const {test} = require('node:test');
const assert = require('node:assert/strict');
const {AICommentProvider, enclosingBlocks, assertFresh, safeSourcePath, assertNoSecrets} = require('../dist/analysis');
const find = s => new AICommentProvider().find(s);
test('single-line instruction and offset', () => { const s='int f(){\n // AI: implement\n}'; const [c]=find(s); assert.equal(c.text,'implement');assert.equal(s.slice(c.start,c.end),c.raw); });
test('consecutive instructions stay separate; multiline comment instructions', () => { assert.equal(find('// AI: one\n// - two\n// AI: three')[0].text,'one\n- two');assert.equal(find('/*\n * AI: one\n * two\n */')[0].text,'one\ntwo');assert.equal(find('// AI: one\n// AI: two').length,2); });
test('ignore ordinary, escaped, character and raw string contents', () => {assert.equal(find('auto a="// AI: nope"; auto b=R"tag(/* AI: nope */)tag"; char c=\'"\'; auto d="escaped\\\" // AI: no";').length,0);});
test('escaped newline line comment cannot introduce braces', () => { const s='int f(){\n// text \\\n }\n// AI: ok\n}';assert.equal(enclosingBlocks(s,find(s)[0]).length,1);});
test('balanced enclosing blocks ignore string/comment braces', () => {const s='void f(){ if(true){ // AI: test\n puts("}"); /* } */ } }';const blocks=enclosingBlocks(s,find(s)[0]);assert.equal(blocks.length,2);assert.equal(s.slice(blocks[0].start,blocks[0].end),'{ // AI: test\n puts("}"); /* } */ }');});
test('version and text both checked even edit then Undo',()=>{assert.throws(()=>assertFresh(1,2,'same','same'));assert.throws(()=>assertFresh(1,1,'a','b'));assertFresh(1,1,'a','a');});
test('secret paths and common embedded credentials blocked',()=>{for(const p of ['/w/.git/a.cpp','/w/.env/a.cpp','/w/.codex/auth.cpp','/w/secrets/a.h'])assert.equal(safeSourcePath(p),false);assert.equal(safeSourcePath('src/main.cpp'),true);assert.throws(()=>assertNoSecrets('const char* password = "hunter2";'));});
test('prefixed characters and digit separators preserve following instructions',()=>{const s="auto c=L'\\\"'; auto n=1'000; // AI: ok";assert.equal(find(s).length,1);assert.equal(find(s)[0].text,'ok');});
const {inlineTarget} = require('../dist/analysis');
test('inline range preserves surrounding functions and expands indentation only',()=>{
  const source='int before(){return 1;}\n  int target(){\n// AI: test\n}\nint after(){return 2;}';
  const start=source.indexOf('int target');const end=source.indexOf('\nint after');const span=inlineTarget(source,{start,end});
  const edited=source.slice(0,span.start)+'int target(){return 3;}'+source.slice(span.end);
  assert.equal(edited,'int before(){return 1;}\nint target(){return 3;}\nint after(){return 2;}');
});
test('inline range rejects adjacent code on either boundary',()=>{
  assert.throws(()=>inlineTarget('void a(){} void b(){}',{start:11,end:21}),/Invalid|shares a line/);
  assert.throws(()=>inlineTarget('void a(){} void b(){}',{start:0,end:10}),/shares a line/);
});
test('exclusive column-zero end never includes next function',()=>{
  const source='void a(){}\r\nvoid b(){}';const end=source.indexOf('void b');const span=inlineTarget(source,{start:0,end});assert.equal(source.slice(span.end),'\nvoid b(){}');
});
test('Mouse class fallback includes header and trailing semicolon',()=>{
 const source='class Mouse {\n  // AI: реализуй мышь\n};';
 const span=inlineTarget(source,enclosingBlocks(source,find(source)[0])[0]);
 assert.deepEqual(span,{start:0,end:source.length});
});
test('class symbol ending at brace includes only its semicolon',()=>{
 const source='class Mouse {\n// AI: implement\n};\nint untouched;';
 const span=inlineTarget(source,{start:0,end:source.indexOf('}')+1});
 assert.equal(source.slice(span.end),'\nint untouched;');
 assert.throws(()=>inlineTarget(source.replace('};','}; int other;'),{start:0,end:source.indexOf('}')+1}),/shares a line/);
});
test('struct fallback and class with separate brace retain safe boundaries',()=>{
 const source='struct Mouse {\n// AI: test\n};';
 assert.equal(inlineTarget(source,enclosingBlocks(source,find(source)[0])[0]).start,0);
 const separate='class Mouse\n{\n// AI: test\n};';
 assert.doesNotThrow(()=>inlineTarget(separate,enclosingBlocks(separate,find(separate)[0])[0]));
});
const {validateReplacement} = require('../dist/analysis');
const fs = require('node:fs');const path = require('node:path');
const horseSource=fs.readFileSync(path.join(__dirname,'fixtures/horse-source.cpp'),'utf8');
const horseBad=fs.readFileSync(path.join(__dirname,'fixtures/horse-bad-replacement.cpp'),'utf8');
const horseInstruction=find(horseSource)[0];
test('reported Horse corruption: reject exact repeated Shape/Rectangle/Circle/main suffix',()=>{
 assert.throws(()=>validateReplacement(horseSource,horseInstruction,horseBad),/repeats surrounding code/);
});
test('Horse insertion accepts target-only replacement',()=>{
 const horse='class Horse : public Animal {\npublic:\n  Horse(const std::string& n, int a) : Animal(n,a) {}\n  void makeSound() const override { std::cout << "Neigh!"; }\n};';
 assert.doesNotThrow(()=>validateReplacement(horseSource,horseInstruction,horse));
 const result=horseSource.slice(0,horseInstruction.start)+horse+horseSource.slice(horseInstruction.end);
 for(const token of ['class Shape','class Rectangle','class Circle','int main()'])assert.equal(result.split(token).length-1,1);
});
test('empty, unchanged and fenced drafts rejected',()=>{
 for(const text of ['',horseSource.slice(horseInstruction.start,horseInstruction.end),'```cpp\nclass Horse {};\n```'])assert.throws(()=>validateReplacement(horseSource,horseInstruction,text));
});
