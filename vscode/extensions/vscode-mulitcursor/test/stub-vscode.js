// Minimal stand-in for the parts of the VS Code API the extension uses.
class Position {
	constructor(line, character) { this.line = line; this.character = character; }
	isEqual(o) { return this.line === o.line && this.character === o.character; }
	with(line, character) {
		return new Position(line === undefined ? this.line : line, character === undefined ? this.character : character);
	}
}
class Range {
	constructor(start, end) { this.start = start; this.end = end; }
}
class Selection extends Range {
	constructor(anchor, active) { super(anchor, active); this.anchor = anchor; this.active = active; }
	get isEmpty() { return this.anchor.isEqual(this.active); }
}

const listeners = { selection: [], activeEditor: [] };
function event(bucket) {
	return (fn) => { bucket.push(fn); return { dispose() {} }; };
}

const vscode = {
	Position, Range, Selection,
	TextEditorRevealType: { Default: 0 },
	TextEditorSelectionChangeKind: { Keyboard: 1, Mouse: 2, Command: 3 },
	commands: {
		_handlers: {},
		registerCommand(id, fn) { vscode.commands._handlers[id] = fn; return { dispose() {} }; },
		executeCommand(id) { return vscode.commands._handlers[id](); }
	},
	window: {
		activeTextEditor: undefined,
		onDidChangeTextEditorSelection: event(listeners.selection),
		onDidChangeActiveTextEditor: event(listeners.activeEditor)
	},
	_fireSelectionChange(e) { listeners.selection.forEach((fn) => fn(e)); }
};

function makeEditor(text, tabSize = 4) {
	const lines = text.split('\n');
	return {
		options: { tabSize },
		document: {
			get lineCount() { return lines.length; },
			lineAt(line) { return { text: lines[line] }; }
		},
		_selections: [new Selection(new Position(0, 0), new Position(0, 0))],
		get selections() { return this._selections; },
		set selections(value) {
			this._selections = value;
			// The real editor notifies listeners after an API-driven change.
			vscode._fireSelectionChange({ selections: value, kind: 3 }); // 'api' arrives as Command
		},
		get selection() { return this._selections[0]; },
		revealRange() {}
	};
}

module.exports = { vscode, makeEditor, Position, Selection };
