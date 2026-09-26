const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1100, height: 700 } });
    const media = path.join(__dirname, '../media');
    const html = fs.readFileSync(path.join(media, 'editor.html'), 'utf8')
      .replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/, '')
      .replace(/<link[^>]*>/g, '').replace(/<script[^>]*><\/script>/g, '');
    await page.setContent(html);
    await page.addStyleTag({ path: path.join(media, 'editor.css') });
    await page.evaluate(() => {
      window.__messages = [];
      window.acquireVsCodeApi = () => ({ postMessage: value => window.__messages.push(value) });
    });
    await page.addScriptTag({ path: path.join(media, 'core.js') });
    await page.addScriptTag({ path: path.join(media, 'editor.js') });
    await page.evaluate(() => window.postMessage({ type: 'data', bytes: btoa(String.fromCharCode(0, 1, 9, 0, 1)) }, '*'));
    await page.waitForFunction(() => document.querySelectorAll('#rows .row').length > 0);
    assert.equal(await page.locator('footer').count(), 0);
    assert.equal(await page.locator('#search, #goto, #find-status').count(), 0);
    await page.locator('.byte[data-offset="3"]').click();
    const state = await page.evaluate(() => window.__messages.filter(value => value.type === 'status').at(-1).state);
    assert.equal(state.cursor, 3);
    assert.equal(state.length, 5);
    assert.equal(state.groupSize, 1);
    await page.evaluate(() => window.postMessage({ type: 'action', action: 'goto', offset: 0 }, '*'));
    await page.evaluate(() => window.postMessage({ type: 'action', action: 'query', query: '00 01', mode: 'hex' }, '*'));
    await page.evaluate(() => window.postMessage({ type: 'action', action: 'search', direction: 1 }, '*'));
    await page.waitForFunction(() => document.querySelectorAll('.search-match').length === 8);
    const matched = await page.evaluate(() => window.__messages.filter(value => value.type === 'status').at(-1).state);
    assert.equal(matched.matches, 2);
    assert.equal(matched.cursor, 0);
    assert.equal(matched.selected, 2);
    await page.evaluate(() => window.postMessage({ type: 'action', action: 'group', value: 4 }, '*'));
    assert.equal(await page.locator('.byte').count(), 4);
    await page.evaluate(() => window.postMessage({ type: 'action', action: 'radix', value: 10 }, '*'));
    const changed = await page.evaluate(() => window.__messages.filter(value => value.type === 'status').at(-1).state);
    assert.equal(changed.groupSize, 4);
    assert.equal(changed.radix, 10);
    console.log('PASS: status updates, external actions, search, grouping and no webview footer');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
