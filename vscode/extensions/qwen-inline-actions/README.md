# Qwen Inline Actions — Continue inline edit (0.2.3)

CodeLens **Edit with Continue** над C/C++ комментарием `// AI: ...` или `/* AI: ... */` запускает редактирование содержащей функции через inline diff Continue. Предложение проверяется и принимается/отклоняется прямо в редакторе средствами Continue.

Версия 0.2.0 отправляла фрагмент в чат. Его применение могло заменить весь файл. В 0.2.3 этот маршрут удалён: используется `continue.customQuickActionStreamInlineEdit(prompt, range)`, передающий диапазон механизму inline diff. Возврата к отправке в чат при ошибке нет.

```cpp
int calculate()
{
    // AI: Calculate factorial of 10
}
```

Команда также доступна в палитре с курсором внутри AI-комментария. Требуются сохранённый C/C++ файл в доверенном workspace, включённые `editor.codeLens` и Continue.

## Установка

В терминале Qwen Dev Container:

```sh
code --install-extension /workspace/vscode/extensions/qwen-inline-actions/qwen-inline-actions-0.2.3.vsix --force
```

Затем **Developer: Reload Window**. Появится **Edit with Continue** вместо Send to Continue. Сначала отклоните/закройте старые предложения Continue. Старые ответы чата не используйте для применения фрагмента ко всему файлу.

Continue должен быть установлен в этом окне. Для роли `edit` (либо fallback `chat`) настройте локальную `qwen3-coder:30b` через `http://ollama-gateway:8080`. Bridge не меняет модель, конфигурацию Continue, networking, mounts или изоляцию контейнера. Прямых HTTP-запросов у расширения нет.

Удаление: `code --uninstall-extension local.qwen-inline-actions`. Обновление — установка нового VSIX с `--force` и Reload Window.

## Область и ограничения

- Функция определяется через Document Symbols clangd/cpptools. Дубли объединяются. Неоднозначность требует выбора. Без symbols предлагается содержащий блок или выделение.
- Inline diff Continue работает целыми строками. Bridge расширяет границы только на пробелы; соседний код на граничной строке вызывает отказ. Разместите функцию/блок на отдельных строках. Конец диапазона в начале следующей строки не включает эту строку.
- Перед отправкой проверяются версия документа и активный редактор, выделяется точный диапазон. Во время генерации не переключайте файл и не запускайте вторую правку: внутренняя команда Continue асинхронна и не возвращает handle завершения.
- Передаются инструкция и ограниченные include/соседние строки текущего файла. Сам Continue дополнительно собирает prefix/suffix по своим лимитам. Лимит bridge не ограничивает внутренний контекст Continue.
- Вне workspace контекст bridge не читает; symlink наружу и распространённые секретные пути блокируются. Есть проверка типичных credentials, но это не универсальный DLP.
- Многострочные комментарии поддерживаются; строки/raw-строки не интерпретируются как инструкции. Препроцессор не вычисляется; fallback не является полным C++ AST.
- Bridge не применяет код и не вызывает Accept. Отображение промежуточных изменений, отмена, Accept/Reject и Undo принадлежат Continue. Это не собственная транзакционная защита файла.
- Используется внутренний API Continue, наличие команды проверяется после активации. В просмотренных исходниках custom inline action использует `contextMenuPrompts.docstring`, если тот переопределён, вместо переданного prompt. Не задавайте такой override для этого сценария. Совместимость с конкретной установленной версией требует проверки.
- Удаление/сохранение AI-комментария запрашивается у модели; до применения он остаётся. Bridge не выполняет shell и не изменяет исходники самостоятельно.

## Настройки

| `qwenInlineActions.*` | Default |
| --- | --- |
| `enabled` | `true` |
| `maxContextLines` | `200` |
| `keepInstructionComment` | `false` |

Старые `apiBase`, `model`, `temperature`, `timeoutSeconds`, `requireDiffConfirmation` не используются. Output Channel `Qwen Inline Actions` содержит статусы без исходников.

## Сборка и тесты

Node.js 20+, npm, zip. Runtime npm-зависимостей нет.

```sh
npm ci --ignore-scripts
npm test
npm run lint
npm run package
```

`src/analysis.ts`: лексер, блоки, границы строк, проверки. `src/extension.ts`: CodeLens, scope/context, ContinueBridge. `test/core.test.cjs`: unit-тесты. `test/host.cjs`: настоящий VS Code API с подставной командой Continue. `scripts/host-test.cjs`: запуск временного расширения и очистка. `scripts/package.cjs`: упаковка VSIX. Остальные файлы: package.json/lock, tsconfig.json, eslint.config.mjs, LICENSE, .gitignore, TEST-REPORT.md.

Host-тесты запускайте в доверенном окне без Continue:

```sh
node scripts/host-test.cjs
```

Последний отчёт — `.test-results.json`. [Результаты и ограничения](TEST-REPORT.md).

Проверка с настоящим Continue: используйте файл с несколькими функциями, нажмите **Edit with Continue**, проверьте inline diff, Reject, затем повторите и Accept. Соседние функции должны остаться без изменений; затем проверьте Undo.

Исходники: [команда Continue](https://github.com/continuedev/continue/blob/main/extensions/vscode/src/commands.ts), [inline diff manager](https://github.com/continuedev/continue/blob/main/extensions/vscode/src/diff/vertical/manager.ts).

В 0.2.3 поддержаны class/struct из Document Symbols и простой заголовок класса в fallback. Завершающий `;` после `}` включается в диапазон; соседняя декларация на той же строке по-прежнему запрещена.

## Global scope

Для AI-комментария вне функции/класса появляется выбор:

- **Global: replace AI comment** — заменить только строки инструкции новым кодом. Существующие объявления остаются вне диапазона редактирования.
- **Explicit selection** — если выделение содержит инструкцию.
- **Global: entire file** — явно разрешить правку всего файла; лимит контекста сохраняется.

Для добавления класса или функции выбирайте первый вариант. Для изменения существующего кода выделите нужную область вместе с инструкцией либо явно выберите весь файл. Esc отменяет действие. Комментарий должен находиться на отдельной строке.
