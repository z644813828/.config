const vscode = require('vscode');
const fs = require('fs/promises');
const path = require('path');
const os = require('os');

function activate(context) {
  const disposable = vscode.commands.registerCommand(
    'trixieDevcontainer.create',
    async function () {
      try {
        const folder = vscode.workspace.workspaceFolders?.[0];

        if (!folder) {
          vscode.window.showErrorMessage('Нет открытого проекта');
          return;
        }

        const sourceDir = path.join(
          os.homedir(),
          'Documents',
          'Projects',
          '.devcontainer'
        );

        const targetDir = path.join(folder.uri.fsPath, '.devcontainer');

        try {
          const stat = await fs.stat(sourceDir);
          if (!stat.isDirectory()) {
            vscode.window.showErrorMessage(
              `Источник не является директорией: ${sourceDir}`
            );
            return;
          }
        } catch {
          vscode.window.showErrorMessage(
            `Не найдена директория шаблона: ${sourceDir}`
          );
          return;
        }

        let targetExists = false;
        try {
          await fs.stat(targetDir);
          targetExists = true;
        } catch {
          targetExists = false;
        }

        if (targetExists) {
          const answer = await vscode.window.showWarningMessage(
            'В проекте уже есть .devcontainer. Перезаписать?',
            { modal: true },
            'Перезаписать',
            'Отмена'
          );

          if (answer !== 'Перезаписать') {
            return;
          }

          await fs.rm(targetDir, { recursive: true, force: true });
        }

        await fs.cp(sourceDir, targetDir, { recursive: true });

        vscode.window.showInformationMessage(
          'Контейнер разработки (trixie) создан'
        );
      } catch (err) {
        vscode.window.showErrorMessage(
          `Ошибка при создании контейнера: ${err instanceof Error ? err.message : String(err)}`
        );
      }
    }
  );

  context.subscriptions.push(disposable);
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
