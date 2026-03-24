const vscode = require('vscode');

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
      const path = folder.uri.fsPath;

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
