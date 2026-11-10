const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { createHash } = require('node:crypto');
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

test('changes CSS and runtime URLs so cached browsers fetch the repair', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'o3-css-cache-'));
  try {
    const cssHash = '8a460280e2aa67f7';
    const runtimeHash = 'f55c0bf81031bebd';
    const runtime = `${javascript} const cssChunk="${cssHash}";`;
    fs.writeFileSync(path.join(directory, cssHash + '.css'), css);
    fs.writeFileSync(path.join(directory, cssHash + '.css.gz'), zlib.gzipSync(css));
    fs.writeFileSync(path.join(directory, `openmrs.${runtimeHash}.js`), runtime);
    fs.writeFileSync(path.join(directory, `openmrs.${runtimeHash}.js.br`), zlib.brotliCompressSync(runtime));
    fs.writeFileSync(path.join(directory, 'index.html'), `<script src="openmrs.${runtimeHash}.js"></script>`);
    assert.equal(repairDirectory(directory), 2);
    const fixedCss = css.split(escaped).join(correct);
    const newCssHash = createHash('sha256').update(fixedCss).digest('hex').slice(0, 16);
    const fixedRuntime = runtime.replace(cssHash, newCssHash);
    const newRuntimeHash = createHash('sha256').update(fixedRuntime).digest('hex').slice(0, 16);
    assert.equal(fs.readFileSync(path.join(directory, newCssHash + '.css'), 'utf8'), fixedCss);
    assert.equal(zlib.gunzipSync(fs.readFileSync(path.join(directory, newCssHash + '.css.gz'))).toString(), fixedCss);
    assert.equal(fs.readFileSync(path.join(directory, `openmrs.${newRuntimeHash}.js`), 'utf8'), fixedRuntime);
    assert.equal(zlib.brotliDecompressSync(fs.readFileSync(path.join(directory, `openmrs.${newRuntimeHash}.js.br`))).toString(), fixedRuntime);
    assert.equal(fs.readFileSync(path.join(directory, 'index.html'), 'utf8'), `<script src="openmrs.${newRuntimeHash}.js"></script>`);
    assert.equal(repairDirectory(directory), 0);
  } finally {
    fs.rmSync(directory, { recursive: true });
  }
});
