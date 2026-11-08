const vscode = require('vscode');
const os = require('os');

function activate(context) {
  context.subscriptions.push(
    vscode.window.registerTerminalProfileProvider('hostTerminal.local', {
      provideTerminalProfile() {
        // Run in the local UI extension host. A file URI selects the local
        // terminal backend even when the workspace is inside a container.
        return new vscode.TerminalProfile({
          name: 'Терминал хоста',
          cwd: vscode.Uri.file(os.homedir()),
          shellPath: process.platform === 'win32'
            ? (process.env.COMSPEC || 'cmd.exe')
            : (os.userInfo().shell || process.env.SHELL || '/bin/sh'),
          iconPath: new vscode.ThemeIcon('device-desktop')
        });
      }
    })
  );
}

module.exports = { activate };
