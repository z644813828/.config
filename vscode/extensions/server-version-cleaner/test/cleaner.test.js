'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { clean, installation } = require('../cleaner');
const commit = n => n.toString(16).padStart(40, '0');
async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'server-cleaner-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  async function add(n, modern = true, channel = 'Stable') {
    const dir = path.join(root, modern ? `cli/servers/${channel}-${commit(n)}` : `bin/${commit(n)}`);
    const app = modern ? path.join(dir, 'server') : dir;
    await fs.mkdir(app, { recursive: true });
    await fs.writeFile(path.join(app, 'product.json'), JSON.stringify({ commit: commit(n), date: `2026-01-${String(n).padStart(2, '0')}T00:00:00Z` }));
    return { dir, app };
  }
  return { root, add };
}
test('removes third and older versions across layouts; leaves data, incomplete installs and other channels', async t => {
  const { root, add } = await fixture(t);
  const old = await add(1, false);
  const previous = await add(2);
  const current = await add(3);
  const insiders = await add(1, true, 'Insiders');
  const data = path.join(root, 'extensions');
  const incomplete = path.join(root, 'bin', commit(4));
  await fs.mkdir(data); await fs.mkdir(incomplete);
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => [] }), [old.dir]);
  await assert.rejects(fs.stat(old.dir), { code: 'ENOENT' });
  for (const dir of [previous.dir, current.dir, insiders.dir, data, incomplete]) assert.ok((await fs.stat(dir)).isDirectory());
});
test('protects current and other running versions even when older than retained versions', async t => {
  const { add } = await fixture(t);
  const current = await add(1); const running = await add(2);
  await add(3); await add(4);
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => [`${running.app}/node`] }), []);
});
test('deduplicates commits in legacy and modern layouts', async t => {
  const { add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3); await add(3, false);
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => [] }), [old.dir]);
});
test('process inspection failures abort deletion and release lock', async t => {
  const { root, add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  await assert.rejects(clean({ appRoot: current.app, inspectProcesses: async () => { throw new Error('Denied'); } }), /Denied/);
  assert.ok(await fs.stat(old.dir));
  await assert.rejects(fs.stat(path.join(root, '.server-version-cleaner.lock')), { code: 'ENOENT' });
});
test('rechecks for newly started processes before deleting', async t => {
  const { add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  let calls = 0;
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => ++calls === 1 ? [] : [old.app] }), []);
});
test('skips symlinks and honors existing cleanup lock', async t => {
  const { root, add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  const link = path.join(root, 'cli/servers', `Stable-${commit(5)}`);
  await fs.symlink(old.dir, link);
  await fs.mkdir(path.join(root, '.server-version-cleaner.lock'));
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => [] }), []);
  assert.ok(await fs.stat(old.dir));
  await fs.rmdir(path.join(root, '.server-version-cleaner.lock'));
  await clean({ appRoot: current.app, inspectProcesses: async () => [] });
  assert.ok((await fs.lstat(link)).isSymbolicLink());
});
test('dry run keeps all files; unsupported paths are ignored', async t => {
  const { add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  assert.deepEqual(await clean({ appRoot: current.app, dryRun: true, inspectProcesses: async () => [] }), [old.dir]);
  assert.ok(await fs.stat(old.dir));
  assert.equal(installation('/usr/share/code'), undefined);
  assert.equal(installation(`/custom/bin/${commit(1)}`).root, '/custom');
});
test('uses remote executable when appRoot describes the desktop client', async t => {
  const { add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  assert.deepEqual(await clean({ appRoot: '/Applications/Visual Studio Code.app/Contents/Resources/app', execPath: path.join(current.app, 'node'), inspectProcesses: async () => [] }), [old.dir]);
});
test('removes old shared builds and their links, protects processes using resolved paths', async t => {
  const { root } = await fixture(t);
  const homeDir = path.join(root, 'home');
  const bin = path.join(homeDir, '.vscode-server/bin');
  const shared = path.join(root, 'shared/bin/linux-x64');
  await fs.mkdir(bin, { recursive: true });
  const targets = [];
  for (let n = 1; n <= 4; n++) {
    const target = path.join(shared, commit(n));
    await fs.mkdir(target, { recursive: true });
    await fs.writeFile(path.join(target, 'product.json'), JSON.stringify({ commit: commit(n), date: `2026-01-0${n}T00:00:00Z` }));
    await fs.symlink(target, path.join(bin, commit(n)));
    targets.push(target);
  }
  // Version 2 is running via its resolved path, version 4 is the current host.
  const removed = await clean({ appRoot: '/desktop/app', execPath: path.join(targets[3], 'node'), homeDir, inspectProcesses: async () => [path.join(targets[1], 'node')] });
  assert.deepEqual(removed, [targets[0]]);
  await assert.rejects(fs.stat(targets[0]), { code: 'ENOENT' });
  await assert.rejects(fs.lstat(path.join(bin, commit(1))), { code: 'ENOENT' });
  for (const target of targets.slice(1)) assert.ok((await fs.stat(target)).isDirectory());
  for (let n = 2; n <= 4; n++) assert.ok((await fs.lstat(path.join(bin, commit(n)))).isSymbolicLink());
});
test('falls back to installation timestamps when product has no build date', async t => {
  const { add } = await fixture(t);
  const old = await add(1); await add(2); const current = await add(3);
  await fs.writeFile(path.join(old.app, 'product.json'), JSON.stringify({ commit: commit(1) }));
  await fs.utimes(old.dir, new Date('2025-01-01'), new Date('2025-01-01'));
  const messages = [];
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses: async () => [], log: m => messages.push(m) }), [old.dir]);
  assert.ok(messages.some(m => m.includes('No build date')));
});
async function sharedFixture(t) {
  const { root } = await fixture(t);
  const homeDir = path.join(root, 'home');
  const bin = path.join(homeDir, '.vscode-server/bin');
  const shared = path.join(root, 'shared/bin/linux-x64');
  await fs.mkdir(bin, { recursive: true });
  const targets = [];
  for (let n = 1; n <= 4; n++) {
    const target = path.join(shared, commit(n));
    await fs.mkdir(target, { recursive: true });
    await fs.writeFile(path.join(target, 'product.json'), JSON.stringify({ commit: commit(n), date: `2026-01-0${n}T00:00:00Z`, quality: 'stable' }));
    targets.push(target);
  }
  return { root, bin, shared, targets, options: { execPath: path.join(targets[3], 'node'), homeDir, inspectProcesses: async () => [] } };
}
test('shared cache is cleaned even without per-user symlinks', async t => {
  const { targets, options } = await sharedFixture(t);
  assert.deepEqual(await clean(options), targets.slice(0, 2));
  for (const target of targets.slice(0, 2)) await assert.rejects(fs.stat(target), { code: 'ENOENT' });
  for (const target of targets.slice(2)) assert.ok(await fs.stat(target));
});
test('process using a user symlink protects the shared target; dry run preserves both', async t => {
  const { bin, targets, options } = await sharedFixture(t);
  for (let n = 1; n <= 4; n++) await fs.symlink(targets[n - 1], path.join(bin, commit(n)));
  options.inspectProcesses = async () => [path.join(bin, commit(1), 'node')];
  assert.deepEqual(await clean({ ...options, dryRun: true }), [targets[1]]);
  for (let n = 1; n <= 4; n++) {
    assert.ok(await fs.stat(targets[n - 1]));
    assert.ok((await fs.lstat(path.join(bin, commit(n)))).isSymbolicLink());
  }
  assert.deepEqual(await clean(options), [targets[1]]);
  assert.ok(await fs.stat(targets[0]));
});
test('shared cleanup stays within current architecture and channel and honors shared lock', async t => {
  const { root, shared, targets, options } = await sharedFixture(t);
  const otherArch = path.join(root, 'shared/bin/linux-arm64', commit(1));
  await fs.mkdir(otherArch, { recursive: true });
  await fs.writeFile(path.join(otherArch, 'product.json'), JSON.stringify({ commit: commit(1), date: '2025-01-01' }));
  await fs.writeFile(path.join(targets[0], 'product.json'), JSON.stringify({ commit: commit(1), date: '2025-01-01', quality: 'insider' }));
  const lock = path.join(shared, '.server-version-cleaner.lock');
  await fs.mkdir(lock);
  assert.deepEqual(await clean(options), []);
  await fs.rmdir(lock);
  assert.deepEqual(await clean(options), [targets[1]]);
  assert.ok(await fs.stat(otherArch));
  assert.ok(await fs.stat(targets[0]));
});
test('permission fallback uses noninteractive sudo with separate arguments only for shared cache', async () => {
  const { sharedMutation } = require('../cleaner');
  const denied = async () => { throw Object.assign(new Error('denied'), { code: 'EACCES' }); };
  const calls = [];
  const run = async (...args) => calls.push(args);
  const target = '/shared path/bin/linux-x64/' + commit(1);
  await sharedMutation(denied, 'rm', ['-r', '--', target], true, () => {}, run);
  assert.deepEqual(calls[0].slice(0, 2), ['sudo', ['-n', '--', 'rm', '-r', '--', target]]);
  await assert.rejects(sharedMutation(denied, 'rm', ['-r', '--', target], false, () => {}, run), { code: 'EACCES' });
  assert.equal(calls.length, 1);
  await assert.rejects(sharedMutation(denied, 'rm', ['-r', '--', target], true, () => {}, async () => { throw new Error('password required'); }), /needs write access or passwordless sudo/);
});
function fakeProc({ cmdline, exe, cmdError, exeError, listError }) {
  const fail = code => { throw Object.assign(new Error(code), { code }); };
  return {
    readdir: async () => listError ? fail(listError) : ['1178', 'self'],
    stat: async () => ({ uid: 1000 }),
    readFile: async () => cmdError ? fail(cmdError) : cmdline,
    readlink: async () => exeError ? fail(exeError) : exe
  };
}
test('EACCES reading exe retains cmdline and lets cleanup remove only inactive builds', async t => {
  const { processPaths } = require('../cleaner');
  const { add } = await fixture(t);
  const old = await add(1); const active = await add(2); await add(3); const current = await add(4);
  const messages = [];
  const inspectProcesses = () => processPaths({ uid: 1000, log: m => messages.push(m), procFs: fakeProc({ cmdline: `${active.app}/node\0server-main.js\0`, exeError: 'EACCES' }) });
  assert.deepEqual(await clean({ appRoot: current.app, inspectProcesses }), [old.dir]);
  assert.ok(await fs.stat(active.dir));
  assert.ok(messages.some(m => m.includes('/proc/1178/exe')));
});
test('denied cmdline still permits exe-based process protection', async () => {
  const { processPaths } = require('../cleaner');
  assert.deepEqual(await processPaths({ uid: 1000, procFs: fakeProc({ cmdError: 'EPERM', exe: '/server/node' }) }), ['/server/node']);
});
test('inaccessible or exited process does not abort inspection; systemic errors do', async () => {
  const { processPaths } = require('../cleaner');
  for (const code of ['EACCES', 'EPERM', 'ENOENT', 'ESRCH']) {
    assert.deepEqual(await processPaths({ uid: 1000, procFs: fakeProc({ cmdError: code, exeError: code }) }), []);
  }
  await assert.rejects(processPaths({ uid: 1000, procFs: fakeProc({ listError: 'EACCES' }) }), { code: 'EACCES' });
  await assert.rejects(processPaths({ uid: 1000, procFs: fakeProc({ cmdError: 'EIO' }) }), { code: 'EIO' });
});
