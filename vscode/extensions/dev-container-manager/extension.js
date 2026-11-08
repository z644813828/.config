const vscode = require('vscode');
const fs = require('fs/promises');
const path = require('path');
const os = require('os');

function activate(context) {
  for (const variant of ['codex', 'qwen']) {
    const disposable = vscode.commands.registerCommand(
      `devContainerManager.create${variant[0].toUpperCase()}${variant.slice(1)}`,
      async function () {
        try {
          const folder = vscode.workspace.workspaceFolders?.[0];

          if (!folder) {
            vscode.window.showErrorMessage('Нет открытого проекта');
            return;
          }

          const sourceDir = path.join(
            os.homedir(),
            '.config',
            'vscode',
            'devcontainer',
            variant
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
            await fs.lstat(targetDir);
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

          const symlinkType = process.platform === 'win32' ? 'junction' : 'dir';
          await fs.symlink(sourceDir, targetDir, symlinkType);

          vscode.window.showInformationMessage(
            `Ссылка на контейнер разработки (${variant}) создана`
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
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
