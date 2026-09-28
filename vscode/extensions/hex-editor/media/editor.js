const vscode = acquireVsCodeApi();
const $ = id => document.getElementById(id);
const viewport = $('viewport');
const hoverGuides = $('hover-guides');
function applySettings(settings) {
  const value = Number(settings.hoverOpacity);
  const opacity = Number.isFinite(value) ? Math.max(0, Math.min(100, value)) / 100 : 0.06;
  hoverGuides.style.setProperty('--hover-opacity', String(opacity));
}

let hoverPoint = null, hoverFrame = 0;
function hideHoverGuides() {
  hoverPoint = null;
  hoverGuides.hidden = true;
}
function updateHoverGuides() {
  if (hoverFrame) return;
  hoverFrame = requestAnimationFrame(() => {
    hoverFrame = 0;
    if (!hoverPoint) return;
    const { x, y } = hoverPoint;
    const bounds = viewport.getBoundingClientRect();
    const cell = document.elementFromPoint(x, y)?.closest('#rows [data-offset]');
    if (!cell || x < bounds.left || x >= bounds.left + viewport.clientWidth || y < bounds.top || y >= bounds.top + viewport.clientHeight) {
      hoverGuides.hidden = true;
      return;
    }
    hoverGuides.style.left = `${bounds.left}px`;
    hoverGuides.style.top = `${bounds.top}px`;
    hoverGuides.style.width = `${viewport.clientWidth}px`;
    hoverGuides.style.height = `${viewport.clientHeight}px`;
    const rowBounds = cell.closest('.row').getBoundingClientRect();
    const cellBounds = cell.getBoundingClientRect();
    const horizontal = hoverGuides.querySelector('.hover-horizontal');
    const vertical = hoverGuides.querySelector('.hover-vertical');
    horizontal.style.top = `${rowBounds.top - bounds.top}px`;
    horizontal.style.height = `${rowBounds.height}px`;
    vertical.style.left = `${cellBounds.left - bounds.left}px`;
    vertical.style.width = `${cellBounds.width}px`;
    hoverGuides.hidden = false;
  });
}
viewport.addEventListener('pointermove', event => {
  if (event.pointerType === 'touch') return;
  hoverPoint = { x: event.clientX, y: event.clientY };
  updateHoverGuides();
}, { passive: true });
viewport.addEventListener('pointerleave', hideHoverGuides);
window.addEventListener('blur', hideHoverGuides);
window.addEventListener('pointercancel', hideHoverGuides);

