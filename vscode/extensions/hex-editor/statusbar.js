const vscode = require('vscode');
const core = require('./media/core');

function createStatusBar(context) {
  const views = new Map();
  const items = {};
  let input;
  const definitions = [
    ['offset', 100, 'hexEditor.goto'], ['selection', 99],
    ['group', 98, 'hexEditor.group'], ['radix', 97, 'hexEditor.radix'],
    ['find', 96, 'hexEditor.find'], ['previous', 95, 'hexEditor.previous'],
    ['next', 94, 'hexEditor.next'], ['message', 93], ['size', -1000]
  ];
  for (const [name, priority, command] of definitions) {
    const item = vscode.window.createStatusBarItem(`hexEditor.${name}`, vscode.StatusBarAlignment.Right, priority);
    item.name = `Hex Editor: ${name}`; item.command = command;
    items[name] = item; context.subscriptions.push(item);
  }
  const active = () => [...views.keys()].find(panel => panel.active);
  const post = (panel, action, extra = {}) => {
    if (views.has(panel)) panel.webview.postMessage({ type: 'action', action, ...extra });
  };
  function refresh() {
    for (const item of Object.values(items)) item.hide();
    const panel = active(), state = views.get(panel);
    if (!state) return;
    const address = value => state.addressRadix === 10 ? String(value) : value.toString(16).toUpperCase().padStart(8, '0');
    items.offset.text = state.length ? `Offset ${address(state.cursor)}` : 'Empty file';
    items.offset.tooltip = `Go to address (${state.addressRadix === 10 ? 'Dec' : 'Hex'})`;
    items.group.text = `uint${state.groupSize * 8}_t`; items.group.tooltip = 'Integer grouping';
    items.radix.text = state.radix === 16 ? 'Hex' : 'Dec'; items.radix.tooltip = 'Display format';
    items.find.text = state.matches === null ? '$(search) Find' : `$(search) ${state.matches.toLocaleString()} matches`;
    items.find.tooltip = 'Find bytes or text (Ctrl/Cmd+F)';
    items.size.text = `${state.length.toLocaleString()} bytes`; items.size.tooltip = 'File size';
    for (const key of ['offset', 'group', 'radix', 'find', 'size']) items[key].show();
    if (state.selected > 1) {
      items.selection.text = `${state.selected} bytes selected`;
      items.selection.tooltip = `${address(state.low)}–${address(state.high)} (${state.addressRadix === 16 ? 'Hex' : 'Dec'}, inclusive)`;
      items.selection.show();
    }
    if (state.matches > 0) {
      items.previous.text = '$(arrow-up)'; items.previous.tooltip = 'Previous match (Shift+F3)'; items.previous.show();
      items.next.text = '$(arrow-down)'; items.next.tooltip = 'Next match (F3)'; items.next.show();
    }
    if (state.message) { items.message.text = state.message; items.message.tooltip = state.message; items.message.show(); }
  }
  function openInput(panel, kind) {
    input?.hide();
    const state = views.get(panel);
    if (!state) return;
    const box = vscode.window.createInputBox(); input = box;
    let base = state.addressRadix, mode = state.mode;
    const button = (icon, tooltip) => ({ iconPath: new vscode.ThemeIcon(icon), tooltip });
    const format = value => base === 16 ? value.toString(16).toUpperCase().padStart(8, '0') : String(value);
    const update = () => {
      box.title = kind === 'goto' ? `Hex Editor: Go to (${base === 16 ? 'Hex' : 'Dec'})` : `Hex Editor: Find (${mode === 'hex' ? 'Hex' : 'UTF-8'})`;
      box.placeholder = kind === 'goto' ? (base === 16 ? 'Address in hex, without 0x' : 'Decimal address') : mode === 'hex' ? 'DE AD BE EF' : 'Search text';
      box.buttons = kind === 'goto' ? [button('symbol-number', `Switch to ${base === 16 ? 'Dec' : 'Hex'}`)] : [button('symbol-key', 'Switch Hex / UTF-8'), button('arrow-up', 'Previous match'), button('arrow-down', 'Next match'), button('clear-all', 'Clear search')];
    };
    update(); box.value = kind === 'goto' ? format(state.cursor) : state.query;
    const search = direction => {
      try {
        if (box.value && !(mode === 'hex' && !box.value.trim())) core.pattern(box.value, mode);
        box.validationMessage = undefined;
        post(panel, 'search', { query: box.value, mode, direction });
      } catch (error) { box.validationMessage = error.message; }
    };
    const listeners = [
      box.onDidChangeValue(value => {
        box.validationMessage = undefined;
        if (kind === 'find') post(panel, 'query', { query: value, mode });
      }),
      box.onDidAccept(() => {
        if (kind === 'find') { search(1); return; }
        try {
          const offset = core.address(box.value, views.get(panel)?.length || 0, base);
          post(panel, 'goto', { offset, addressRadix: base }); box.hide();
        } catch (error) { box.validationMessage = error.message; }
      }),
      box.onDidTriggerButton(clicked => {
        const index = box.buttons.indexOf(clicked);
        if (kind === 'goto') {
          let offset = state.cursor;
          try { offset = core.address(box.value, Number.MAX_SAFE_INTEGER, base); } catch { /* Keep current offset for unfinished input. */ }
          base = base === 16 ? 10 : 16; update(); box.value = format(offset);
          post(panel, 'addressRadix', { value: base });
        } else if (index === 0) {
          mode = mode === 'hex' ? 'text' : 'hex'; update(); post(panel, 'query', { query: box.value, mode });
        } else if (index === 3) { box.value = ''; search(1); }
        else search(index === 1 ? -1 : 1);
      }),
      box.onDidHide(() => { for (const listener of listeners) listener.dispose(); box.dispose(); if (input === box) input = undefined; })
    ];
    box.show();
  }
  for (const action of ['find', 'goto', 'group', 'radix', 'next', 'previous']) {
    context.subscriptions.push(vscode.commands.registerCommand(`hexEditor.${action}`, async () => {
      const panel = active(); if (!panel) return;
      if (action === 'find' || action === 'goto') { openInput(panel, action); return; }
      if (action === 'next' || action === 'previous') { post(panel, 'search', { direction: action === 'next' ? 1 : -1 }); return; }
      const state = views.get(panel);
      const choices = action === 'group' ? [1, 2, 4, 8].map(value => ({ label: `uint${value * 8}_t`, value })) : [{ label: 'Hex', value: 16 }, { label: 'Dec', value: 10 }];
      for (const choice of choices) if (choice.value === (action === 'group' ? state.groupSize : state.radix)) choice.description = 'Current';
      const choice = await vscode.window.showQuickPick(choices, { title: action === 'group' ? 'Hex Editor: Integer type' : 'Hex Editor: Display format' });
      if (choice) post(panel, action, { value: choice.value });
    }));
  }
  context.subscriptions.push({ dispose() { input?.hide(); views.clear(); } });
  return {
    attach(panel) {
      views.set(panel, null);
      const change = panel.onDidChangeViewState(refresh);
      panel.onDidDispose(() => { change.dispose(); views.delete(panel); refresh(); });
      refresh();
    },
    update(panel, state) { if (views.has(panel)) { views.set(panel, state); refresh(); } }
  };
}
module.exports = { createStatusBar };
