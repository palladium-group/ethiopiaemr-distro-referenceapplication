// Work around over-escaped base64 CSS-module hashes in the pinned O3 shell.
// Only repair hashes also present in the emitted JavaScript; leave ordinary CSS
// escapes alone. Run after `openmrs build`, before packaging the SPA.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

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
  for (const name of files.filter(name => name.endsWith('.css'))) {
    const file = path.join(directory, name);
    const repaired = repairCss(fs.readFileSync(file, 'utf8'), javascript);
    if (!repaired.count) continue;
    fs.writeFileSync(file, repaired.css);
    // Some CLI builds precompress assets. Keep every served representation equal.
    if (fs.existsSync(file + '.gz')) fs.writeFileSync(file + '.gz', zlib.gzipSync(repaired.css));
    if (fs.existsSync(file + '.br')) fs.writeFileSync(file + '.br', zlib.brotliCompressSync(repaired.css));
    count += repaired.count;
  }
  console.log(`Verified and repaired ${count} over-escaped CSS-module selectors.`);
  return count;
}

if (require.main === module) repairDirectory(process.argv[2] || './spa');
module.exports = { repairCss, repairDirectory };
