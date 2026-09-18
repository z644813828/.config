const Module = require('module');
const assert = require('assert');
const { vscode, makeEditor, Position, Selection } = require('./stub-vscode');

// Make `require('vscode')` resolve to the stub.
const load = Module._load;
Module._load = function (request, ...rest) {
	return request === 'vscode' ? vscode : load.call(this, request, ...rest);
};

const extension = require('../extension');
extension.activate({ subscriptions: [] });

const run = (id) => vscode.commands.executeCommand(id);
const cursors = (editor) => editor.selections.map((s) => `${s.active.line}:${s.active.character}`);
const ranges = (editor) =>
	editor.selections.map((s) => `${s.anchor.line}:${s.anchor.character}>${s.active.line}:${s.active.character}`);

let failures = 0;
function test(name, fn) {
	try {
		fn();
		console.log(`  ok   ${name}`);
	} catch (e) {
		failures++;
		console.log(`  FAIL ${name}\n       ${e.message}`);
	}
}

function open(text, selections, tabSize) {
	const editor = makeEditor(text, tabSize);
	if (selections) {
		editor._selections = selections;
	}
	vscode.window.activeTextEditor = editor;
	vscode._fireSelectionChange({ selections: editor._selections, kind: 2 }); // as if clicked
	return editor;
}

const at = (line, character) => new Selection(new Position(line, character), new Position(line, character));

console.log('expand');

test('alt+j adds cursors in document order', () => {
	const ed = open('aaaa\nbbbb\ncccc\ndddd', [at(0, 2)]);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:2']);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:2', '2:2']);
});

test('alt+k adds a cursor above', () => {
	const ed = open('aaaa\nbbbb\ncccc', [at(2, 1)]);
	run('multiCursor.expandUp');
	run('multiCursor.expandUp');
	assert.deepStrictEqual(cursors(ed), ['0:1', '1:1', '2:1']);
});

test('expanding back removes the last cursor instead of growing both ways', () => {
	const ed = open('aaaa\nbbbb\ncccc\ndddd', [at(0, 2)]);
	run('multiCursor.expandDown');
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:2', '2:2']);
	run('multiCursor.expandUp');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:2']);
	run('multiCursor.expandUp');
	assert.deepStrictEqual(cursors(ed), ['0:2']);
	// Once down to one cursor, up expands again.
	run('multiCursor.expandUp');
	assert.deepStrictEqual(cursors(ed), ['0:2'], 'no line above line 0');
});

test('stops at the last line', () => {
	const ed = open('aaaa\nbbbb', [at(1, 0)]);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['1:0']);
});

test('short lines clip but the goal column survives', () => {
	const ed = open('aaaaaaaa\nbb\ncccccccc', [at(0, 6)]);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:6', '1:2'], 'clipped to end of short line');
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:6', '1:2', '2:6'], 'column 6 restored');
});

test('tabs are measured as visual columns', () => {
	//        line 0: "\tab"  -> visual columns 0,4,5
	//        line 1: "    xy" -> visual columns 0..
	const ed = open('\tab\n    xy', [at(0, 2)], 4); // after the tab and "a" => visual 5
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:5']);
});

test('expand all down / up', () => {
	const ed = open('aaa\nbbb\nccc\nddd', [at(1, 1)]);
	run('multiCursor.expandAllDown');
	assert.deepStrictEqual(cursors(ed), ['1:1', '2:1', '3:1']);
	const other = open('aaa\nbbb\nccc\nddd', [at(2, 0)]);
	run('multiCursor.expandAllUp');
	assert.deepStrictEqual(cursors(other), ['0:0', '1:0', '2:0']);
});

test('six lines keep yank register indices aligned with paste order', () => {
	const ed = open('1\n2\n3\n4\n5\n6');
	for (let i = 0; i < 5; i++) run('multiCursor.expandDown');
	const registers = ed.selections.map((s) => ed.document.lineAt(s.active.line).text);
	assert.deepStrictEqual(registers, ['1', '2', '3', '4', '5', '6']);
	// A consumer that visits paste destinations in document order must see
	// the same register index for every line.
	const pasted = registers.flatMap((value, i) => [ed.document.lineAt(i).text, value]);
	assert.deepStrictEqual(pasted, ['1', '1', '2', '2', '3', '3', '4', '4', '5', '5', '6', '6']);
});

test('last cursor remains tracked when moving past another cursor', () => {
	const ed = open('aaaa\nbbbb\ncccc', [at(1, 2)]);
	run('multiCursor.expandDown');
	run('multiCursor.moveLastCursorLeft');
	run('multiCursor.moveLastCursorUp');
	run('multiCursor.moveLastCursorUp');
	assert.deepStrictEqual(cursors(ed), ['0:1', '1:2']);
});

