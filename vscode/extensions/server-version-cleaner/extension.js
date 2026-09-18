'use strict';
const vscode = require('vscode');
const { clean } = require('./cleaner');

function activate(context) {
  const output = vscode.window.createOutputChannel('Server Version Cleaner');
  let running;
  const run = (manual = false) => {
    if (running) return running;
    if (!vscode.env.remoteName || context.extension.extensionKind !== vscode.ExtensionKind.Workspace || process.platform !== 'linux') {
      output.appendLine('Cleanup requires a remote Linux extension host.');
      return Promise.resolve();
    }
    running = clean({
      appRoot: vscode.env.appRoot,
      keep: vscode.workspace.getConfiguration('serverVersionCleaner').get('keep', 2),
      log: message => output.appendLine(message)
    }).catch(error => {
      output.appendLine(`Cleanup skipped/failed: ${error.message}`);
      if (manual) void vscode.window.showWarningMessage(`Server cleanup failed: ${error.message}. See Output → Server Version Cleaner.`);
    })
      .finally(() => { running = undefined; });
    return running;
  };
  context.subscriptions.push(output, vscode.commands.registerCommand('serverVersionCleaner.clean', () => { output.show(true); return run(true); }));
  if (vscode.workspace.getConfiguration('serverVersionCleaner').get('enabled', true)) void run();
}
module.exports = { activate };
