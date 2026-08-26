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

test('alt+j adds a cursor below, last cursor stays primary', () => {
	const ed = open('aaaa\nbbbb\ncccc\ndddd', [at(0, 2)]);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['1:2', '0:2']);
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['2:2', '1:2', '0:2']);
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
	assert.deepStrictEqual(cursors(ed), ['2:2', '1:2', '0:2']);
	run('multiCursor.expandUp');
	assert.deepStrictEqual(cursors(ed), ['1:2', '0:2']);
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
	assert.deepStrictEqual(cursors(ed), ['1:2', '0:6'], 'clipped to end of short line');
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['2:6', '1:2', '0:6'], 'column 6 restored');
});

test('tabs are measured as visual columns', () => {
	//        line 0: "\tab"  -> visual columns 0,4,5
	//        line 1: "    xy" -> visual columns 0..
	const ed = open('\tab\n    xy', [at(0, 2)], 4); // after the tab and "a" => visual 5
	run('multiCursor.expandDown');
	assert.deepStrictEqual(cursors(ed), ['1:5', '0:2']);
});

test('expand all down / up', () => {
	const ed = open('aaa\nbbb\nccc\nddd', [at(1, 1)]);
	run('multiCursor.expandAllDown');
	assert.deepStrictEqual(cursors(ed), ['3:1', '2:1', '1:1']);
	const other = open('aaa\nbbb\nccc\nddd', [at(2, 0)]);
	run('multiCursor.expandAllUp');
	assert.deepStrictEqual(cursors(other), ['0:0', '1:0', '2:0']);
});

console.log('move last cursor');

test('alt+shift+j/k moves only the last cursor', () => {
	const ed = open('aaaa\nbbbb\ncccc\ndddd', [at(0, 2)]);
	run('multiCursor.expandDown'); // cursors 1:2 (last), 0:2
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['2:2', '0:2']);
	run('multiCursor.moveLastCursorDown');
	assert.deepStrictEqual(cursors(ed), ['3:2', '0:2']);
	run('multiCursor.moveLastCursorUp');
	assert.deepStrictEqual(cursors(ed), ['2:2', '0:2']);
});

test('alt+shift+h/l moves only the last cursor horizontally', () => {
	const ed = open('aaaa\nbbbb', [at(0, 2)]);
	run('multiCursor.expandDown');
	run('multiCursor.moveLastCursorRight');
	assert.deepStrictEqual(cursors(ed), ['1:3', '0:2']);
	run('multiCursor.moveLastCursorLeft');
	run('multiCursor.moveLastCursorLeft');
	assert.deepStrictEqual(cursors(ed), ['1:1', '0:2']);
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

console.log(failures ? `\n${failures} failing` : '\nall passing');
process.exit(failures ? 1 : 0);
