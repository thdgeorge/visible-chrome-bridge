'use strict';
// npm lockfiles contain the valid empty root key, which ConvertFrom-Json in
// Windows PowerShell cannot represent. Parse with the existing Node runtime.
const fs = require('node:fs');
try {
  const [lockPath, version, tarball, integrity] = process.argv.slice(2);
  const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8').replace(/^\uFEFF/, ''));
  if (lock.lockfileVersion < 2 || !lock.packages) throw new Error();
  const main = lock.packages['node_modules/chrome-devtools-mcp'];
  if (!main || main.version !== version || main.resolved !== tarball ||
      main.integrity !== integrity) throw new Error();
  for (const [name, pkg] of Object.entries(lock.packages)) {
    if (name === '') continue;
    if (!name.startsWith('node_modules/') || /(^|\/)\.\.(\/|$)|[\\:]/.test(name) ||
        pkg.link || typeof pkg.resolved !== 'string' ||
        !/^sha(?:256|384|512)-[A-Za-z0-9+/]+={0,2}$/.test(pkg.integrity)) throw new Error();
    const url = new URL(pkg.resolved);
    if (url.protocol !== 'https:' || url.hostname !== 'registry.npmjs.org' ||
        url.port || url.username || url.password || url.search || url.hash ||
        !/^\/(?:@[a-z0-9._-]+\/)?[a-z0-9._-]+\/-\/[a-zA-Z0-9._-]+\.tgz$/.test(url.pathname)) throw new Error();
  }
} catch {
  process.exitCode = 1;
}
