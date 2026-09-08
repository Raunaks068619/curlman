import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const sourceDirectory = path.resolve('out', 'make');
const destinationDirectory = path.resolve('dist-electron');
const platformLabel = platformName(process.platform);
const supportedExtensions = extensionsFor(process.platform);
const version = JSON.parse(fs.readFileSync(path.resolve('package.json'), 'utf8')).version;

if (!fs.existsSync(sourceDirectory)) {
  throw new Error(`Electron Forge output is missing: ${sourceDirectory}`);
}

fs.rmSync(destinationDirectory, { recursive: true, force: true });
fs.mkdirSync(destinationDirectory, { recursive: true });

const candidates = findFiles(sourceDirectory).filter((filePath) => {
  const basename = path.basename(filePath);
  return supportedExtensions.some((extension) => extension === basename || basename.endsWith(extension));
});

if (candidates.length === 0) {
  throw new Error(`No ${platformLabel} release artifacts were found under ${sourceDirectory}.`);
}

const staged = candidates.map((sourcePath) => {
  const sourceName = path.basename(sourcePath);
  const destinationName = sourceName === 'RELEASES'
    ? `Curlman-${version}-windows-x64-RELEASES`
    : sourceName.replaceAll(' ', '-');
  const destinationPath = path.join(destinationDirectory, destinationName);
  fs.copyFileSync(sourcePath, destinationPath);
  return destinationPath;
});

const checksumLines = staged
  .sort((left, right) => left.localeCompare(right))
  .map((filePath) => `${sha256(filePath)}  ${path.basename(filePath)}`);
const checksumPath = path.join(destinationDirectory, `SHA256SUMS-${platformLabel}.txt`);
fs.writeFileSync(checksumPath, `${checksumLines.join('\n')}\n`);

process.stdout.write(`Staged ${staged.length} ${platformLabel} Electron artifacts in ${destinationDirectory}.\n`);

function platformName(platform) {
  if (platform === 'win32') return 'windows';
  if (platform === 'linux') return 'linux';
  if (platform === 'darwin') return 'macos';
  throw new Error(`Unsupported Electron release platform: ${platform}`);
}

function extensionsFor(platform) {
  if (platform === 'win32') return ['.exe', '.nupkg', '.zip', 'RELEASES'];
  if (platform === 'linux') return ['.deb', '.rpm', '.zip'];
  if (platform === 'darwin') return ['.zip'];
  return [];
}

function findFiles(directory) {
  const results = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) results.push(...findFiles(entryPath));
    else results.push(entryPath);
  }
  return results;
}

function sha256(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}
