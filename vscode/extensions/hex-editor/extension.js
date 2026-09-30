const vscode = require('vscode');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const LIMIT = 32 * 1024 * 1024;

function activate(context) {
  const changes = new vscode.EventEmitter();
  const statusBar = require('./statusbar').createStatusBar(context);
  const webviews = new Set();
  const hoverOpacity = () => vscode.workspace.getConfiguration('hexEditor').get('hoverOpacity', 6);
  context.subscriptions.push(changes);
  context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(event => {
    if (!event.affectsConfiguration('hexEditor.hoverOpacity')) return;
    for (const panel of webviews) panel.webview.postMessage({ type: 'settings', hoverOpacity: hoverOpacity() });
  }));
  const provider = {
    onDidChangeCustomDocument: changes.event,
    async openCustomDocument(uri, openContext) {
      const source = openContext.backupId ? vscode.Uri.parse(openContext.backupId) : uri;
      const stat = await vscode.workspace.fs.stat(source);
      if (stat.size > LIMIT) throw new Error('Hex Editor currently supports files up to 32 MiB.');
      const bytes = await vscode.workspace.fs.readFile(source);
      const document = {
        uri,
        bytes,
        dirty: false,
        panels: new Set(),
        watcher: undefined,
        reloadTimer: undefined,
        dispose() {
          if (this.reloadTimer) clearTimeout(this.reloadTimer);
          this.watcher?.dispose();
          this.panels.clear();
        }
      };
      if (!openContext.backupId && uri.scheme === 'file') watch(document);
      return document;
    },
    async resolveCustomEditor(document, panel) {
      document.panels.add(panel);
      statusBar.attach(panel);
      webviews.add(panel);
      panel.onDidDispose(() => { document.panels.delete(panel); webviews.delete(panel); });
      const media = vscode.Uri.joinPath(context.extensionUri, 'media');
      panel.webview.options = { enableScripts: true, localResourceRoots: [media] };
      const nonce = crypto.randomBytes(16).toString('hex');
      const resource = name => panel.webview.asWebviewUri(vscode.Uri.joinPath(media, name)).toString();
      const html = fs.readFileSync(path.join(context.extensionPath, 'media', 'editor.html'), 'utf8');
      panel.webview.html = html.replaceAll('{{csp}}', panel.webview.cspSource).replaceAll('{{nonce}}', nonce)
        .replaceAll('{{style}}', resource('editor.css')).replaceAll('{{core}}', resource('core.js')).replaceAll('{{script}}', resource('editor.js'));
      panel.webview.onDidReceiveMessage(message => {
        if (message.type === 'status') statusBar.update(panel, message.state);
        if (message.type === 'command' && panel.active) {
          const commands = {
            find: 'hexEditor.find',
            goto: 'hexEditor.goto'
          };
          if (commands[message.action]) vscode.commands.executeCommand(commands[message.action]);
        }
        if (message.type === 'ready') {
          send(document, panel);
          panel.webview.postMessage({ type: 'settings', hoverOpacity: hoverOpacity() });
        }
        if (message.type === 'edit') {
          const { offset } = message;
          const values = message.values === undefined ? [message.value] : message.values;
          if (!Number.isInteger(offset) || offset < 0 || !Array.isArray(values) || ![1, 2, 4, 8].includes(values.length) || offset + values.length > document.bytes.length || values.some(value => !Number.isInteger(value) || value < 0 || value > 255)) return;
          const before = Array.from(document.bytes.subarray(offset, offset + values.length));
          if (before.every((value, index) => value === values[index])) return;
          const apply = replacement => {
            document.bytes.set(replacement, offset);
            document.dirty = true;
            for (const view of document.panels) view.webview.postMessage(replacement.length === 1 ? { type: 'patch', offset, value: replacement[0] } : { type: 'patch', offset, values: replacement });
          };
          apply(values);
          changes.fire({ document, label: values.length === 1 ? 'Edit byte' : 'Edit integer', undo: () => apply(before), redo: () => apply(values) });
        }
        if (message.type === 'undo' || message.type === 'redo') vscode.commands.executeCommand(message.type);
      });
    },
    async saveCustomDocument(document) {
      await vscode.workspace.fs.writeFile(document.uri, document.bytes.slice());
      document.dirty = false;
    },
    async saveCustomDocumentAs(document, destination) {
      await vscode.workspace.fs.writeFile(destination, document.bytes.slice());
      document.dirty = false;
    },
    async revertCustomDocument(document) {
      document.bytes = await vscode.workspace.fs.readFile(document.uri);
      document.dirty = false;
      for (const panel of document.panels) send(document, panel);
    },
    async backupCustomDocument(document, context) {
      await vscode.workspace.fs.writeFile(context.destination, document.bytes.slice());
      return { id: context.destination.toString(), delete: () => vscode.workspace.fs.delete(context.destination) };
    }
  };
  function send(document, panel) {
    panel.webview.postMessage({ type: 'data', bytes: Buffer.from(document.bytes).toString('base64') });
  }
  function notify(document, text) {
    for (const panel of document.panels) panel.webview.postMessage({ type: 'message', text });
  }
  function watch(document) {
    const directory = vscode.Uri.file(path.dirname(document.uri.fsPath));
    const watcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(directory, path.basename(document.uri.fsPath)));
    document.watcher = watcher;
    const reload = async () => {
      if (document.dirty) {
        notify(document, 'File changed on disk. Save, revert, or discard local edits before reloading.');
        return;
      }
      try {
        const stat = await vscode.workspace.fs.stat(document.uri);
        if (stat.size > LIMIT) throw new Error('File exceeds the 32 MiB editor limit.');
        const updated = await vscode.workspace.fs.readFile(document.uri);
        if (sameBytes(document.bytes, updated)) return;
        document.bytes = updated;
        for (const panel of document.panels) send(document, panel);
        notify(document, 'Reloaded after an external file change.');
      } catch (error) {
        notify(document, `Could not reload changed file: ${error.message || error}`);
      }
    };
    const schedule = () => {
      if (document.reloadTimer) clearTimeout(document.reloadTimer);
      document.reloadTimer = setTimeout(() => { document.reloadTimer = undefined; reload(); }, 100);
    };
    watcher.onDidChange(schedule);
    watcher.onDidCreate(schedule);
    watcher.onDidDelete(() => notify(document, 'File was deleted on disk.'));
  }
  function sameBytes(left, right) {
    if (left.length !== right.length) return false;
    for (let index = 0; index < left.length; index++) if (left[index] !== right[index]) return false;
    return true;
  }
  context.subscriptions.push(vscode.window.registerCustomEditorProvider('local.hexEditor', provider, {
    supportsMultipleEditorsPerDocument: true,
    webviewOptions: { enableFindWidget: false, retainContextWhenHidden: true }
  }));
  context.subscriptions.push(vscode.commands.registerCommand('hexEditor.open', async uri => {
    uri = uri || vscode.window.activeTextEditor?.document.uri;
    if (!uri) [uri] = await vscode.window.showOpenDialog({ canSelectMany: false }) || [];
    if (uri) await vscode.commands.executeCommand('vscode.openWith', uri, 'local.hexEditor');
  }));
}
module.exports = { activate };
