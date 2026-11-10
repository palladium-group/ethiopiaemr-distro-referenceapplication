// Work around over-escaped base64 CSS-module hashes in the pinned O3 shell.
// Only repair hashes also present in the emitted JavaScript; leave ordinary CSS
// escapes alone. Run after `openmrs build`, before packaging the SPA.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { createHash } = require('node:crypto');

const digest = text => createHash('sha256').update(text).digest('hex').slice(0, 16);

function writeAsset(file, text) {
  fs.writeFileSync(file, text);
  if (fs.existsSync(file + '.gz')) fs.writeFileSync(file + '.gz', zlib.gzipSync(text));
  if (fs.existsSync(file + '.br')) fs.writeFileSync(file + '.br', zlib.brotliCompressSync(text));
}

function versionAssets(directory, replacements) {
  // Rspack stores CSS chunk hashes in the JS runtime. Updating only the CSS
  // contents leaves browsers using the old URL for up to six months. Propagate
  // new hashes through JS chunks and finally index.html / manifest references.
  const assets = fs.readdirSync(directory)
    .filter(name => /\.(js|css|html|json)$/.test(name))
    .map(name => ({ name, originalName: name, text: fs.readFileSync(path.join(directory, name), 'utf8') }));
  for (let pass = 0; replacements.size; pass++) {
    if (pass === 10) throw new Error('Cyclic asset references while versioning repaired CSS');
    const next = new Map();
    for (const asset of assets) {
      let text = asset.text;
      for (const [before, after] of replacements) text = text.split(before).join(after);
      if (text === asset.text) continue;
      const match = asset.name.match(/(?:^|\.)([a-f0-9]{16})\.(?:js|css)$/);
      if (match) {
        const hash = digest(text);
        next.set(match[1], hash);
        asset.name = asset.name.replace(match[1], hash);
      }
      asset.text = text;
    }
    replacements = next;
  }
  for (const asset of assets) {
    const file = path.join(directory, asset.name);
    if (asset.name !== asset.originalName) {
      for (const suffix of ['.gz', '.br']) {
        const original = path.join(directory, asset.originalName) + suffix;
        if (fs.existsSync(original)) fs.copyFileSync(original, file + suffix);
      }
    }
    writeAsset(file, asset.text);
  }
}

function repairCss(css, javascript) {
  let count = 0;
  const result = css.replace(/\.((?:[\w-]|\\{3}[+=/]|\\[+=/])+)/g, (selector, hash) => {
    if (!hash.includes('\\\\\\')) return selector;
    const decoded = hash.replace(/\\{3}([+=/])/g, '$1').replace(/\\([+=/])/g, '$1');
    if (!/^[A-Za-z0-9+/_-]{22}==$/.test(decoded)) return selector;
    // Unused CSS-module exports may have been removed from JavaScript.
    if (!javascript.includes(decoded)) return selector;
    count++;
    return '.' + hash.replace(/\\{3}([+=/])/g, '\\$1');
  });
  return { css: result, count };
}

function repairDirectory(directory) {
  // The app shell and its shared component chunks are emitted at the SPA root.
  const files = fs.readdirSync(directory);
  const javascript = files.filter(name => name.endsWith('.js'))
    .map(name => fs.readFileSync(path.join(directory, name), 'utf8')).join('\n');
  let count = 0;
  const replacements = new Map();
  for (const name of files.filter(name => name.endsWith('.css'))) {
    const file = path.join(directory, name);
    const repaired = repairCss(fs.readFileSync(file, 'utf8'), javascript);
    if (!repaired.count) continue;
    writeAsset(file, repaired.css);
    // Some CLI builds precompress assets. Keep every served representation equal.
    const match = name.match(/(?:^|\.)([a-f0-9]{16})\.css$/);
    if (match) {
      const hash = digest(repaired.css);
      const versioned = path.join(directory, name.replace(match[1], hash));
      // Copy compressed variants before writeAsset so it regenerates them too.
      for (const suffix of ['.gz', '.br']) {
        if (fs.existsSync(file + suffix)) fs.copyFileSync(file + suffix, versioned + suffix);
      }
      writeAsset(versioned, repaired.css);
      replacements.set(match[1], hash);
    }
    count += repaired.count;
  }
  if (replacements.size) versionAssets(directory, replacements);
  console.log(`Verified and repaired ${count} over-escaped CSS-module selectors.`);
  return count;
}

if (require.main === module) repairDirectory(process.argv[2] || './spa');
module.exports = { repairCss, repairDirectory };
