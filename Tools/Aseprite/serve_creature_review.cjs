const http=require('node:http');const fs=require('node:fs');const path=require('node:path');
const file=path.resolve(__dirname,'../../Assets/Generated/CreatureProductionV1/review.html');
http.createServer((req,res)=>{if(req.url==='/'||req.url==='/review.html'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});fs.createReadStream(file).pipe(res);}else{res.writeHead(404);res.end();}}).listen(8795,'127.0.0.1',()=>console.log('Creature review: http://127.0.0.1:8795/review.html'));