let bytes = new Uint8Array(), cursor = 0, anchor = 0, hasSelection = false, nibble = '', dragging = false;
let lastSearch = '';
let searchQuery = '', searchMode = 'hex', messageText = '', lastStatus = '';
let searchCount = null;
let matchMask = null;
let groupSize = 1, radix = 16, selectionUnit = 1;
let addressRadix = 16;
const formatAddress = value => addressRadix === 16 ? hex(value, 8) : String(value);
let editing = null;
let lastCellClick = null;
let inspectorKey = '';
let dataRevision = 0;
function renderInspector() {
  const littleEndian = $('little-endian').checked;
  const key = `${cursor}:${littleEndian}:${dataRevision}`;
  if (key === inspectorKey) return;
  inspectorKey = key;
  $('inspector-offset').textContent = bytes.length ? `Offset 0x${hex(cursor, 8)}` : 'Empty file';
  const fragment = document.createDocumentFragment();
  for (const [name, value] of Object.entries(HexCore.inspect(bytes, cursor, littleEndian))) {
    const label = document.createElement('dt'); label.textContent = name;
    const output = document.createElement('dd'); output.textContent = value; output.dataset.type = name;
    if (['End of File', 'Invalid encoding', 'Overflow (128 bits)'].includes(value)) output.className = 'unavailable';
    fragment.append(label, output);
  }
  $('inspector-values').replaceChildren(fragment);
}
$('little-endian').addEventListener('change', () => { cancelEdit(); nibble = ''; render(); });
const hex = (value, width = 2) => value.toString(16).toUpperCase().padStart(width, '0');
function updateColumns() {
  const digits = radix === 16 ? groupSize * 2 : ((1n << BigInt(groupSize * 8)) - 1n).toString().length;
  viewport.style.setProperty('--cell-width', `${Math.max(digits, groupSize > 1 ? 3 : 1)}ch`);
  document.querySelector('.heading').innerHTML = Array.from({ length: 16 / groupSize }, (_, i) => {
    const start = i * groupSize;
    const label = groupSize === 1 ? hex(start, 1) : `${hex(start, 1)}–${hex(start + groupSize - 1, 1)}`;
    return `<span class="${start + groupSize === 8 ? 'midpoint' : ''}">${label}</span>`;
  }).join('');

}
updateColumns();
function render() {
  if (searchCount && searchCount.revision !== dataRevision) resetSearchCount();
  updateHoverGuides();
  renderInspector();
  const total = Math.ceil(bytes.length / 16);
  const start = Math.max(0, Math.floor(viewport.scrollTop / 24) - 2);
  const end = Math.min(total, start + Math.ceil(viewport.clientHeight / 24) + 5);
  $('before').style.height = `${Math.min(start, total) * 24}px`;
  $('after').style.height = `${Math.max(0, total - end) * 24}px`;
  const fragment = document.createDocumentFragment();
  const low = Math.min(anchor, cursor), high = Math.min(bytes.length - 1, Math.max(anchor, cursor) + selectionUnit - 1);
  for (let row = start; row < end; row++) {
    const line = document.createElement('div'); line.className = 'row';
    const offset = document.createElement('span'); offset.className = 'offset'; offset.textContent = hex(row * 16, 8); line.append(offset);
    const values = document.createElement('span'); values.className = 'hex';
    const ascii = document.createElement('span'); ascii.className = 'ascii';
    for (let col = 0; col < 16; col += groupSize) {
      const index = row * 16 + col;
      const cell = document.createElement('span'); cell.className = 'byte';
      if (col + groupSize === 8) cell.classList.add('midpoint');
      if (index < bytes.length) {
        cell.dataset.offset = index; cell.dataset.length = groupSize;
        cell.textContent = HexCore.formatUnsigned(bytes, index, groupSize, radix, $('little-endian').checked);
        if (groupSize === 1 && radix === 16 && index === cursor && nibble) cell.textContent = nibble + '·';
        if (index + groupSize > bytes.length) cell.classList.add('incomplete');
        if (matchMask?.subarray(index, index + groupSize).some(value => value)) cell.classList.add('search-match');
        if (hasSelection && index <= high && index + groupSize - 1 >= low) cell.classList.add('selected');
        if (cursor >= index && cursor < index + groupSize) cell.classList.add('cursor');
        if (index === cursor && nibble) cell.classList.add('pending');
      }
      values.append(cell);
    }
    for (let col = 0; col < 16; col++) {
      const index = row * 16 + col;
      const cell = document.createElement('span'); cell.className = 'char';
      if (index < bytes.length) {
        cell.dataset.offset = index; cell.dataset.length = 1;
        cell.textContent = bytes[index] >= 32 && bytes[index] <= 126 ? String.fromCharCode(bytes[index]) : '.';
        if (matchMask?.[index]) cell.classList.add('search-match');
        if (hasSelection && index >= low && index <= high) cell.classList.add('selected');
        if (index === cursor) cell.classList.add('cursor');
      } else cell.textContent = ' ';
      ascii.append(cell);
    }
    line.append(values, ascii); fragment.append(line);
  }
  $('rows').replaceChildren(fragment);
  publishStatus();
}
function select(offset, extend = false, reveal = true, unit = 1) {
  if (!bytes.length) return;
  selectionUnit = unit;
  cursor = Math.max(0, Math.min(bytes.length - 1, offset));
  if (!extend) anchor = cursor;
  hasSelection = true; nibble = '';
  if (reveal) {
    const top = Math.floor(cursor / 16) * 24;
    if (top < viewport.scrollTop) viewport.scrollTop = top;
    else if (top + 48 > viewport.scrollTop + viewport.clientHeight) viewport.scrollTop = top + 48 - viewport.clientHeight;
  }
  render();
}
// Replacing virtual rows must not make the browser anchor to moving spacers.
// Coalesce scroll events so rendering cannot build a backlog during fast scrolling.
let scrollFrame = 0;
viewport.addEventListener('scroll', () => {
  if (scrollFrame) return;
  scrollFrame = requestAnimationFrame(() => { scrollFrame = 0; render(); });
}, { passive: true });
new ResizeObserver(render).observe(viewport);
viewport.addEventListener('pointerdown', event => {
  const target = event.target.closest('[data-offset]');
  if (!target || event.button !== 0) return;
  event.preventDefault(); viewport.focus(); dragging = true;
  // Virtual rows are replaced after selection, so browser dblclick targets are unstable.
  const now = performance.now();
  const index = Number(target.dataset.offset);
  const editCell = target.classList.contains('byte') && lastCellClick?.offset === index && now - lastCellClick.time < 500;
  lastCellClick = target.classList.contains('byte') && !editCell ? { offset: index, time: now } : null;
  select(Number(target.dataset.offset), event.shiftKey, false, Number(target.dataset.length));
  if (editCell) { dragging = false; beginEdit(); }
});
window.addEventListener('pointermove', event => {
  if (!dragging) return;
  if (!(event.buttons & 1)) { dragging = false; return; }
  const bounds = viewport.getBoundingClientRect();
  if (event.clientY < bounds.top + 24) viewport.scrollTop -= 24;
  if (event.clientY > bounds.bottom - 24) viewport.scrollTop += 24;
  const target = document.elementFromPoint(event.clientX, Math.max(bounds.top + 25, Math.min(bounds.bottom - 1, event.clientY)))?.closest('[data-offset]');
  if (target) select(Number(target.dataset.offset), true, false, Number(target.dataset.length));
});
window.addEventListener('pointerup', () => { dragging = false; });
window.addEventListener('pointercancel', () => { dragging = false; });
window.addEventListener('blur', () => { dragging = false; });
function publishStatus() {
  const low = Math.min(anchor, cursor);
  const high = Math.min(bytes.length - 1, Math.max(anchor, cursor) + selectionUnit - 1);
  const state = { cursor, length: bytes.length, selected: hasSelection && bytes.length ? high - low + 1 : 0,
    low, high, groupSize, radix, addressRadix, query: searchQuery, mode: searchMode,
    matches: searchCount?.total ?? null, message: messageText };
  const key = JSON.stringify(state);
  if (key !== lastStatus) { lastStatus = key; vscode.postMessage({ type: 'status', state }); }
}
function setMessage(value) { messageText = value; publishStatus(); }
function resetSearchCount() {
  if (searchCount) { hasSelection = false; anchor = cursor; selectionUnit = 1; }
  searchCount = null; matchMask = null; lastSearch = ''; messageText = '';
}
function requestInput(action) {
  cancelEdit(); hideHoverGuides();
  vscode.postMessage({ type: 'command', action });
}
function applyAction(message) {
  if (message.action === 'goto') {
    if (message.addressRadix === 10 || message.addressRadix === 16) addressRadix = message.addressRadix;
    if (Number.isInteger(message.offset) && message.offset >= 0 && message.offset < bytes.length) select(message.offset);
  } else if (message.action === 'addressRadix') {
    if ([10, 16].includes(message.value)) addressRadix = message.value;
    render();
  } else if (message.action === 'group' || message.action === 'radix') {
    if (message.action === 'group' && [1, 2, 4, 8].includes(message.value)) groupSize = message.value;
    if (message.action === 'radix' && [10, 16].includes(message.value)) radix = message.value;
    cancelEdit(); nibble = ''; selectionUnit = 1; updateColumns(); render();
  } else if (message.action === 'page') {
    const page = 16 * Math.max(1, Math.floor(viewport.clientHeight / 24) - 1);
    select(cursor + (message.direction === -1 ? -page : page), false, true, selectionUnit);
  } else if (message.action === 'move') {
    const step = selectionUnit > 1 && Math.abs(message.delta) === 1 ? groupSize : 1;
    const target = cursor + message.delta * step;
    const lastGroup = Math.floor((bytes.length - 1) / step) * step;
    select(selectionUnit > 1 && message.delta > 0 ? Math.min(lastGroup, target) : target, Boolean(message.extend), true, selectionUnit);
  } else if (message.action === 'search' || message.action === 'query') {
    if (typeof message.query === 'string' && (searchQuery !== message.query || searchMode !== message.mode)) {
      searchQuery = message.query; searchMode = message.mode === 'text' ? 'text' : 'hex'; resetSearchCount();
    }
    if (message.action === 'search') search(message.direction === -1 ? -1 : 1);
    else render();
  }
}
window.addEventListener('keydown', event => {
  const mod = event.ctrlKey || event.metaKey;
  if (mod && !event.shiftKey && !event.altKey && ['f', 'g'].includes(event.key.toLowerCase())) {
    event.preventDefault(); event.stopImmediatePropagation();
    requestInput(event.key.toLowerCase() === 'g' ? 'goto' : 'find');
  }
}, { capture: true });
viewport.addEventListener('keydown', event => {
  const mod = event.ctrlKey || event.metaKey;
  if (mod && ['z', 'y'].includes(event.key.toLowerCase())) {
    event.preventDefault(); nibble = ''; vscode.postMessage({ type: event.key.toLowerCase() === 'y' || event.shiftKey ? 'redo' : 'undo' }); render(); return;
  }
  if (mod && event.key.toLowerCase() === 'a') { event.preventDefault(); anchor = 0; select(bytes.length - 1, true); return; }
  if (event.ctrlKey && !event.metaKey && !event.altKey && !event.shiftKey && ['u', 'd'].includes(event.key.toLowerCase())) {
    event.preventDefault();
    const page = 16 * Math.max(1, Math.floor(viewport.clientHeight / 24) - 1);
    select(cursor + (event.key.toLowerCase() === 'u' ? -page : page), false, true, selectionUnit);
    return;
  }
  if (mod || event.altKey) return;
  const step = selectionUnit > 1 ? groupSize : 1;
  const steps = { ArrowLeft: -step, ArrowRight: step, ArrowUp: -16, ArrowDown: 16, PageUp: -16 * Math.max(1, Math.floor(viewport.clientHeight / 24) - 1), PageDown: 16 * Math.max(1, Math.floor(viewport.clientHeight / 24) - 1) };
  if (event.key in steps) { event.preventDefault(); select(selectionUnit > 1 ? Math.min(Math.floor((bytes.length - 1) / groupSize) * groupSize, cursor + steps[event.key]) : cursor + steps[event.key], event.shiftKey, true, selectionUnit); }
  else if (event.key === 'Home' || event.key === 'End') { event.preventDefault(); select(Math.min(Math.floor(cursor / 16) * 16 + (event.key === 'End' ? 16 - step : 0), Math.floor((bytes.length - 1) / step) * step), event.shiftKey, true, selectionUnit); }
  else if (event.key === 'Enter') { event.preventDefault(); beginEdit(); }
  else if (event.key === 'Escape') { nibble = ''; hasSelection = false; render(); }
  else if (/^[0-9a-f]$/i.test(event.key) && bytes.length) {
    event.preventDefault();
    if (groupSize !== 1 || radix !== 16) {
      if (radix === 16 || /^[0-9]$/.test(event.key)) beginEdit(event.key);
      return;
    }
    if (!nibble) { nibble = event.key.toUpperCase(); render(); }
    else {
      const value = parseInt(nibble + event.key, 16);
      bytes[cursor] = value; dataRevision++; vscode.postMessage({ type: 'edit', offset: cursor, value }); select(cursor + 1);
    }
  }
});
function cancelEdit() {
  editing = null; $('edit-group').hidden = true;
}
function beginEdit(initial) {
  const offset = Math.floor(cursor / groupSize) * groupSize;
  if (offset + groupSize > bytes.length) { setMessage('Incomplete group at end of file. Choose a smaller integer type to edit these bytes.'); return; }
  editing = { offset, width: groupSize, radix, littleEndian: $('little-endian').checked };
  nibble = '';
  select(offset, false, true, groupSize);
  $('edit-label').textContent = `0x${hex(offset, 8)} · uint${groupSize * 8}_t (${radix === 16 ? 'Hex' : 'Decimal'})`;
  $('edit-group').hidden = false;
  $('edit-value').value = initial === undefined ? HexCore.formatUnsigned(bytes, offset, groupSize, radix, editing.littleEndian) : initial;
  $('edit-value').focus();
  if (initial === undefined) $('edit-value').select();
}
$('edit-group').addEventListener('submit', event => {
  event.preventDefault();
  if (!editing) return;
  try {
    const { offset, width, radix: base, littleEndian } = editing;
    const values = HexCore.encodeUnsigned($('edit-value').value, width, base, littleEndian);
    bytes.set(values, offset); dataRevision++;
    vscode.postMessage({ type: 'edit', offset, values: Array.from(values) });
    cancelEdit(); setMessage(''); select(offset, false, true, width); viewport.focus();
  } catch (error) { setMessage(error.message); }
});
$('cancel-edit').addEventListener('click', () => { cancelEdit(); viewport.focus(); });
$('edit-value').addEventListener('keydown', event => {
  if (event.key === 'Escape') { event.preventDefault(); cancelEdit(); viewport.focus(); }
});
function search(direction) {
  if (!searchQuery.length || (searchMode === 'hex' && !searchQuery.trim())) { resetSearchCount(); render(); return; }
  try {
    const pattern = HexCore.pattern(searchQuery, searchMode);
    if (!pattern.length) throw new Error('Enter a search pattern.');
    const key = searchMode + ':' + searchQuery;
    if (!searchCount || searchCount.key !== key || searchCount.revision !== dataRevision) {
      matchMask = new Uint8Array(bytes.length);
      let markedEnd = 0;
      const total = HexCore.countMatches(bytes, pattern, offset => {
        const end = offset + pattern.length;
        matchMask.fill(1, Math.max(offset, markedEnd), end);
        markedEnd = end;
      });
      searchCount = { key, revision: dataRevision, total };
    }

    const start = key === lastSearch ? Math.min(anchor, cursor) + direction : cursor;
    const found = HexCore.find(bytes, pattern, start, direction);
    lastSearch = key;
    setMessage('');
    if (found < 0) { hasSelection = false; render(); return; }
    anchor = found + pattern.length - 1; select(found, true);
  } catch (error) { setMessage(error.message); }
}
window.addEventListener('message', event => {
  const message = event.data;
  if (message.type === 'settings') {
    applySettings(message);
  } else if (message.type === 'action') {
    applyAction(message);
  } else if (message.type === 'data') {
    cancelEdit(); selectionUnit = 1;
    dataRevision++;
    bytes = Uint8Array.from(atob(message.bytes), c => c.charCodeAt(0));
    cursor = Math.min(cursor, Math.max(0, bytes.length - 1)); anchor = cursor; nibble = ''; hasSelection = false; lastSearch = ''; render();
    requestAnimationFrame(() => viewport.focus({ preventScroll: true }));
  } else if (message.type === 'patch') { bytes.set(message.values || [message.value], message.offset); dataRevision++; render(); }
});
vscode.postMessage({ type: 'ready' });
