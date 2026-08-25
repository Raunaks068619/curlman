import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

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
const appIcon = path.join(resourcesDirectory, 'Curlman-Icon.png');
const trayIcon = path.join(resourcesDirectory, 'Curlman-TrayTemplate.png');
const retinaTrayIcon = path.join(resourcesDirectory, 'Curlman-TrayTemplate@2x.png');
const mainSource = fs.readFileSync(mainBundle, 'utf8');

if (/require\(["']sql\.js["']\)/.test(mainSource)) {
  throw new Error('The packaged main process still requires an external sql.js module.');
}
if (!fs.existsSync(renderer)) throw new Error(`Packaged renderer is missing: ${renderer}`);
if (!fs.existsSync(wasm)) throw new Error(`Packaged SQLite WASM is missing: ${wasm}`);
if (!fs.existsSync(appIcon)) throw new Error(`Packaged app icon is missing: ${appIcon}`);
if (!fs.existsSync(trayIcon)) throw new Error(`Packaged tray icon is missing: ${trayIcon}`);
if (!fs.existsSync(retinaTrayIcon)) throw new Error(`Packaged Retina tray icon is missing: ${retinaTrayIcon}`);
if (process.platform === 'darwin') {
  const appBundle = path.resolve(resourcesDirectory, '..', '..');
  execFileSync('codesign', ['--force', '--deep', '--sign', '-', appBundle], { stdio: 'inherit' });
  execFileSync('codesign', ['--verify', '--deep', '--strict', appBundle], { stdio: 'inherit' });
}

process.stdout.write('Packaged Electron app contains its runtime, renderer, SQLite, and tray icons.\n');

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
