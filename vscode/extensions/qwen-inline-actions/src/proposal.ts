import * as vscode from 'vscode';
import { randomUUID } from 'node:crypto';
import { assertFresh, validateReplacement } from './analysis';
import type { Snapshot } from './extension';

interface Proposal { snapshot: Snapshot; draft: vscode.TextDocument }
export class ProposalManager implements vscode.Disposable, vscode.TextDocumentContentProvider {
  private pending?: Proposal;
  private reviewing = false;
  private readonly scheme = `qwen-review-${randomUUID()}`;
  private readonly contents = new Map<string, string>();
  private registration?: vscode.Disposable;
  private readonly status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 90);
  constructor() {
    this.status.text = '$(diff) Qwen: Review result';
    this.status.command = 'qwenInlineActions.review';
    this.status.tooltip = 'First finish and accept/reject the Continue diff in the draft, then review the source change.';
  }
  provideTextDocumentContent(uri: vscode.Uri): string { return this.contents.get(uri.toString()) ?? ''; }
  get active(): boolean { return !!this.pending; }
  async create(snapshot: Snapshot): Promise<vscode.TextDocument> {
    if (this.pending) throw new Error('Continue draft already exists. Review or discard it first.');
    this.fresh(snapshot);
    const draft = await vscode.workspace.openTextDocument({ language: snapshot.doc.languageId, content: snapshot.text.slice(snapshot.target.start, snapshot.target.end) });
    this.pending = { snapshot, draft }; this.status.show();
    return draft;
  }
  private fresh(s: Snapshot): void {
    if (s.doc.isClosed) throw new Error('Source document was closed.');
    assertFresh(s.version, s.doc.version, s.text, s.doc.getText());
  }
  /** Explicit user action. No source mutation until the immutable diff is accepted. */
  async review(decide: () => Thenable<string | undefined> = () => vscode.window.showInformationMessage('Review the source diff. Finished the Continue draft?', 'Apply to source', 'Cancel')): Promise<void> {
    if (this.reviewing) return;
    const pending = this.pending;
    if (!pending || pending.draft.isClosed) throw new Error('Continue draft is missing. Generate again.');
    this.reviewing = true;
    const id = randomUUID();
    const before = vscode.Uri.parse(`${this.scheme}:/${id}/original.cpp`);
    const after = vscode.Uri.parse(`${this.scheme}:/${id}/proposed.cpp`);
    try {
      const { snapshot, draft } = pending;
      this.fresh(snapshot);
      const draftVersion = draft.version;
      const replacement = draft.getText().replace(/\r?\n/g, snapshot.doc.eol === vscode.EndOfLine.CRLF ? '\r\n' : '\n');
      validateReplacement(snapshot.text, snapshot.target, replacement);
      if (!this.registration) this.registration = vscode.workspace.registerTextDocumentContentProvider(this.scheme, this);
      this.contents.set(before.toString(), snapshot.text);
      this.contents.set(after.toString(), snapshot.text.slice(0, snapshot.target.start) + replacement + snapshot.text.slice(snapshot.target.end));
      await vscode.commands.executeCommand('vscode.diff', before, after, 'Qwen: original ↔ proposed source', { preview: true });
      if (await decide() !== 'Apply to source') return;
      if (this.pending !== pending) throw new Error('Continue draft was discarded.');
      this.fresh(snapshot);
      if (draft.isClosed || draft.version !== draftVersion) throw new Error('Continue draft changed during review. Finish generation and review again.');
      if (!vscode.workspace.isTrusted || !vscode.workspace.getConfiguration('qwenInlineActions', snapshot.doc.uri).get('enabled', true)) throw new Error('Workspace or extension is disabled.');
      const edit = new vscode.WorkspaceEdit();
      edit.replace(snapshot.doc.uri, new vscode.Range(snapshot.doc.positionAt(snapshot.target.start), snapshot.doc.positionAt(snapshot.target.end)), replacement);
      if (!await vscode.workspace.applyEdit(edit)) throw new Error('Source edit was rejected by VS Code.');
      this.pending = undefined; this.status.hide();
      await vscode.window.showTextDocument(snapshot.doc, { preview: false });
    } finally {
      const tabs = vscode.window.tabGroups.all.flatMap(g => g.tabs).filter(t => t.input instanceof vscode.TabInputTextDiff && t.input.modified.toString() === after.toString());
      if (tabs.length) await vscode.window.tabGroups.close(tabs, true);
      this.contents.delete(before.toString()); this.contents.delete(after.toString());
      this.reviewing = false;
    }
  }
  discard(): void { this.pending = undefined; this.status.hide(); }
  dispose(): void { this.discard(); this.status.dispose(); this.registration?.dispose(); this.contents.clear(); }
}
