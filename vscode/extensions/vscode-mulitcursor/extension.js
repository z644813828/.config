const vscode = require('vscode');

// Port of the Atom `multi-cursor` package (joseramonc/multi-cursor).
//
// Two ideas the built-in VS Code commands do not give you:
//   * expand up/down keeps a "last cursor"; expanding back in the opposite
//     direction removes it again instead of growing the block both ways;
//   * the last cursor can be moved on its own, leaving the others in place.
//
// The last cursor is kept at index 0 of `editor.selections`, i.e. it is the
// primary selection, so the status bar and auto-reveal follow it.

/** Desired *visual* column, kept across vertical moves (Atom's goalColumn). */
let goalColumn;

/** Signature of the selections we set ourselves, to ignore our own events. */
let ownSelections = null;

function signature(selections) {
	return selections
		.map((s) => `${s.anchor.line}:${s.anchor.character}>${s.active.line}:${s.active.character}`)
		.join('|');
}

function tabSize(editor) {
	const size = editor.options.tabSize;
	return typeof size === 'number' && size > 0 ? size : 4;
}

/** Character offset -> visual column, expanding tabs. */
function toVisualColumn(text, character, tabWidth) {
	let column = 0;
	const end = Math.min(character, text.length);
	for (let i = 0; i < end; i++) {
		column += text[i] === '\t' ? tabWidth - (column % tabWidth) : 1;
	}
	return column + Math.max(0, character - text.length);
}

/** Visual column -> character offset, clipped to the end of the line. */
function toCharacter(text, visualColumn, tabWidth) {
	let column = 0;
	for (let i = 0; i < text.length; i++) {
		if (column >= visualColumn) {
			return i;
		}
		const next = text[i] === '\t' ? column + tabWidth - (column % tabWidth) : column + 1;
		if (next > visualColumn) {
			// The target column falls inside a tab; snap to the nearer edge.
			return visualColumn - column <= next - visualColumn ? i : i + 1;
		}
		column = next;
	}
	return text.length;
}

function lineText(document, line) {
	return document.lineAt(line).text;
}

function currentVisualColumn(editor, position) {
	if (goalColumn !== undefined) {
		return goalColumn;
	}
	return toVisualColumn(lineText(editor.document, position.line), position.character, tabSize(editor));
}

function positionAt(editor, line, visualColumn) {
	const character = toCharacter(lineText(editor.document, line), visualColumn, tabSize(editor));
	return new vscode.Position(line, character);
}

function apply(editor, selections, reveal) {
	ownSelections = signature(selections);
	editor.selections = selections;
	editor.revealRange(new vscode.Range(reveal, reveal), vscode.TextEditorRevealType.Default);
}

function expand(direction) {
	const editor = vscode.window.activeTextEditor;
	if (!editor) {
		return;
	}

	const selections = editor.selections;
	const last = selections[0];
	const line = last.active.line + direction;
	if (line < 0 || line >= editor.document.lineCount) {
		return;
	}

	const visualColumn = currentVisualColumn(editor, last.active);
	const position = positionAt(editor, line, visualColumn);
	const occupied = selections.findIndex((s) => s.active.isEqual(position));

	let next;
	if (occupied >= 0) {
		// A cursor is already there: we are moving back, so drop the last one
		// and hand "last cursor" over to the one we bumped into.
		const rest = selections.filter((_, i) => i !== 0);
		const hit = rest.findIndex((s) => s.active.isEqual(position));
		next = [rest[hit], ...rest.filter((_, i) => i !== hit)];
	} else {
		next = [new vscode.Selection(position, position), ...selections];
	}

	goalColumn = visualColumn;
	apply(editor, next, position);
}

