export interface Span { start: number; end: number }
export interface Instruction extends Span { text: string; raw: string }

/** Offset-preserving lexer. Strings, raw strings and comments cannot create braces or instructions. */
export function lex(source: string): { code: string; comments: (Span & { raw: string })[] } {
  const chars = source.split('');
  const comments: (Span & { raw: string })[] = [];
  const mask = (a: number, b: number) => { for (let k = a; k < b; k++) if (chars[k] !== '\n' && chars[k] !== '\r') chars[k] = ' '; };
  let i = 0;
  while (i < source.length) {
    const start = i;
    if (source.startsWith('//', i)) {
      i = source.indexOf('\n', i);
      if (i < 0) i = source.length;
      // Translation phase 2: a continued line comment remains a comment.
      while (i < source.length && /\\\r?$/.test(source.slice(start, i))) {
        const next = source.indexOf('\n', i + 1); i = next < 0 ? source.length : next;
      }
      comments.push({ start, end: i, raw: source.slice(start, i) }); mask(start, i);
    } else if (source.startsWith('/*', i)) {
      const end = source.indexOf('*/', i + 2); i = end < 0 ? source.length : end + 2;
      if (end >= 0) comments.push({ start, end: i, raw: source.slice(start, i) });
      mask(start, i);
    } else if (source.startsWith('R"', i)) {
      const m = /^R"([^\s()\\]{0,16})\(/.exec(source.slice(i));
      if (m) { const end = source.indexOf(`)${m[1]}"`, i + m[0].length); i = end < 0 ? source.length : end + m[1].length + 2; mask(start, i); }
      else i++;
    } else if (source[i] === '"' || (source[i] === "'" && (!/[\w]/.test(source[i - 1] ?? '') || /(?:^|[^\w])(?:u8|u|U|L)$/.test(source.slice(Math.max(0, i - 4), i))))) {
      const quote = source[i++];
      while (i < source.length) { if (source[i] === '\\') { i += 2; continue; } if (source[i++] === quote) break; }
      i = Math.min(i, source.length); mask(start, i);
    } else i++;
  }
  return { code: chars.join(''), comments };
}

export class AICommentProvider {
  find(source: string): Instruction[] {
    const comments = lex(source).comments;
    const result: Instruction[] = [];
    for (let i = 0; i < comments.length; i++) {
      const c = comments[i];
      const body = c.raw.startsWith('//') ? c.raw.slice(2) : c.raw.slice(2, -2).replace(/^\s*\* ?/gm, '');
      const m = /^\s*AI:\s*([\s\S]*?)\s*$/.exec(body);
      if (!m || !m[1]) continue;
      let end = c.end; let text = m[1];
      if (c.raw.startsWith('//')) while (i + 1 < comments.length) {
        const next = comments[i + 1];
        if (!next.raw.startsWith('//') || !/^\r?\n[\t ]*$/.test(source.slice(end, next.start)) || /^\/\/\s*AI:/.test(next.raw)) break;
        text += '\n' + next.raw.slice(2).trim(); end = next.end; i++;
      }
      result.push({ start: c.start, end, text, raw: source.slice(c.start, end) });
    }
    return result;
  }
}

/** Fallback offers enclosing balanced blocks; it never silently guesses a function signature. */
export function enclosingBlocks(source: string, instruction: Span): Span[] {
  const code = lex(source).code; const stack: number[] = []; const spans: Span[] = [];
  for (let i = 0; i < code.length; i++) {
    if (code[i] === '{') stack.push(i);
    if (code[i] === '}') { const start = stack.pop(); if (start !== undefined && start <= instruction.start && i >= instruction.end) spans.push(declarationBlock(source, { start, end: i + 1 })); }
  }
  return spans.sort((a, b) => a.end - a.start - (b.end - b.start));
}

/** Recognize a simple class header in fallback; never absorb another declaration. */
function declarationBlock(source: string, span: Span): Span {
  const lineStart = source.lastIndexOf('\n', span.start - 1) + 1;
  const header = source.slice(lineStart, span.start);
  if (/^\s*(?:class|struct|union)\s+[A-Za-z_]\w*(?:\s+final)?(?:\s*:\s*[^;{}=()]+)?\s*$/.test(header)) return { start: lineStart, end: span.end };
  return span;
}

export function assertFresh(version: number, currentVersion: number, original: string, current: string): void {
  if (version !== currentVersion || original !== current) throw new Error('File changed; generate again.');
}

export function safeSourcePath(path: string): boolean {
  return !/(^|[/\\])(\.git|\.env[^/\\]*|\.ssh|\.codex|secrets?|credentials?|auth)([/\\.]|$)/i.test(path) && /\.(c|cc|cpp|cxx|h|hh|hpp|hxx)$/i.test(path);
}

export function assertNoSecrets(text: string): void {
  if (/-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:password|passwd|api[_-]?key|access[_-]?token|secret)\s*[:=]\s*["'][^"'\n]+["']|\b(?:ghp_|sk-)[a-zA-Z0-9_-]{16,}/i.test(text)) throw new Error('Potential secret in context; remove it before sending.');
}

/** Continue edits whole lines; never silently include adjacent code. */
export function inlineTarget(source: string, span: Span): Span {
  if (!Number.isInteger(span.start) || !Number.isInteger(span.end) || span.start < 0 || span.end > source.length || span.end <= span.start) throw new Error('Invalid inline edit range.');
  const start = span.start === 0 ? 0 : source.lastIndexOf('\n', span.start - 1) + 1;
  const last = source[span.end - 1] === '\n' ? span.end - 1 : span.end;
  const next = source.indexOf('\n', last);
  const end = next < 0 ? source.length : next;
  const suffix = source.slice(span.end, end).trim();
  const terminator = source[span.end - 1] === '}' && suffix === ';';
  if (source.slice(start, span.start).trim() || (suffix && !terminator)) throw new Error('Target shares a line with other code. Put the function/block on separate lines before using Continue inline edit.');
  return { start, end };
}

/** Reject echoed surrounding declarations before transferring a draft to the source. */
export function validateReplacement(source: string, target: Span, replacement: string): void {
  if (!replacement.trim() || replacement.length > 256_000 || replacement.includes('\0') || /^\s*```/m.test(replacement)) throw new Error('Continue draft is empty, too large, or contains markdown.');
  if (replacement === source.slice(target.start, target.end)) throw new Error('Continue draft has no changes.');
  const normalize = (text: string) => text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  const proposed = '\n' + normalize(replacement).join('\n') + '\n';
  const selected = '\n' + normalize(source.slice(target.start, target.end)).join('\n') + '\n';
  for (const outside of [source.slice(0, target.start), source.slice(target.end)]) {
    const lines = normalize(outside);
    for (let i = 0; i + 3 <= lines.length; i++) {
      const block = '\n' + lines.slice(i, i + 3).join('\n') + '\n';
      if (block.length >= 70 && proposed.includes(block) && !selected.includes(block)) throw new Error('Continue draft repeats surrounding code. Source was not changed. Discard the draft and generate again.');
    }
  }
}
