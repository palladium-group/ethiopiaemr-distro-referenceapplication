#!/usr/bin/env node
/*
 * Injects the locally-built @palladium-ethiopia/esm-ethiopia-reports-app into an
 * already-assembled SPA tree. The app is not published to npm, so it cannot go
 * through `openmrs assemble`; instead its prebuilt dist is copied into the SPA
 * and registered here by editing importmap.json and routes.registry.json.
 *
 * It also removes the community @openmrs/esm-reports-app's "/reports" page so it
 * does not collide with our app's route.
 *
 * Usage: node inject-ethiopia-reports.js <spaDir>
 */
const fs = require('fs');
const path = require('path');

const spaDir = process.argv[2] || '/app/spa';
const APP = '@palladium-ethiopia/esm-ethiopia-reports-app';
const FOLDER = 'ethiopia-esm-reports-app-1.0.1';
const BUNDLE = `./${FOLDER}/ethiopia-esm-reports-app.js`;

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}
function writeJson(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj));
}

// --- importmap.json ---
const importmapPath = path.join(spaDir, 'importmap.json');
const im = readJson(importmapPath);
im.imports = im.imports || {};
im.imports[APP] = BUNDLE;
writeJson(importmapPath, im);
console.log(`inject-ethiopia-reports: importmap += ${APP} -> ${BUNDLE}`);

// --- routes.registry.json ---
const registryPath = path.join(spaDir, 'routes.registry.json');
const rr = readJson(registryPath);
const ourRoutes = readJson(path.join(spaDir, FOLDER, 'routes.json'));
rr[APP] = ourRoutes;
console.log(`inject-ethiopia-reports: registry += ${APP}`);

const others = rr['@openmrs/esm-reports-app'];
if (others && Array.isArray(others.pages)) {
  const before = others.pages.length;
  others.pages = others.pages.filter((p) => p.route !== 'reports');
  console.log(`inject-ethiopia-reports: esm-reports-app /reports removed (${before} -> ${others.pages.length} pages)`);
} else {
  console.log('inject-ethiopia-reports: esm-reports-app not present in registry (nothing to neutralize)');
}
writeJson(registryPath, rr);

console.log('inject-ethiopia-reports: done');
