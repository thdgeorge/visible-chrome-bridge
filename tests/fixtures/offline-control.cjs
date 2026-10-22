'use strict';
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const directory = process.argv[2];
let sent = false;
const server = http.createServer((request, response) => {
  // No headers, identifiers, body, or credentials are captured.
  fs.writeFileSync(path.join(directory, 'poll-observed'), 'local request observed');
  if (request.method === 'POST' && request.url.endsWith('/response')) {
    let body = '';
    request.on('data', chunk => { body += chunk; });
    request.on('end', () => {
      const result = JSON.parse(body);
      const rpc = result.resp_json;
      const hasResponse = result.request_id === 'synthetic-local-request' &&
        result.channel === 'main' && result.resp_code === 200 &&
        rpc && rpc.jsonrpc === '2.0' && rpc.id === 1 && rpc.result &&
        rpc.result.serverInfo && rpc.result.serverInfo.name === 'offline-test';
      fs.writeFileSync(path.join(directory, 'response-observed'),
        JSON.stringify({ hasResponse: !!hasResponse }));
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end('{}');
    });
    return;
  }
  setTimeout(() => {
    response.writeHead(200, { 'content-type': 'application/json' });
    const commands = [];
    if (!sent && request.url.includes('/poll')) {
      sent = true;
      commands.push({ request_id: 'synthetic-local-request', shard_token: 'synthetic-local-shard',
        command_type: 'jsonrpc', channel: 'main', created_at: new Date().toISOString(),
        response_timeout: '15s', headers: {},
        jsonrpc: { jsonrpc: '2.0', id: 1, method: 'initialize',
          params: { protocolVersion: '2024-11-05', capabilities: {},
            clientInfo: { name: 'offline-test', version: '1.0.0' } } },
      });
    }
    response.end(JSON.stringify({ commands }));
  }, 250);
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(path.join(directory, 'control.url'), `http://127.0.0.1:${server.address().port}`);
});
