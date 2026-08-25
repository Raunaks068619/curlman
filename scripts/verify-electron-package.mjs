import fs from 'node:fs';
import path from 'node:path';

const outputDirectory = path.resolve('out');
const mainBundles = findFiles(outputDirectory, (filePath) => filePath.endsWith(`${path.sep}.vite${path.sep}build${path.sep}main.js`));

if (mainBundles.length !== 1) {
  throw new Error(`Expected one packaged Electron main bundle, found ${mainBundles.length}.`);
}

const mainBundle = mainBundles[0];
const appDirectory = path.resolve(path.dirname(mainBundle), '..', '..');
const resourcesDirectory = path.dirname(appDirectory);
const renderer = path.join(appDirectory, '.vite', 'renderer', 'main_window', 'index.html');
const wasm = path.join(resourcesDirectory, 'sql-wasm.wasm');
const mainSource = fs.readFileSync(mainBundle, 'utf8');

if (/require\(["']sql\.js["']\)/.test(mainSource)) {
  throw new Error('The packaged main process still requires an external sql.js module.');
}
if (!fs.existsSync(renderer)) throw new Error(`Packaged renderer is missing: ${renderer}`);
if (!fs.existsSync(wasm)) throw new Error(`Packaged SQLite WASM is missing: ${wasm}`);

process.stdout.write('Packaged Electron app contains its main process, renderer, and SQLite runtime.\n');

function findFiles(directory, matches) {
  if (!fs.existsSync(directory)) return [];
  const results = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) results.push(...findFiles(entryPath, matches));
    else if (matches(entryPath)) results.push(entryPath);
  }
  return results;
}
