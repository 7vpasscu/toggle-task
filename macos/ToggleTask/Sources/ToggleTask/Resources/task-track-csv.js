'use strict';
// The desktop preview and macOS use this same tabular contract.
(function(root){
const columns = ["Local ID","Row kind","Sub-item name","Project","Parent item","Sub-items","Client","Brand","Project Area","Project Status","Workflow Status","Assigned To","Requested By (PM)","Recorded By","Worker ID","Created By","Session Start","Session End","Session Minutes","Type of Work","Units","Historical Minutes","Logged Minutes","Sub-item Minutes","Total Time","Total Time (Original)","Quantity","Work Types (Auto)","Project Participants","First Session Start","Last Session End","Month","Last Edited","Continuation of","Source","App metadata"];
const fail = message => { throw Error('Local CSV: '+message); };
const list = value => JSON.stringify(value ?? []);
const iso = value => value == null ? '' : new Date(value).toISOString();
const sum = (rows,fn) => rows.reduce((n,r)=>n+fn(r),0);
function cell(value){
  let s=String(value??'');
  // Excel treats some text as a formula even inside quotes. Escape reversibly.
  if (/^(?:'|\s*[=+\-@]|[\t\r\n])/.test(s)) s="'"+s;
  return '"'+s.replace(/"/g,'""')+'"';
}
function parse(text){
  const s=text.replace(/^\uFEFF/,''), rows=[];
  let row=[], field='', quoted=false, closed=false;
  const finish=()=>{row.push(field.startsWith("'")?field.slice(1):field);field='';closed=false;};
  for(let i=0;i<s.length;i++){
    const c=s[i];
    if(quoted){
      if(c!=='"') field+=c;
      else if(s[i+1]==='"'){field+='"';i++;}
      else {quoted=false;closed=true;}
    }else if(c===',') finish();
    else if(c==='\r'||c==='\n'){
      finish();rows.push(row);row=[];
      if(c==='\r'&&s[i+1]==='\n')i++;
    }else if(!closed && c==='"' && !field) quoted=true;
    else if(closed||c==='"')fail('Invalid quoting.');
    else field+=c;
  }
  if(quoted)fail('Incomplete quoted field.');
  if(field||closed||row.length){finish();rows.push(row);}
  return rows;
}
function encode(state){
  const {projects,sessions,active,...preferences}=state;
  const all=active?[...sessions,active]:sessions;
  const rows=[{'Row kind':'Settings','App metadata':JSON.stringify(preferences)}];
  const byProject=new Map(),names=new Map(projects.map(p=>[p.id,p.name]));
  const users=new Map(state.users.map(u=>[u.id,u.name]));
  for(const s of all){
    if(!byProject.has(s.projectId))byProject.set(s.projectId,[]);
    byProject.get(s.projectId).push(s);
  }
  for(const p of projects){
    const children=byProject.get(p.id)||[],done=children.filter(s=>s.end!=null);
    const mins=sum(done,s=>(s.end-s.start)/60000);
    const types=[...new Set(done.map(s=>s.workType).filter(Boolean))];
    const counts=new Map(),seen=new Set();
    for(const s of done){
      const k=s.continuationOf||s.id;if(seen.has(k))continue;seen.add(k);
      if(s.workType)counts.set(s.workType,(counts.get(s.workType)||0)+(s.units||0));
    }
    const row={...p.notion,'Row kind':'Project','Local ID':p.id,'Sub-item name':p.name,'Project':p.name,
      'Client':p.client,'Brand':p.brand,'Project Area':p.area,'Project Status':p.status||(p.archived?'Archived':'Active'),
      'Assigned To':list(p.participants),'Type of Work':list(p.workTypes),'Sub-items':list(children.map(s=>s.id)),
      'Historical Minutes':p.historicalMinutes??0,'Logged Minutes':mins,'Sub-item Minutes':mins,'Total Time':(p.historicalMinutes||0)+mins,
      'Quantity':JSON.stringify(Object.fromEntries(counts)),'Work Types (Auto)':list(types),
      'Project Participants':list([...new Set(done.map(s=>s.userId).filter(Boolean))]),
      'First Session Start':done.length?iso(done.reduce((v,s)=>Math.min(v,s.start),Infinity)):'',
      'Last Session End':done.length?iso(done.reduce((v,s)=>Math.max(v,s.end),-Infinity)):''};
    if(p.archived)row['Project Status']='Archived';
    rows.push(row);
  }
  for(const s of all){
    rows.push({...s.notion,'Row kind':s.end==null?'Timer':'Session','Local ID':s.id,'Parent item':s.projectId,
      'Project':names.get(s.projectId)||s.projectName,'Sub-item name':s.description,
      'Session Start':iso(s.start),'Session End':iso(s.end),'Session Minutes':s.end==null?'':(s.end-s.start)/60000,
      'Recorded By':s.recordedBy||users.get(s.userId),'Worker ID':s.userId,'Type of Work':list(s.workType?[s.workType]:[]),
      'Units':s.units??0,'Continuation of':s.continuationOf,'Source':s.source,'Month':iso(s.start).slice(0,7)});
  }
  return '\uFEFF'+[columns,...rows.map(r=>columns.map(c=>r[c]))].map(r=>r.map(cell).join(',')).join('\r\n')+'\r\n';
}
function decode(text){
  const [header,...records]=parse(text);
  if(!header||header.length!==columns.length||columns.some(c=>!header.includes(c)))fail('Unexpected column names.');
  const projects=[],sessions=[],ids=new Set();
  let active=null,prefs=null;
  const kept=['Created By','Requested By (PM)','Workflow Status','Last Edited','Total Time (Original)'];
  function number(s){const n=Number(s);if(!Number.isFinite(n)||n<0)fail('Invalid numeric value.');return n;}
  function date(s){const n=Date.parse(s);if(!Number.isFinite(n))fail('Invalid date.');return n;}
  function strings(s){const a=JSON.parse(s||'[]');if(!Array.isArray(a)||a.some(x=>typeof x!=='string'))fail('Invalid list.');return a;}
  for(const cells of records){
    if(cells.length!==header.length)fail('Incomplete row.');
    const r=Object.fromEntries(header.map((key,i)=>[key,cells[i]])),kind=r['Row kind'],id=r['Local ID'];
    if(kind==='Settings'){
      if(prefs)fail('Duplicate settings row.');
      prefs=JSON.parse(r['App metadata']);continue;
    }
    if(!id||ids.has(id))fail('Missing or duplicate ID.');ids.add(id);
    const notion=Object.fromEntries(kept.filter(k=>r[k]).map(k=>[k,r[k]]));
    if(kind==='Project'){
      projects.push({id,name:r.Project,client:r.Client,brand:r.Brand,area:r['Project Area'],status:r['Project Status'],
        archived:r['Project Status']==='Archived',participants:strings(r['Assigned To']),workTypes:strings(r['Type of Work']),
        historicalMinutes:number(r['Historical Minutes']),notion});
    }else if(kind==='Session'||kind==='Timer'){
      const s={id,projectId:r['Parent item'],projectName:r.Project,userId:r['Worker ID']||null,description:r['Sub-item name'],
        start:date(r['Session Start']),recordedBy:r['Recorded By'],source:r.Source,workType:strings(r['Type of Work'])[0]||'',
        units:number(r.Units),notion};
      if(r['Continuation of'])s.continuationOf=r['Continuation of'];
      if(kind==='Timer'){if(active||r['Session End'])fail('Invalid running timer.');active=s;}
      else {s.end=date(r['Session End']);if(s.end<=s.start)fail('Invalid session interval.');sessions.push(s);}
    }else fail('Unknown row type.');
  }
  if(!prefs||!Number.isSafeInteger(prefs.revision)||prefs.revision<0||!Array.isArray(prefs.users)||!Array.isArray(prefs.workTypes))fail('Missing settings.');
  const parents=new Set(projects.map(p=>p.id));
  if([...sessions,...(active?[active]:[])].some(s=>!parents.has(s.projectId)))fail('Unknown parent project.');
  return {...prefs,projects,sessions,active};
}
function encodeDesktop(json){
  const input=JSON.parse(json);
  const convert=s=>({...s,projectId:s.projectID??s.projectId,userId:s.workerID??s.workerId,start:s.startedAt,end:s.endedAt});
  const owner=input.workerID||input.workerId||'';
  return encode({version:3,revision:0,userId:owner,users:owner?[{id:owner,name:'Local profile'}]:[],
    workTypes:[...new Set(input.projects.flatMap(p=>p.workTypes))],projects:input.projects,
    sessions:input.sessions.map(convert),active:input.active?convert(input.active):null});
}
function decodeDesktop(csv){
  const data=decode(csv);
  const convert=s=>({...s,projectID:s.projectId,workerID:s.userId,startedAt:s.start,endedAt:s.end,
    recordedBy:s.recordedBy||'',source:s.source||'manual',durationSeconds:s.end?Math.floor((s.end-s.start)/1000):0});
  return JSON.stringify({projects:data.projects,sessions:data.sessions.map(convert),active:data.active?convert(data.active):null,workerID:data.userId||null});
}
const api={encode,decode,columns,encodeDesktop,decodeDesktop};
if(typeof module!=='undefined')module.exports=api;else root.TaskTrackCSV=api;
})(globalThis);