function expandAll(direction) {
	const editor = vscode.window.activeTextEditor;
	if (!editor) {
		return;
	}

	const selections = editor.selections;
	const start = selections[0].active.line;
	const stop = direction < 0 ? 0 : editor.document.lineCount - 1;
	if (start === stop) {
		return;
	}

	const visualColumn = currentVisualColumn(editor, selections[0].active);
	const taken = new Set(selections.map((s) => `${s.active.line}:${s.active.character}`));
	const added = [];
	let position = selections[0].active;

	for (let line = start + direction; direction < 0 ? line >= stop : line <= stop; line += direction) {
		position = positionAt(editor, line, visualColumn);
		const key = `${position.line}:${position.character}`;
		if (taken.has(key)) {
			continue;
		}
		taken.add(key);
		added.unshift(new vscode.Selection(position, position));
	}

	goalColumn = visualColumn;
	apply(editor, [...added, ...selections], position);
}

function moveLastCursor(direction) {
	const editor = vscode.window.activeTextEditor;
	if (!editor) {
		return;
	}

	const document = editor.document;
	const selections = editor.selections;
	const last = selections[0];
	const from = last.active;
	let position;

	if (direction === 'left') {
		goalColumn = undefined;
		if (from.character > 0) {
			position = from.with(undefined, from.character - 1);
		} else if (from.line > 0) {
			position = new vscode.Position(from.line - 1, lineText(document, from.line - 1).length);
		} else {
			return;
		}
	} else if (direction === 'right') {
		goalColumn = undefined;
		if (from.character < lineText(document, from.line).length) {
			position = from.with(undefined, from.character + 1);
		} else if (from.line + 1 < document.lineCount) {
			position = new vscode.Position(from.line + 1, 0);
		} else {
			return;
		}
	} else {
		const line = from.line + (direction === 'up' ? -1 : 1);
		if (line < 0 || line >= document.lineCount) {
			return;
		}
		const visualColumn = currentVisualColumn(editor, from);
		goalColumn = visualColumn;
		position = positionAt(editor, line, visualColumn);
	}

	// An empty selection just moves; a real selection is extended, like Atom's
	// `modifySelection`.
	const moved = last.isEmpty
		? new vscode.Selection(position, position)
		: new vscode.Selection(last.anchor, position);

	// Atom calls mergeCursors afterwards: drop any cursor we landed on top of.
	const rest = moved.isEmpty
		? selections.slice(1).filter((s) => !(s.isEmpty && s.active.isEqual(position)))
		: selections.slice(1);

	apply(editor, [moved, ...rest], position);
}

function reset() {
	goalColumn = undefined;
	ownSelections = null;
}

function activate(context) {
	const commands = {
		'multiCursor.expandDown': () => expand(1),
		'multiCursor.expandUp': () => expand(-1),
		'multiCursor.expandAllDown': () => expandAll(1),
		'multiCursor.expandAllUp': () => expandAll(-1),
		'multiCursor.moveLastCursorLeft': () => moveLastCursor('left'),
		'multiCursor.moveLastCursorRight': () => moveLastCursor('right'),
		'multiCursor.moveLastCursorUp': () => moveLastCursor('up'),
		'multiCursor.moveLastCursorDown': () => moveLastCursor('down')
	};

	for (const [id, handler] of Object.entries(commands)) {
		context.subscriptions.push(vscode.commands.registerCommand(id, handler));
	}

	context.subscriptions.push(
		vscode.window.onDidChangeTextEditorSelection((e) => {
			// Anything we did not do ourselves (a click, typing, another
			// command) invalidates the remembered column. Our own changes come
			// back as `Command` (the API source), so they are told apart by the
			// selections themselves; a mouse click never is ours.
			const mouse = e.kind === vscode.TextEditorSelectionChangeKind.Mouse;
			if (!mouse && ownSelections !== null && signature(e.selections) === ownSelections) {
				return;
			}
			reset();
		}),
		vscode.window.onDidChangeActiveTextEditor(reset)
	);
}

function deactivate() {
	reset();
}

module.exports = { activate, deactivate };
