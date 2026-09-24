const Module = require('module');
const assert = require('assert');
const { vscode, makeEditor, Position, Selection } = require('./stub-vscode');
const load = Module._load;
Module._load = function (request, ...rest) {
	return request === 'vscode' ? vscode : load.call(this, request, ...rest);
};
require('../extension').activate({ subscriptions: [] });
const run = (id) => vscode.commands.executeCommand('multiCursor.' + id);
const at = (line, col = 0) => new Selection(new Position(line, col), new Position(line, col));
const tick = () => new Promise((resolve) => setTimeout(resolve, 5));

function setup(up = false) {
	const ed = makeEditor(Array(30).fill('yy1').join('\n'));
	ed.document.version = 2;
	ed._selections = [at(up ? 4 : 0)];
	vscode.window.activeTextEditor = ed;
	vscode._fireSelectionChange({ textEditor: ed, selections: ed.selections, kind: 2 });
	for (let i = 0; i < 4; i++) run(up ? 'expandUp' : 'expandDown');
	return ed;
}
function changes(text = '\nyy1\nyy2') {
	return Array.from({ length: 5 }, (_, line) => ({
		range: { start: new Position(line, 1), end: new Position(line, 1) },
		rangeLength: 0, text
	})).reverse();
}
function edit(ed, edits = changes(), reason) {
	vscode._fireDocumentChange({ document: ed.document, contentChanges: edits, reason });
}
function stale(ed, block = false) {
	ed.selections = Array.from({ length: 5 }, (_, i) => block
		? new Selection(new Position(i + 1, 0), new Position(i + 1, 1)) : at(i + 1));
}
const rows = (ed) => ed.selections.map((s) => s.active.line);
(async () => {
	for (const up of [false, true]) {
		for (const block of [false, true]) {
			const ed = setup(up);
			edit(ed);
			// VS Code may first report selections automatically moved by the edit.
			ed._selections = [at(0), at(3), at(6), at(9), at(12)];
			vscode._fireSelectionChange({ textEditor: ed, selections: ed.selections });
			stale(ed, block);
			await tick();
			assert.deepStrictEqual(rows(ed), [1, 4, 7, 10, 13]);
			run('moveLastCursorRight');
			assert.strictEqual(ed.selections[up ? 0 : 4].active.character, block ? 2 : 1);
			assert.strictEqual(ed.selections[up ? 4 : 0].active.character, block ? 1 : 0);
		}
	}
	console.log('ok: two-line paste into five cursors, both directions and cursor shapes');
	for (const text of ['\nyy1', '\r\nyy1\r\nyy2', '\n  yy1\nyy2\nyy3']) {
		const ed = setup();
		edit(ed, changes(text));
		const column = text.includes('  ') ? 2 : 0;
		ed.selections = Array.from({ length: 5 }, (_, i) => at(i + 1, column));
		await tick();
		const height = text.split('\n').length - 1;
		assert.deepStrictEqual(rows(ed), [0, 1, 2, 3, 4].map((i) => 1 + i * (height + 1)));
	}
	console.log('ok: one/three-line blocks, CRLF and indentation');
	{
		const ed = setup(); edit(ed);
		ed.selections = [1, 4, 7, 10, 13].map((line) => at(line));
		await tick();
		assert.deepStrictEqual(rows(ed), [1, 4, 7, 10, 13]);
	}
	console.log('ok: correct positions are not shifted twice');
	{
		const ed = setup(); edit(ed);
		ed.selections = [1, 4, 7, 10, 13].map((line) => at(line));
		// A later API move must not reuse an old paste correction.
		stale(ed);
		await tick();
		assert.deepStrictEqual(rows(ed), [1, 2, 3, 4, 5]);
	}
	{
		const ed = setup();
		const edits = changes();
		for (const change of edits) change.text = '\nx'.repeat(change.range.start.line + 1);
		edit(ed, edits); stale(ed);
		await tick();
		assert.deepStrictEqual(rows(ed), [1, 3, 6, 10, 15]);
	}
	console.log('ok: stale correction cancelled; variable register lengths');
	for (const scenario of ['undo', 'replacement', 'inline', 'mouse', 'keyboard', 'new-edit', 'switch', 'disabled', 'no-vim']) {
		const ed = setup();
		const originalGet = vscode.extensions.getExtension;
		const originalConfig = vscode.workspace.getConfiguration;
		if (scenario === 'no-vim') vscode.extensions.getExtension = () => undefined;
		if (scenario === 'disabled') vscode.workspace.getConfiguration = () => ({ get: () => true });
		const edits = changes(scenario === 'inline' ? 'xx' : '\nyy1\nyy2');
		if (scenario === 'replacement') edits[0].rangeLength = 1;
		edit(ed, edits, scenario === 'undo' ? 1 : undefined);
		stale(ed);
		if (scenario === 'mouse' || scenario === 'keyboard') {
			vscode._fireSelectionChange({ textEditor: ed, selections: ed.selections, kind: scenario === 'mouse' ? 2 : 1 });
		}
		if (scenario === 'new-edit') { ed.document.version++; edit(ed, changes('x')); }
		if (scenario === 'switch') vscode.window.activeTextEditor = makeEditor('other');
		await tick();
		assert.deepStrictEqual(rows(ed), [1, 2, 3, 4, 5], scenario);
		vscode.extensions.getExtension = originalGet;
		vscode.workspace.getConfiguration = originalConfig;
	}
	console.log('ok: undo, unrelated edits, user moves, editor switch, disabled/absent Vim');
})().catch((error) => { console.error(error); process.exitCode = 1; });
