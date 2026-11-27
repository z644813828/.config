const vscode=require('vscode');const fs=require('node:fs/promises');const path=require('node:path');const assert=require('node:assert/strict');
const {AICommentProvider,inlineTarget}=require('./dist/analysis');
const {ContextCollector,ContinueBridge,continueCommand,QwenCodeLensProvider}=require('./dist/extension');
const {ProposalManager}=require('./dist/proposal');
exports.activate=async function(extensionContext){
 const config=require('./test-config.json');const report={tests:[],started:new Date().toISOString()};
 const root=vscode.workspace.workspaceFolders?.find(f=>f.uri.scheme==='file');let uri,doc,registration;
 const drafts=[];let manager;const previous=vscode.window.activeTextEditor;
 async function test(name,fn){try{await fn();report.tests.push({name,passed:true});}catch(e){report.tests.push({name,passed:false,error:String(e.stack||e)});}}
 const original=await fs.readFile(path.join(config.sourceRoot,'test/fixtures/horse-source.cpp'),'utf8');
 const bad=await fs.readFile(path.join(config.sourceRoot,'test/fixtures/horse-bad-replacement.cpp'),'utf8');
 const good='class Horse : public Animal {\npublic:\n  Horse(const std::string& n, int a) : Animal(n,a) {}\n  void makeSound() const override { std::cout << "Neigh!"; }\n};';
 let response=good;let call;
 try{
  assert.ok(root&&vscode.workspace.isTrusted);assert.ok(!vscode.extensions.getExtension('Continue.continue'),'Use an isolated test window without Continue');
  uri=vscode.Uri.joinPath(root.uri,`.qwen-host-test-${Date.now()}.cpp`);await vscode.workspace.fs.writeFile(uri,Buffer.from(original));doc=await vscode.workspace.openTextDocument(uri);
  const instruction=new AICommentProvider().find(original)[0];const target=inlineTarget(original,instruction);
  const command=continueCommand+'.test'+Date.now();
  registration=vscode.commands.registerCommand(command,async(prompt,range)=>{
   const draft=vscode.window.activeTextEditor.document;drafts.push(draft);call={draft,prompt,range};
   assert.equal(draft.uri.scheme,'untitled');assert.notEqual(draft.uri.toString(),uri.toString());assert.equal(draft.getText(range),instruction.raw);
   const edit=new vscode.WorkspaceEdit();edit.replace(draft.uri,range,response);assert.ok(await vscode.workspace.applyEdit(edit));
  });extensionContext.subscriptions.push(registration);
  async function begin(text=good){manager?.dispose();manager=new ProposalManager();response=text;const snapshot=(await new ContextCollector().collect(doc,target,instruction)).snapshot;await new ContinueBridge(command,manager).send(snapshot,'Implement Horse');return snapshot;}
  await test('Continue receives isolated untitled draft; original source unchanged during generation',async()=>{await begin();assert.equal(call.draft.getText(),good);assert.equal(doc.getText(),original);});
  await test('One pending draft; cannot overwrite snapshot',async()=>{const snapshot=(await new ContextCollector().collect(doc,target,instruction)).snapshot;await assert.rejects(manager.create(snapshot),/already exists/);});
  await test('Reject actual source diff leaves file unchanged',async()=>{let shown=false;await manager.review(async()=>{assert.ok(vscode.window.tabGroups.activeTabGroup.activeTab.input instanceof vscode.TabInputTextDiff);shown=true;return 'Cancel';});assert.ok(shown);assert.equal(doc.getText(),original);});
  await test('Accept actual source diff applies only Horse range',async()=>{await manager.review(async()=> 'Apply to source');assert.equal(doc.getText(),original.slice(0,target.start)+good+original.slice(target.end));for(const name of ['class Shape','class Rectangle','class Circle','int main()'])assert.equal(doc.getText().split(name).length-1,1);});
  await test('Real VS Code Undo restores entire original source',async()=>{await vscode.window.showTextDocument(doc);await vscode.commands.executeCommand('undo');assert.equal(doc.getText(),original);});
  await test('Exact reported corrupt suffix rejected before diff or source mutation',async()=>{await begin(bad);let prompts=0;await assert.rejects(manager.review(async()=>{prompts++;return 'Apply to source';}),/repeats surrounding code/);assert.equal(prompts,0);assert.equal(doc.getText(),original);});
  await test('Draft still changing during review cannot be applied',async()=>{await begin();await assert.rejects(manager.review(async()=>{const edit=new vscode.WorkspaceEdit();edit.insert(call.draft.uri,new vscode.Position(0,0),'// more streaming\n');await vscode.workspace.applyEdit(edit);return 'Apply to source';}),/draft changed/);assert.equal(doc.getText(),original);});
  await test('Source changed during generation cannot be applied',async()=>{await begin();const edit=new vscode.WorkspaceEdit();edit.insert(uri,new vscode.Position(0,0),'// concurrent\n');await vscode.workspace.applyEdit(edit);await assert.rejects(manager.review(async()=> 'Apply to source'),/File changed/);await vscode.window.showTextDocument(doc);await vscode.commands.executeCommand('undo');assert.equal(doc.getText(),original);});
  await test('Discard detaches source; later draft edits cannot be transferred',async()=>{await begin();manager.discard();await assert.rejects(manager.review(),/missing/);assert.equal(doc.getText(),original);});
  await test('CodeLens stays on source until confirmed application',async()=>{const lenses=new QwenCodeLensProvider();try{assert.equal(lenses.provideCodeLenses(doc).length,1);}finally{lenses.dispose();}});
 }catch(e){report.error=String(e.stack||e);}finally{
  manager?.dispose();registration?.dispose();
  // Only discard the exact untitled test documents; never close user buffers.
  for(const draft of drafts){if(!draft.isClosed){await vscode.window.showTextDocument(draft);await vscode.commands.executeCommand('workbench.action.revertAndCloseActiveEditor');}}
  if(doc&&!doc.isClosed){await doc.save();await vscode.window.showTextDocument(doc);await vscode.commands.executeCommand('workbench.action.closeActiveEditor');}
  if(uri)await vscode.workspace.fs.delete(uri);
  if(previous&&!previous.document.isClosed)await vscode.window.showTextDocument(previous.document);
  report.finished=new Date().toISOString();report.passed=!report.error&&report.tests.every(t=>t.passed);await fs.writeFile(config.report,JSON.stringify(report,null,2));
 }
};
