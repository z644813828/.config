const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
test('binary document edits, undo, redo, save, backup and revert preserve bytes', async () => {
  let provider, providerOptions, listener, edit;
  const commands = new Map();
  const files = new Map([['file', Uint8Array.of(0, 128, 255)]]);
  const uri = value => ({ toString: () => value });
  const mock = {
    EventEmitter: class { event() {} fire(value) { edit = value; } },
    Uri: { parse: uri, joinPath: (_, name) => uri(name) },
    workspace: {
      fs: {
        stat: async target => ({ size: files.get(String(target)).length }),
        readFile: async target => files.get(String(target)).slice(),
        writeFile: async (target, bytes) => files.set(String(target), bytes.slice()),
        delete: async target => files.delete(String(target))
      },
      getConfiguration: () => ({ get: (_, fallback) => fallback }),
      onDidChangeConfiguration() {}
    },
    window: { registerCustomEditorProvider: (_, value, options) => { provider = value; providerOptions = options; } },
    commands: { registerCommand(name, handler) { commands.set(name, handler); } }
  };
  const sandbox = {
    require: name => {
      if (name === 'vscode') return mock;
      if (name === './statusbar') return { createStatusBar: () => ({ attach() {}, update() {} }) };
      return require(name);
    },
    module: { exports: {} },
    Buffer
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../extension.js'), 'utf8'), sandbox);
  sandbox.module.exports.activate({ subscriptions: [], extensionPath: path.join(__dirname, '..'), extensionUri: uri('extension') });
  assert.equal(providerOptions.webviewOptions.retainContextWhenHidden, true);
  const document = await provider.openCustomDocument(uri('file'), {});
  const messages = [];
  await provider.resolveCustomEditor(document, { active: true, onDidDispose() {}, webview: {
    asWebviewUri: String, cspSource: 'test:', postMessage: value => messages.push(value), onDidReceiveMessage: value => { listener = value; }
  } });
  listener({ type: 'status', state: { cursor: 0, length: 3 } });
  listener({ type: 'edit', offset: 1, value: 42 });
  assert.equal(document.bytes[1], 42);
  edit.undo(); assert.equal(document.bytes[1], 128);
  edit.redo(); assert.equal(document.bytes[1], 42);
  listener({ type: 'edit', offset: -1, value: 1 });
  listener({ type: 'edit', offset: 0, value: 256 });
  assert.deepEqual([...document.bytes], [0, 42, 255]);
  await provider.saveCustomDocument(document);
  assert.deepEqual([...files.get('file')], [0, 42, 255]);
  await provider.saveCustomDocumentAs(document, uri('copy'));
  assert.deepEqual([...files.get('copy')], [0, 42, 255]);
  const backup = await provider.backupCustomDocument(document, { destination: uri('backup') });
  const restored = await provider.openCustomDocument(uri('file'), { backupId: backup.id });
  assert.deepEqual([...restored.bytes], [0, 42, 255]);
  await backup.delete(); assert.equal(files.has('backup'), false);
  listener({ type: 'edit', offset: 1, values: [10, 20] });
  assert.deepEqual([...document.bytes], [0, 10, 20]);
  edit.undo(); assert.deepEqual([...document.bytes], [0, 42, 255]);
  edit.redo(); assert.deepEqual([...document.bytes], [0, 10, 20]);
  listener({ type: 'edit', offset: 2, values: [1, 2] });
  listener({ type: 'edit', offset: 0, values: [1, 256] });
  assert.deepEqual([...document.bytes], [0, 10, 20]);
  files.set('file', Uint8Array.of(5));
  await provider.revertCustomDocument(document);
  assert.deepEqual([...document.bytes], [5]);
  assert.equal(messages.at(-1).bytes, 'BQ==');
});
