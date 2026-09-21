// Mini server statico per anteprima locale di Komunigo (solo sviluppo)
const http=require('http'), fs=require('fs'), path=require('path');
const root=__dirname;
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml'};
http.createServer((req,res)=>{
  let p=decodeURIComponent((req.url||'/').split('?')[0]);
  if(p==='/'||p==='') p='/index.html';
  const fp=path.normalize(path.join(root,p));
  if(!fp.startsWith(root)){ res.writeHead(403); res.end('forbidden'); return; }
  fs.readFile(fp,(e,data)=>{
    if(e){ res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200,{'Content-Type':types[path.extname(fp)]||'application/octet-stream'});
    res.end(data);
  });
}).listen(4599,()=>console.log('Komunigo preview su http://localhost:4599'));
