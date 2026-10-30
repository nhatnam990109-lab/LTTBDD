const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const WEB_DIR = path.join(__dirname, 'clinic-app', 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.js': 'text/javascript; charset=UTF-8',
  '.mjs': 'text/javascript; charset=UTF-8',
  '.json': 'application/json; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

if (!fs.existsSync(WEB_DIR)) {
  console.error(`\x1b[31m[LỖI] Không tìm thấy thư mục build web tại: ${WEB_DIR}\x1b[0m`);
  console.error('Vui lòng build web trước bằng lệnh: cd clinic-app && flutter build web --release');
  process.exit(1);
}

const server = http.createServer((req, res) => {
  // Loại bỏ query string (ví dụ /booking?package=1 -> /booking)
  const cleanUrl = decodeURI(req.url.split('?')[0]);
  let safePath = path.normalize(cleanUrl).replace(/^(\.\.[\/\\])+/, '');
  let filePath = path.join(WEB_DIR, safePath);

  // Nếu người dùng yêu cầu 1 file cụ thể nhưng không tồn tại, hoặc yêu cầu đường dẫn route (SPA)
  fs.stat(filePath, (err, stats) => {
    if (err || stats.isDirectory()) {
      // Nếu là thư mục, thử tìm index.html bên trong
      if (!err && stats.isDirectory()) {
        const subIndex = path.join(filePath, 'index.html');
        if (fs.existsSync(subIndex)) {
          filePath = subIndex;
        } else {
          filePath = path.join(WEB_DIR, 'index.html');
        }
      } else {
        // SPA Fallback: Trả về index.html để GoRouter trên client tự điều hướng
        filePath = path.join(WEB_DIR, 'index.html');
      }
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (readErr, content) => {
      if (readErr) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=UTF-8' });
        res.end('Lỗi máy chủ khi đọc file: ' + readErr.message);
        return;
      }
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=3600',
      });
      res.end(content);
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('==================================================');
  console.log(`ClinicCare Web đang chạy tại: http://localhost:${PORT}`);
  console.log('==================================================');
  console.log('- Đã kích hoạt SPA routing (F5 các trang không bị 404)');
  console.log('- Không có banner DEBUG, tải mượt như web thật');
  console.log('Nhấn Ctrl + C để dừng máy chủ web.');
});
