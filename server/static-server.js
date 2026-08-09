import { createAppServer } from './index.js';

const HOST = '127.0.0.1';
const PORT = Number(process.env.PORT || 4173);
const server = createAppServer();

server.once('error', (error) => {
  if (error?.code === 'EADDRINUSE') {
    console.error(`EADDRINUSE：本地端口 ${PORT} 已被占用，请关闭占用它的程序或设置其他 PORT。`);
  } else {
    console.error('本地服务启动失败：', error);
  }
  process.exitCode = 1;
});

server.listen(PORT, HOST, () => {
  console.log(`http://${HOST}:${PORT}`);
});