console.log('move last cursor');

test('alt+shift+j/k moves only the last cursor', () => {
	const ed = open('aaaa\nbbbb\ncccc\ndddd', [at(0, 2)]);
	run('multiCursor.expandDown'); // cursors 1:2 (last), 0:2
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '2:2']);
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['0:2', '3:2']);
	run('multiCursor.moveLastCursorUp');
	assert.deepStrictEqual(cursors(ed), ['0:2', '2:2']);
});

test('alt+shift+h/l moves only the last cursor horizontally', () => {
	const ed = open('aaaa\nbbbb', [at(0, 2)]);
	run('multiCursor.expandDown');
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:3']);
	run('multiCursor.moveLastCursorLeft');
	run('multiCursor.moveLastCursorLeft');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:1']);
});

test('horizontal move wraps across lines', () => {
	const ed = open('ab\ncd', [at(1, 0)]);
	run('multiCursor.moveLastCursorLeft');
	assert.deepStrictEqual(cursors(ed), ['0:2']);
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(cursors(ed), ['1:0']);
});

test('does not run off the buffer', () => {
	const ed = open('ab\ncd', [at(0, 0)]);
	run('multiCursor.moveLastCursorLeft');
	run('multiCursor.moveLastCursorUp');
	assert.deepStrictEqual(cursors(ed), ['0:0']);
	const end = open('ab\ncd', [at(1, 2)]);
	run('multiCursor.moveLastCursorRight');
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(end), ['1:2']);
});

test('vertical move keeps the goal column over short lines', () => {
	const ed = open('aaaaaaaa\nbb\ncccccccc', [at(0, 6)]);
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['1:2']);
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['2:6']);
});

test('a horizontal move forgets the goal column', () => {
	const ed = open('aaaaaaaa\nbb\ncccccccc', [at(0, 6)]);
	run('multiCursor.moveLastCursorDown');   // 1:2, goal column 6
	run('multiCursor.moveLastCursorLeft');   // 1:1, goal column dropped
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['2:1']);
});

test('a non-empty selection is extended, not collapsed', () => {
	const ed = open('aaaa\nbbbb\ncccc', [
		new Selection(new Position(0, 1), new Position(0, 3))
	]);
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(ranges(ed), ['0:1>0:4']);
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(ranges(ed), ['0:1>1:4']);
});

test('moving onto another cursor merges them', () => {
	const ed = open('aaaa\nbbbb\ncccc', [at(0, 2)]);
	run('multiCursor.expandDown');            // 1:2 (last), 0:2
	run('multiCursor.moveLastCursorUp');      // lands on 0:2
	assert.deepStrictEqual(cursors(ed), ['0:2']);
});

test('clicking elsewhere resets the remembered column', () => {
	const ed = open('aaaaaaaa\nbb\ncccccccc', [at(0, 6)]);
	run('multiCursor.moveLastCursorDown');    // 1:2, goal column 6
	vscode._fireSelectionChange({ selections: ed._selections, kind: 2 }); // user click
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['2:2'], 'column 6 forgotten after a click');
});

for (const kind of [1, 3, undefined]) {
	test(`moving all cursors preserves the last cursor (event kind ${kind})`, () => {
		const ed = open('aaaa\nbbbb\ncccc\ndddd\neeee', [at(0, 1)]);
		run('multiCursor.expandDown');
		run('multiCursor.expandDown');
		for (let step = 0; step < 2; step++) {
			ed._selections = ed.selections.map((s) => at(s.active.line + 1, 2));
			vscode._fireSelectionChange({ textEditor: ed, selections: ed.selections, kind });
		}
		run('multiCursor.moveLastCursorRight');
		assert.deepStrictEqual(cursors(ed), ['2:2', '3:2', '4:3']);
		run('multiCursor.expandUp');
		assert.deepStrictEqual(cursors(ed), ['2:2', '3:2', '3:3', '4:3']);
	});
}

test('a mouse selection resets the last cursor even with the same count', () => {
	const ed = open('aaaa\nbbbb\ncccc', [at(0, 1)]);
	run('multiCursor.expandDown');
	vscode._fireSelectionChange({ textEditor: ed, selections: ed.selections, kind: 2 });
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:1']);
});

test('changing the number of cursors resets tracking', () => {
	const ed = open('aaaa\nbbbb\ncccc', [at(0, 1)]);
	run('multiCursor.expandDown');
	run('multiCursor.expandDown');
	ed.selections = [at(0, 1), at(1, 1)];
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(cursors(ed), ['0:2', '1:1']);
});

console.log(failures ? `\n${failures} failing` : '\nall passing');
process.exit(failures ? 1 : 0);
