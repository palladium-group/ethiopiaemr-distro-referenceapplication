const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { repairCss, repairDirectory } = require('./repair-css-module-selectors.cjs');

const className = 'F+JnE5oCZsS0FV+Mxzn6Mg==';
const escaped = className.replace(/[+=]/g, char => '\\'.repeat(3) + char);
const correct = className.replace(/[+=]/g, char => '\\' + char);
const css = `.${escaped}{border-right:1px solid #c6c6c6}.${escaped} .cds--side-nav__link{color:#525252}`;
const javascript = `const styles={leftNav:"${className}"};`;

test('repairs the deployed sidebar hash without changing its declarations', () => {
  const result = repairCss(css, javascript);
  assert.equal(result.count, 2);
  assert.equal(result.css, css.split(escaped).join(correct));
  assert.deepEqual(repairCss(result.css, javascript), { css: result.css, count: 0 });
});

test('preserves unrelated escapes and hashes absent from JavaScript', () => {
  assert.deepEqual(repairCss(css, ''), { css, count: 0 });
  const other = String.raw`.ordinary\+class{content:"\\"}.cds--side-nav__link{color:blue}`;
  assert.deepEqual(repairCss(other, javascript), { css: other, count: 0 });
});

test('updates compressed copies and reads lazy JavaScript chunks', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'o3-css-repair-'));
  try {
    const file = path.join(directory, 'shared.css');
    fs.writeFileSync(file, css);
    fs.writeFileSync(file + '.gz', zlib.gzipSync(css));
    fs.writeFileSync(file + '.br', zlib.brotliCompressSync(css));
    fs.writeFileSync(path.join(directory, 'lazy-chunk.js'), javascript);
    assert.equal(repairDirectory(directory), 2);
    const repaired = fs.readFileSync(file, 'utf8');
    assert.equal(zlib.gunzipSync(fs.readFileSync(file + '.gz')).toString(), repaired);
    assert.equal(zlib.brotliDecompressSync(fs.readFileSync(file + '.br')).toString(), repaired);
    assert.equal(repairDirectory(directory), 0);
  } finally {
    fs.rmSync(directory, { recursive: true });
  }
});
