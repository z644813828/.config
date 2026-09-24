const vscode = require('vscode');

// VSCodeVim's linewise `p` uses absolute cursor positions calculated before
// the batched edit. Repair only that exact pattern; never replay the paste.
function watchPasteCursors(context, getTrackedCount, applySelections) {
	let pending;
	let timer;
	function cancel() {
		pending = undefined;
		clearTimeout(timer);
	}
	context.subscriptions.push({ dispose: cancel });
	context.subscriptions.push(vscode.workspace.onDidChangeTextDocument((event) => {
		const editor = vscode.window.activeTextEditor;
		if (!editor || event.document !== editor.document || event.contentChanges.length === 0) return;
		cancel();
		const count = getTrackedCount();
		if (event.reason !== undefined || count < 2 || event.contentChanges.length !== count ||
			!vscode.extensions.getExtension('vscodevim.vim')?.isActive ||
			vscode.workspace.getConfiguration('vim').get('disableExtension', false)) return;

		const changes = [...event.contentChanges].sort((a, b) => a.range.start.line - b.range.start.line);
		let shift = 0;
		const targets = [];
		for (const [i, change] of changes.entries()) {
			if (change.rangeLength !== 0 || !change.range.start.isEqual(change.range.end) ||
				!/^\r?\n/.test(change.text) ||
				(i > 0 && change.range.start.line === changes[i - 1].range.start.line)) return;
			const lines = change.text.split(/\r?\n/);
			const character = Math.max(0, lines[1].search(/\S/));
			targets.push({ line: change.range.start.line + 1, character, shift });
			shift += lines.length - 1;
		}
		pending = { editor, version: event.document.version, targets };
	}));
	context.subscriptions.push(vscode.window.onDidChangeTextEditorSelection((event) => {
		const state = pending;
		if (!state || event.textEditor !== state.editor) return;
		if (event.kind === vscode.TextEditorSelectionChangeKind.Mouse ||
			event.kind === vscode.TextEditorSelectionChangeKind.Keyboard ||
			event.selections.length !== state.targets.length) {
			cancel();
			return;
		}
		// An automatic edit event may precede Vim's final absolute selections.
		if (!event.selections.every((s, i) => {
			const target = state.targets[i];
			return s.anchor.line === target.line && s.active.line === target.line &&
				Math.min(s.anchor.character, s.active.character) === target.character &&
				Math.abs(s.anchor.character - s.active.character) <= 1;
		})) {
			// A different explicit command supersedes this edit. Only native
			// edit-driven events (no kind) may precede Vim's final selections.
			if (event.kind === vscode.TextEditorSelectionChangeKind.Command) cancel();
			return;
		}
		const selections = event.selections;
		clearTimeout(timer);
		// Let Vim finish updating its view before notifying it of our correction.
		timer = setTimeout(() => {
			if (pending !== state) return;
			cancel();
			if (vscode.window.activeTextEditor !== state.editor ||
				state.editor.document.version !== state.version ||
				!sameSelections(state.editor.selections, selections)) return;
			applySelections(state.editor, selections.map((s, i) => {
				const shift = state.targets[i].shift;
				return new vscode.Selection(s.anchor.with(s.anchor.line + shift), s.active.with(s.active.line + shift));
			}));
		}, 0);
	}));
	context.subscriptions.push(vscode.window.onDidChangeActiveTextEditor(cancel));
	return cancel;
}

function sameSelections(a, b) {
	return a.length === b.length && a.every((s, i) =>
		s.anchor.isEqual(b[i].anchor) && s.active.isEqual(b[i].active));
}

module.exports = { watchPasteCursors };
