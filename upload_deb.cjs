const fs = require('fs');
const http = require('http');
const path = require('path');

const debPath = path.join(__dirname, 'debs', 'com.subdiox.storeswitcher2_2.4.0_iphoneos-arm64.deb');
const b64 = fs.readFileSync(debPath).toString('base64');

function callIosMcp(name, args) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      jsonrpc: '2.0',
      id: Date.now(),
      method: 'tools/call',
      params: { name, arguments: args }
    });
    const req = http.request({
      host: '127.0.0.1',
      port: 8090,
      path: '/mcp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      },
      timeout: 30000
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { resolve(data); }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

(async () => {
  console.log('0. Đánh thức và mở màn hình iPhone...');
  await callIosMcp('wake_and_home', {});

  console.log('1. Xoá file tạm cũ...');
  await callIosMcp('run_command', { command: 'rm -f /var/mobile/storeswitcher.b64 /var/mobile/storeswitcher.deb' });

  const CHUNK_SIZE = 24000;
  console.log('2. Đang truyền ' + Math.ceil(b64.length / CHUNK_SIZE) + ' chunks base64...');
  for (let i = 0; i < b64.length; i += CHUNK_SIZE) {
    const chunk = b64.slice(i, i + CHUNK_SIZE);
    const cmd = "printf '%s' '" + chunk + "' >> /var/mobile/storeswitcher.b64";
    await callIosMcp('run_command', { command: cmd });
    process.stdout.write('.');
  }
  console.log('\n3. Đã truyền xong. Kiểm tra file b64:');
  const resCheck = await callIosMcp('run_command', { command: 'ls -la /var/mobile/storeswitcher.b64' });
  console.log(JSON.stringify(resCheck));

  console.log('4. Decode base64 -> deb:');
  const resDecode = await callIosMcp('run_command', { command: '/var/jb/usr/bin/base64 -d /var/mobile/storeswitcher.b64 > /var/mobile/storeswitcher.deb && ls -la /var/mobile/storeswitcher.deb' });
  console.log(JSON.stringify(resDecode));

  console.log('5. File deb đã sẵn sàng tại: /var/mobile/storeswitcher.deb');
  const resLs = await callIosMcp('run_command', { command: 'ls -la /var/mobile/storeswitcher.deb' });
  console.log(JSON.stringify(resLs));
  await callIosMcp('run_command', { command: 'rm -f /var/mobile/storeswitcher.b64' });
})();
