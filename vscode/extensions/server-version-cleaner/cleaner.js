'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const execute = promisify(execFile);

const hash = '[a-f0-9]{40}';
function installation(appRoot) {
  const modern = appRoot.match(new RegExp(`^(.*)/cli/servers/(Stable|Insiders)-(${hash})/server(?:/|$)`));
  if (modern) return { root: modern[1], channel: modern[2] };
  const platform = appRoot.match(new RegExp(`^(.*)/bin/(linux-[a-z0-9_-]+)/(${hash})(?:/|$)`));
  if (platform) return { root: platform[1], channel: appRoot.includes('insiders') ? 'Insiders' : 'Stable', platform: platform[2], commit: platform[3] };
  const legacy = appRoot.match(new RegExp(`^(.*)/bin/(${hash})(?:/|$)`));
  if (legacy) return { root: legacy[1], channel: appRoot.includes('.vscode-server-insiders/') ? 'Insiders' : 'Stable' };
  return undefined;
}
async function directories(dir) {
  try { return await fs.readdir(dir, { withFileTypes: true }); }
  catch (error) { if (error.code === 'ENOENT') return []; throw error; }
}
async function locate(appRoot, execPath, homeDir, log) {
  // The API's appRoot can describe the client. The executable belongs to this host.
  const runtime = installation(execPath);
  if (runtime?.platform) {
    for (const name of ['.vscode-server', '.vscode-server-insiders']) {
      const root = path.join(homeDir, name);
      const link = path.join(root, 'bin', runtime.commit);
      try {
        const target = await fs.realpath(link);
        if (path.dirname(execPath) === target) {
          log(`Shared server cache: ${runtime.root}; cleaning old builds and container links.`);
          return { ...runtime, userRoot: root, channel: name.endsWith('insiders') ? 'Insiders' : 'Stable' };
        }
      } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
    log(`Shared server cache: ${runtime.root}; no matching user links, cleaning builds directly.`);
    return runtime;
  }
  return runtime || installation(appRoot);
}
async function discover(root, channel, log = () => {}, platform) {
  const found = [];
  const layouts = platform ? [[`bin/${platform}`, new RegExp(`^(${hash})$`), '']] : [
    ['bin', new RegExp(`^(${hash})$`), ''],
    ['cli/servers', new RegExp(`^${channel}-(${hash})$`), 'server']
  ];
  for (const [relative, pattern, suffix] of layouts) {
    const parent = path.join(root, relative);
    // Never traverse a symlinked installation container.
    try { if (!(await fs.lstat(parent)).isDirectory() || await fs.realpath(parent) !== parent) continue; }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    for (const entry of await directories(parent)) {
      const match = entry.name.match(pattern);
      if (!match || (!entry.isDirectory() && !entry.isSymbolicLink())) continue;
      const dir = path.join(parent, entry.name);
      try {
        const product = JSON.parse(await fs.readFile(path.join(dir, suffix, 'product.json'), 'utf8'));
        if (platform && product.quality && product.quality !== (channel === 'Insiders' ? 'insider' : 'stable')) {
          log(`Skipped ${dir}: different release channel.`);
          continue;
        }
        if (product.commit !== match[1]) { log(`Skipped ${dir}: product commit mismatch.`); continue; }
        const stat = await fs.lstat(dir);
        let date = Date.parse(product.date);
        if (!Number.isFinite(date)) {
          date = stat.mtimeMs;
          log(`No build date for ${dir}; using installation modification time.`);
        }
        const target = await fs.realpath(dir);
        found.push({ dir, target, isLink: stat.isSymbolicLink(), commit: match[1], date, ino: stat.ino, dev: stat.dev });
      } catch (error) {
        log(`Skipped ${dir}: ${error.message}`);
        if (error.code !== 'ENOENT' && !(error instanceof SyntaxError)) throw error;
      }
    }
  }
  return found;
}
async function processPaths({ procFs = fs, uid = process.getuid(), log = () => {} } = {}) {
  const result = [];
  const read = async (file, operation) => {
    try { return await operation(); }
    catch (error) {
      if (['ENOENT', 'ESRCH'].includes(error.code)) return undefined;
      if (['EACCES', 'EPERM'].includes(error.code)) {
        log(`Process inspection: ${file} is inaccessible (${error.code}); continuing with available process information.`);
        return undefined;
      }
      throw error;
    }
  };
  // Failure to list /proc still aborts cleanup. Individual protected processes do not.
  for (const entry of await procFs.readdir('/proc')) {
    if (!/^\d+$/.test(entry)) continue;
    const base = `/proc/${entry}`;
    const stat = await read(base, () => procFs.stat(base));
    if (!stat || stat.uid !== uid) continue;
    // Read independently: either source may remain available when the other is denied.
    const cmdline = await read(`${base}/cmdline`, () => procFs.readFile(`${base}/cmdline`, 'utf8'));
    const exe = await read(`${base}/exe`, () => procFs.readlink(`${base}/exe`));
    if (cmdline) result.push(cmdline);
    if (exe) result.push(exe);
  }
  return result;
}
function isActive(entry, active) {
  return active.some(p => [entry.dir, entry.target, ...(entry.aliases || []).map(a => a.dir)].filter(Boolean).some(dir => p.includes(dir)));
}
async function attachAliases(entries, userRoot) {
  if (!userRoot) return;
  for (const entry of entries) {
    const dir = path.join(userRoot, 'bin', entry.commit);
    try {
      const stat = await fs.lstat(dir);
      if (stat.isSymbolicLink() && await fs.realpath(dir) === entry.target) {
        entry.aliases = [{ dir, ino: stat.ino, dev: stat.dev, link: await fs.readlink(dir) }];
      }
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
}
function candidates(entries, keep, active) {
  const newest = [...new Map(entries.slice().sort((a, b) => b.date - a.date).map(e => [e.commit, e])).keys()].slice(0, keep);
  return entries.filter(e => !newest.includes(e.commit) && !isActive(e, active));
}
// Only shared-cache mutations use this fallback; no shell or password prompt.
async function sharedMutation(operation, command, args, allowSudo, log, run = execute) {
  try { return await operation(); }
  catch (error) {
    if (!allowSudo || !['EACCES', 'EPERM'].includes(error.code)) throw error;
    log(`Permission denied; trying sudo -n ${command} for the shared cache.`);
    try { await run('sudo', ['-n', '--', command, ...args], { timeout: 120000 }); }
    catch (sudoError) { throw new Error(`Shared cache cleanup needs write access or passwordless sudo: ${sudoError.message}`); }
  }
}
async function clean({ appRoot = '', execPath = process.execPath, homeDir = os.homedir(), keep = 2, dryRun = false, log = () => {}, inspectProcesses }) {
  if (!Number.isInteger(keep) || keep < 2) throw new Error('keep must be an integer >= 2');
  const inspectionMessages = new Set();
  const scanProcesses = inspectProcesses || (() => processPaths({ log: message => {
    if (!inspectionMessages.has(message)) { inspectionMessages.add(message); log(message); }
  } }));
  log(`Runtime: ${execPath}; appRoot: ${appRoot}`);
  const location = await locate(appRoot, execPath, homeDir, log);
  if (!location) { log('Unknown server installation; skipped.'); return []; }
  const { root, channel, platform, userRoot } = location;
  log(`Scanning ${root} (${channel}); retain ${keep} newest builds plus active builds.`);
  if (await fs.realpath(root) !== root) throw new Error('Symlinked server root; cleanup skipped.');
  const lock = path.join(platform ? path.join(root, 'bin', platform) : root, '.server-version-cleaner.lock');
  const mutate = (operation, command, args) => sharedMutation(operation, command, args, Boolean(platform), log);
  try { await mutate(() => fs.mkdir(lock), 'mkdir', ['--', lock]); }
  catch (error) { if (error.code === 'EEXIST') { log('Cleanup lock exists; skipped.'); return []; } throw error; }
  try {
    const entries = await discover(root, channel, log, platform);
    await attachAliases(entries, userRoot);
    log(`Recognized installations: ${entries.length}`);
    const active = [appRoot, execPath, ...await scanProcesses()];
    const selected = candidates(entries, keep, active);
    for (const entry of entries) {
      if (!selected.includes(entry)) log(`Keeping newest/active: ${entry.dir}`);
    }
    const removed = [];
    for (const entry of selected) {
      // Recheck processes and directory identity immediately before removal.
      if (isActive(entry, await scanProcesses())) {
        log(`Keeping newly active: ${entry.dir}`);
        continue;
      }
      const stat = await fs.lstat(entry.dir);
      if (stat.isSymbolicLink() !== entry.isLink || (!stat.isDirectory() && !stat.isSymbolicLink()) || stat.ino !== entry.ino || stat.dev !== entry.dev) continue;
      log(`${dryRun ? 'Would remove' : 'Removing'}: ${entry.dir}`);
      if (!dryRun) {
        if (entry.isLink) await fs.unlink(entry.dir);
        else await mutate(() => fs.rm(entry.dir, { recursive: true }), 'rm', ['-r', '--', entry.dir]);
      }
      removed.push(entry.dir);
      for (const alias of entry.aliases || []) {
        try {
          const current = await fs.lstat(alias.dir);
          if (!current.isSymbolicLink() || current.ino !== alias.ino || current.dev !== alias.dev || await fs.readlink(alias.dir) !== alias.link) continue;
          log(`${dryRun ? 'Would unlink' : 'Unlinking'}: ${alias.dir}`);
          if (!dryRun) await fs.unlink(alias.dir);
        } catch (error) {
          if (error.code !== 'ENOENT') log(`Could not unlink ${alias.dir}: ${error.message}`);
        }
      }
    }
    log(`${dryRun ? 'Candidates' : 'Removed'}: ${removed.length}`);
    return removed;
  } finally { await mutate(() => fs.rmdir(lock), 'rmdir', ['--', lock]); }
}
module.exports = { installation, locate, discover, candidates, clean, sharedMutation, processPaths };
