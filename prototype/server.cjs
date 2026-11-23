const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');

const files = new Set(['index.html','style.css','desktop.css','material.css','core.js','app.js']);
const source = (process.env.TASK_TRACK_NOTION_SOURCE || '').replaceAll('-','').toLowerCase();
const token = process.env.TASK_TRACK_NOTION_TOKEN;
const field = 'Type of Work';
const port = Number(process.env.TASK_TRACK_PORT || 4173);
const store=require('./local-database.cjs');
// Pin writes to the personal proof-of-concept source, even if a different ID is supplied.
const personalSourceHash = '117075600d8bff213300256469d29985965fe9ec27dc4b703541c195d2a2204b';
let writes = Promise.resolve();

async function notionRequest(method, body) {
  const response = await fetch('https://api.notion.com/v1/data_sources/'+source,{
    method, signal:AbortSignal.timeout(10000),
    headers:{Authorization:'Bearer '+token,'Notion-Version':'2025-09-03','Content-Type':'application/json'},
    body:body && JSON.stringify(body)
  });
  if(!response.ok) throw Error('Notion request failed');
  const data = await response.json();
  const options = data.properties?.[field]?.multi_select?.options;
  if(!Array.isArray(options)) throw Error('Missing work type property');
  return options;
}
async function appendOption(name) {
  const existing = await notionRequest('GET');
  if(existing.some(o=>o.name.trim().toLowerCase()===name.toLowerCase())) return existing;
  const options = [...existing.map(o=>({id:o.id})),{name}];
  return notionRequest('PATCH',{properties:{[field]:{multi_select:{options}}}});
}
function json(res,status,data) {
  res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});
  res.end(JSON.stringify(data));
}
async function catalog(req,res) {
  const host=req.headers.host;
  if(!['127.0.0.1:'+port,'localhost:'+port].includes(host)) return json(res,403,{});
  if(req.method==='POST' && (req.headers.origin!=='http://'+host || req.headers['content-type']!=='application/json')) return json(res,403,{});
  if(!['GET','POST'].includes(req.method)) return json(res,405,{});
  if(!token && !source) return json(res,req.method==='GET'?200:503,{connected:false});
  if(!token || createHash('sha256').update(source).digest('hex')!==personalSourceHash) return json(res,503,{});
  let options;
  if(req.method==='GET') options=await notionRequest('GET');
  else {
    let body='';
    for await(const chunk of req) {
      body+=chunk;
      if(Buffer.byteLength(body)>2048) return json(res,413,{});
    }
    let input;
    try{input=JSON.parse(body);}catch{return json(res,400,{});}
    const name=typeof input?.name==='string'?input.name.trim().replace(/\s+/g,' '):'';
    if(!name || name.length>80 || name.includes(',')) return json(res,400,{});
    const pending=writes.then(()=>appendOption(name));
    writes=pending.catch(()=>{});
    options=await pending;
  }
  return json(res,200,{connected:true,options:options.map(({name,color})=>({name,color}))});
}
async function database(req,res) {
  const host=req.headers.host;
  if(!['127.0.0.1:'+port,'localhost:'+port].includes(host) || req.headers['x-task-track']!=='local') return json(res,403,{});
  if(req.method==='GET') return json(res,200,store.read());
  if(req.method!=='PUT') return json(res,405,{});
  if(req.headers.origin!=='http://'+host || req.headers['content-type']!=='application/json') return json(res,403,{});
  const chunks=[];let bytes=0;
  for await(const chunk of req){bytes+=chunk.length;if(bytes>32*1024*1024)return json(res,413,{});chunks.push(chunk);}
  const {state,tag}=JSON.parse(Buffer.concat(chunks).toString('utf8'));
  return json(res,200,store.write(state,tag));
}
http.createServer((req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname;
  if(pathname==='/api/database'){database(req,res).catch(e=>json(res,e.status||500,{error:e.status===409?e.message:'Could not read or write the local CSV. Check the file and folder permissions.'}));return;}
  if(pathname==='/api/work-types'){catalog(req,res).catch(()=>json(res,502,{}));return;}
  const file=pathname.slice(1)||'index.html';
  if(!files.has(file)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',file.endsWith('.css')?'text/css; charset=utf-8':file.endsWith('.js')?'text/javascript; charset=utf-8':'text/html; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  fs.createReadStream(path.join(__dirname,file)).pipe(res);
}).listen(port,'127.0.0.1',()=>console.log('Task Track: http://127.0.0.1:'+port));
