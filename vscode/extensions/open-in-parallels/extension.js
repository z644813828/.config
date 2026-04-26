const vscode = require('vscode');
const fs = require('fs');

function activate(context) {

  const disposable = vscode.commands.registerCommand(
    'openInParallels.open',
    async function () {

      const folder = vscode.workspace.workspaceFolders?.[0];

      if (!folder) {
        vscode.window.showErrorMessage("No folder open");
        return;
      }

      const host = "S";
      let path = folder.uri.fsPath;

      const localBase = '/Users/dmitriy';
      const parallelsBase = '/media/psf/Home';

      path = path.replace(localBase, parallelsBase);

      const remoteUri = vscode.Uri.parse(
        `vscode-remote://ssh-remote+${host}${path}`
      );

      vscode.commands.executeCommand('vscode.openFolder', remoteUri, false);
    }
  );

  context.subscriptions.push(disposable);
}

function deactivate() { }

module.exports = {
  activate,
  deactivate
};
