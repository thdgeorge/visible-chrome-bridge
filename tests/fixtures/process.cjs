'use strict';
const fs = require('node:fs');
const { spawn } = require('node:child_process');
const [mode, output, ...args] = process.argv.slice(2);
if (mode === 'argv') {
  fs.writeFileSync(output, JSON.stringify(args));
} else if (mode === 'tree') {
  const child = spawn(process.execPath, [__filename, 'idle'], { stdio: 'ignore' });
  fs.writeFileSync(output, JSON.stringify({ parent: process.pid, child: child.pid }));
  setInterval(() => {}, 1000);
} else if (mode === 'environment') {
  fs.writeFileSync(output, JSON.stringify({
    secretPresent: Object.keys(process.env).some(k => /^(OPENAI_|CONTROL_PLANE_|NODE_OPTIONS|TUNNEL_CLIENT_)/i.test(k)),
    privacy: process.env.CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS === '1',
    updateCheckDisabled: process.env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS === '1',
    args,
  }));
} else {
  setInterval(() => {}, 1000);
}
