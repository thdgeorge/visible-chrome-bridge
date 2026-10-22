'use strict';
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
// Deliberately fake MCP endpoint: proves upstream stdio/parser wiring only.
const evidence = path.join(__dirname, 'stdio-observed.json');
readline.createInterface({ input: process.stdin }).on('line', line => {
  const request = JSON.parse(line);
  if (!('id' in request)) return;
  let result = {};
  if (request.method === 'initialize') {
    result = { protocolVersion: request.params.protocolVersion,
      capabilities: { tools: {} }, serverInfo: { name: 'offline-test', version: '1.0.0' } };
  } else if (request.method === 'tools/list') result = { tools: [] };
  fs.writeFileSync(evidence, JSON.stringify({
    initialized: true,
    secretPresent: Object.keys(process.env).some(key => /^(CONTROL_PLANE_|OPENAI_|TUNNEL_CLIENT_)/i.test(key)),
    autoConnectFlag: process.argv.includes('--autoConnect'),
  }));
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: request.id, result }) + '\n');
});
