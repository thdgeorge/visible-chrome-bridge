'use strict';
// Transport is owned by the official server. This shim only removes credentials
// from its environment; it does not read or modify any MCP messages.
const { spawn } = require('node:child_process');
const path = require('node:path');
const allowed = new Set([
  'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATH', 'PATHEXT', 'TEMP', 'TMP',
  'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'PROGRAMFILES', 'PROGRAMFILES(X86)',
  'PROGRAMDATA', 'HOMEDRIVE', 'HOMEPATH', 'NUMBER_OF_PROCESSORS',
  'PROCESSOR_ARCHITECTURE', 'OS',
]);
const env = {};
for (const [key, value] of Object.entries(process.env)) {
  if (allowed.has(key.toUpperCase())) env[key] = value;
  else delete process.env[key];
}
env.CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = '1';
env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = '1';
const entry = process.argv[2];
if (!entry || !path.isAbsolute(entry)) process.exit(2);
const child = spawn(process.execPath, [entry, '--autoConnect',
  '--no-usage-statistics', '--no-performance-crux'], {
  env, shell: false, stdio: 'inherit', windowsHide: true,
});
child.on('error', () => process.exit(1));
child.on('exit', (code) => process.exit(code === null ? 1 : code));
