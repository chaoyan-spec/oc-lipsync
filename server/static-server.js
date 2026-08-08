import { createAppServer } from './index.js';

const HOST = '127.0.0.1';
const PORT = Number(process.env.PORT || 4173);
const server = createAppServer();

server.listen(PORT, HOST, () => {
  console.log(`http://${HOST}:${PORT}`);
});
