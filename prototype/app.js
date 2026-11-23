'use strict';
const $=id=>document.getElementById(id), C=Tracker, KEY='toggle-task.v1';
let state, editing=null, undo=null, readOnly=false, manualMode=false, timelineDrag=null;
function migrate() {
  // Translate only built-in type labels. User-entered projects and descriptions are data.
  const legacy = new Map([['Visuales','Visuals'], ['Artes finales','Final artwork'], ['Propuestas','Proposals']]);
  for (const session of [...state.sessions, state.active].filter(Boolean)) {
    session.workType = legacy.get(session.workType) || session.workType;
  }
  state.workTypes = [...new Set([...C.types, ...(state.workTypes || []).map(t => legacy.get(t) || t), ...state.sessions.map(s => s.workType).filter(Boolean)])];
  state.version = 3;
}
function notify(message,action){const n=$('notice');n.replaceChildren(document.createTextNode(message));if(action){const b=document.createElement('button');b.textContent='Undo';b.onclick=action;n.append(b);}n.classList.add('show');clearTimeout(notify.timer);notify.timer=setTimeout(()=>n.classList.remove('show'),9000);}
let tag=null, saving=false;
async function database(method='GET',stateToWrite){
  const options={method,cache:'no-store',headers:{'X-Task-Track':'local'}};
  if(method==='PUT'){
    options.headers['Content-Type']='application/json';
    options.body=JSON.stringify({tag,state:stateToWrite});
  }
  const response=await fetch('/api/database',options);
  if(!response.ok){
    if(response.status===409)readOnly=true;
    const data=await response.json().catch(()=>({}));
    throw Error(data.error||'Local CSV unavailable. Reload after checking the local server.');
  }
  return response.json();
}
async function mutate(fn){
  if(saving){notify('Saving your previous change. Try again in a moment.');return false;}
  saving=true;
  try{
    if(readOnly)throw Error('Reload before changing the local CSV.');
    const next=structuredClone(state);
    if(remoteTypes)next.workTypes=[...new Set([...next.workTypes,...remoteTypes])];
    fn(next);next.revision++;
    $('saveState').textContent='Saving…';
    const saved=await database('PUT',next);
    tag=saved.tag;state=next;render();
    $('saveState').textContent='Saved to local CSV';return true;
  }catch(e){$('saveState').textContent='Could not save';notify(e.message);render();return false;}
  finally{saving=false;}
}
async function openDatabase(){
  document.querySelector('.layout').inert=true;
  try{
    const disk=await database();
    tag=disk.tag;
    if(disk.state)state=disk.state;
    else {
      const legacy=localStorage.getItem(KEY);
      state=legacy?JSON.parse(legacy):C.seed();
      migrate();
      tag=(await database('PUT',state)).tag;
    }
    $('databasePath').textContent=disk.file;
    render();setDay(new Date());$('saveState').textContent='Saved to local CSV';
    refreshCatalog();setInterval(tick,500);
    document.querySelector('.layout').inert=false;
  }catch(e){readOnly=true;$('saveState').textContent='Local CSV unavailable';notify(e.message);}
}
function el(tag,text,cls){const e=document.createElement(tag);if(text!=null)e.textContent=text;if(cls)e.className=cls;return e;}
function options(select,items,current){select.replaceChildren(...items.map(x=>{const o=document.createElement('option');o.value=x.id;o.textContent=x.name;return o;}));if(items.some(x=>x.id===current))select.value=current;}
function optionList(list,values){list.replaceChildren(...values.map(value=>{const option=document.createElement('option');option.value=value;return option;}));}
function normalized(value){return String(value??'').trim().replace(/\s+/g,' ');}
function sameName(a,b){return normalized(a).localeCompare(normalized(b),undefined,{sensitivity:'accent'})===0;}
const projectName=id=>state.projects.find(p=>p.id===id)?.name||'Unknown project';
const projectForName=name=>state.projects.find(p=>sameName(p.name,name));
const userName=id=>state.users.find(p=>p.id===id)?.name||'Unknown profile';
function inPeriod(s,period){const now=new Date();const start=period==='today'?new Date(now.getFullYear(),now.getMonth(),now.getDate()).getTime():period==='week'?Date.now()-7*86400000:0;return s.end>start;}
function filtered(){const q=$('search').value.toLocaleLowerCase();return C.mine(state).filter(s=>inPeriod(s,$('period').value)&&(s.description+' '+projectName(s.projectId)).toLocaleLowerCase().includes(q)).sort((a,b)=>b.start-a.start);}
function action(text,callback){const b=el('button',text);b.onclick=callback;return b;}
function workTypes(){return remoteTypes ?? state.workTypes ?? C.types;}
function descriptionSuggestions(projectID){return Array.from(new Set(C.mine(state).filter(s=>s.projectId===projectID&&s.description.trim()).map(s=>s.description.trim()))).sort((a,b)=>a.localeCompare(b,'en'));}
function currentProjectID(){return projectForName($('project').value)?.id;}
function render(){
 const available=state.projects.filter(p=>!p.archived);
 if(state.active&&!manualMode) $('project').value=projectName(state.active.projectId);
 else if(!$('project').value || projectForName($('project').value)?.archived) $('project').value=available[0]?.name || '';
 if(!$('workType').value) $('workType').value=workTypes()[0] || '';
 options($('user'),state.users,state.userId);
 optionList($('descriptionOptions'),descriptionSuggestions(currentProjectID()));
 $('user').disabled=!!state.active;for(const id of ['project','description','workType','units'])$(id).disabled=!!state.active&&!manualMode;
 if(state.active&&!manualMode){$('description').value=state.active.description;$('workType').value=state.active.workType;$('units').value=state.active.units;}
 $('manualDurationWrap').hidden=!manualMode;$('clock').hidden=manualMode;$('manualMinutes').required=manualMode;
 $('toggle').textContent=manualMode?'✓':state.active?'■':'▶';$('toggle').setAttribute('aria-label',manualMode?'Save manual entry':state.active?'Stop timer':'Start timer');$('toggle').classList.toggle('running',!!state.active);
 $('miniToggle').textContent=state.active?'Stop':'Start';$('activeHint').textContent=manualMode?'Enter the minutes you worked.':state.active?'Timer running.':'Ready to track.';
 $('miniDescription').textContent=state.active?.description||'Ready to track';$('palette').value=state.palette||'lilac';$('theme').value=state.theme||'dark';document.body.dataset.palette=state.palette||'lilac';document.body.dataset.theme=state.theme||'dark';
 renderSessions();renderProjects();renderReports();renderDay();tick();}
function tick(){const value=C.format(state.active?(Date.now()-state.active.start)/1000:0);for(const id of ['clock','menuClock','miniClock'])$(id).textContent=value;document.title=state.active?value+' · Task Track':'Task Track';}
function aggregate(records){const grouped=new Map();for(const session of records){const key=C.logicalID(session),root=C.rootFor(state,session);let item=grouped.get(key);if(!item){item={id:key,root,segments:[],seconds:0};grouped.set(key,item);}item.segments.push(session);item.seconds+=C.seconds(session);}return [...grouped.values()].sort((a,b)=>Math.max(...b.segments.map(s=>s.start))-Math.max(...a.segments.map(s=>s.start)));}
function renderSessions(){const list=filtered(),target=$('sessions');target.replaceChildren();const days=new Map();for(const session of list){const key=localDate(session.start).slice(0,10);if(!days.has(key))days.set(key,[]);days.get(key).push(session);}const groups=[...days.entries()].map(([day,records])=>[day,aggregate(records)]);const count=groups.reduce((n,[,items])=>n+items.length,0);$('sessionCount').textContent=count+(count===1?' task':' tasks');$('total').textContent=C.format(list.reduce((n,s)=>n+C.seconds(s),0));
 if(!groups.length){target.append(el('p','No matching sessions for this profile.','empty'));return;}
 for(const [day,items] of groups){const group=el('section',null,'daygroup'),header=el('header'),date=new Date(day+'T12:00:00'),label=day===localDate(Date.now()).slice(0,10)?'Today':date.toLocaleDateString('en-GB',{weekday:'short',day:'numeric',month:'short'});header.append(el('strong',label),el('time',C.format(items.reduce((n,item)=>n+item.seconds,0))));group.append(header);
  for(const item of items){const session=item.root,row=el('article',null,'session'),detail=action('',()=>openEditor(session));detail.className='details';const project=state.projects.find(p=>p.id===session.projectId),line=el('p'),dot=el('span',null,'projectdot');dot.style.background=typeColor(session.workType);dot.title=session.workType;line.append(dot,document.createTextNode(projectName(session.projectId)+' · '+(project?.brand || 'Unassigned brand')+' · '+session.workType));detail.append(el('span',session.description||'+ Add description'),line);detail.setAttribute('aria-label', 'Edit '+(session.description||'session'));
   const resume=action('▶',async()=>{if(await mutate(next=>{const root=C.rootFor(next,session);C.start(next,{projectId:root.projectId,description:root.description,workType:root.workType,units:root.units,continuationOf:C.logicalID(root)});})){setManualMode(false);notify('Tracking more time on this task.');}});resume.className='resume';resume.setAttribute('aria-label','Resume '+(session.description||'session'));row.append(detail,el('time',C.format(item.seconds)),resume);group.append(row);}target.append(group);}
}
function typeColor(type){const builtin={'Visuals':'#648ec7','Final artwork':'#c98444','Proposals':'#21a58a'};if(Object.hasOwn(builtin,type))return builtin[type];const colors=['#21a58a','#ad78cb','#c99422','#648ec7'];return colors[Array.from(type||'').reduce((hash,c)=>(hash*31+c.codePointAt(0))>>>0,0)%colors.length];}
function renderProjects() {
  const target = $('projects'); target.replaceChildren();
  for (const project of state.projects) {
    const card = el('article',null,'projectcard'), header = el('header');
    header.append(el('h2',project.name), action('Edit',() => openProject(project)));
    card.append(header,el('p',(project.brand || 'Unassigned brand') + ' · ' + (project.archived?'Archived':'Active')));
    const archive = action(project.archived?'Restore':'Archive',() => mutate(n => {
      if(n.active?.projectId === project.id) throw Error('Stop the timer before archiving this project.');
      n.projects.find(p=>p.id===project.id).archived = !project.archived;
    }));
    card.append(archive); target.append(card);
  }
}
function renderReports() {
  const period = $('reportPeriod').value;
  $('customDaysField').hidden = period !== 'custom';
  const selected = $('dayDate').value ? new Date(dayBounds()[0]) : new Date();
  selected.setHours(0,0,0,0);
  const end = new Date(selected); end.setDate(end.getDate()+1);
  const start = new Date(selected);
  const days = Number(period==='custom' ? $('customDays').value : period);
  const area = $('reports'); area.replaceChildren();
  if(period==='custom' && (!Number.isInteger(days) || days<1 || days>3660)) {
    $('reportRange').textContent='Enter a whole number from 1 to 3660.'; return;
  }
  if(period!=='all') start.setDate(start.getDate()-days+1);
  const dateLabel=d=>d.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
  $('reportRange').textContent=period==='all'?'All recorded dates':days===1?dateLabel(selected):dateLabel(start)+' – '+dateLabel(selected);
  const mine=C.mine(state);
  const ids=new Set(mine.map(s=>s.projectId));
  const available=state.projects.filter(p=>ids.has(p.id));
  const brandKey=p=>'brand:'+(p.brand || '').trim().toLocaleLowerCase('en');
  const brands=new Map(available.map(p=>[brandKey(p),p.brand?.trim() || 'Unassigned brand']));
  const byName=(a,b)=>a.name.localeCompare(b.name,'en');
  const brandSelect=$('reportBrand'), projectSelect=$('reportProject');
  options(brandSelect,[{id:'',name:'All brands'},...[...brands].map(([id,name])=>({id,name})).sort(byName)],brandSelect.value);
  const projects=available.filter(p=>!brandSelect.value || brandKey(p)===brandSelect.value);
  options(projectSelect,[{id:'',name:'All projects'},...projects.sort(byName)],projectSelect.value);
  const matching=new Set(projects.map(p=>p.id));
  const records=mine.filter(s=>
    (!brandSelect.value || matching.has(s.projectId)) &&
    (!projectSelect.value || s.projectId===projectSelect.value) &&
    (period==='all' || C.dayOverlap(s,+start,+end)>0));
  const totals = new Map();
  let total=0;
  for(const s of records){
    const ms = period==='all'?s.end-s.start:C.dayOverlap(s,+start,+end);
    total+=ms;
    const project = totals.get(s.projectId) || {ms:0,types:new Map(),tasks:new Set(),sessions:[]};
    project.ms+=ms; project.sessions.push(s);
    const key=C.logicalID(s);
    if(!project.tasks.has(key)){
      project.types.set(s.workType,(project.types.get(s.workType)||0)+s.units);
      project.tasks.add(key);
    }
    totals.set(s.projectId,project);
  }
  area.append(el('h1',C.format(total/1000)));
  for(const [id,project] of [...totals].sort((a,b)=>b[1].ms-a[1].ms)){
    const sessions=project.sessions.sort((a,b)=>b.start-a.start || a.id.localeCompare(b.id));
    const go=session=>showReportedSession(session,period==='all'?session.start:Math.max(session.start,+start));
    const card=el('article',null,'projectcard reportCard'), summary=action('',()=>go(sessions[0]));
    summary.className='reportLink';
    summary.setAttribute('aria-label','Show '+projectName(id)+' in Calendar');
    const bar=el('div',null,'bar'),fill=el('span');
    fill.style.width=(project.ms/total*100)+'%'; bar.append(fill);
    summary.append(el('strong',projectName(id)+' · '+C.format(project.ms/1000)),bar,
      el('p',[...project.types].map(([type,n])=>type+' · '+n+' units').join(' / ')));
    card.append(summary);
    if(sessions.length>1) {
      const choices=el('details');
      choices.append(el('summary',sessions.length+' sessions'));
      for(const session of sessions){
        const date=new Date(session.start).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
        choices.append(action(date+' · '+clockTime(session.start)+' · '+(session.description||'No description'),()=>go(session)));
      }
      card.append(choices);
    }
    area.append(card);
  }
  if(!total) area.append(el('p','No time logged during this period.','empty'));
}
async function toggle(){if((manualMode||!state.active)&&(!workTypes().some(t=>sameName(t,$('workType').value))||!projectForName($('project').value))){notify('Select a project and type, or create one from the dropdown.');return false;}if(manualMode){const minutes=C.parseMinutes($('manualMinutes').value);if(!minutes){notify('Enter a duration such as 26, 126 or 1:26.');return false;}const end=Date.now(),session={id:C.id(),userId:state.userId,projectId:currentProjectID(),description:$('description').value.trim(),workType:workTypes().find(t=>sameName(t,$('workType').value)),units:Number($('units').value),start:end-minutes*60000,end};const saved=await mutate(n=>C.upsert(n,session));if(saved)notify('Manual entry saved.');return saved;}return mutate(n=>{if(n.active)C.stop(n);else C.start(n,{projectId:currentProjectID(),description:$('description').value.trim(),workType:workTypes().find(t=>sameName(t,$('workType').value)),units:Number($('units').value)});});}
$('timerForm').onsubmit=async e=>{e.preventDefault();await toggle();};$('miniToggle').onclick=async()=>{if(state.active)await mutate(n=>C.stop(n));else {setManualMode(false);await toggle();}};
$('miniButton').onclick=()=>{$('mini').hidden=!$('mini').hidden;$('miniButton').setAttribute('aria-expanded',String(!$('mini').hidden));};
document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='d'&&!e.altKey){e.preventDefault();if(!$('editor').open&&!$('projectEditor').open)setManualMode(!manualMode);return;}if(e.key==='Escape'){$('mini').hidden=true;$('miniButton').setAttribute('aria-expanded','false');}if((e.ctrlKey||e.metaKey)&&e.key==='Enter'&&!$('editor').open&&!$('projectEditor').open){e.preventDefault();toggle();}});
const headings={timer:'Your sessions',day:'Calendar',reports:'Reports',settings:'Settings'};
function showView(view){const tracking=['timer','day'].includes(view);$('viewSegments').hidden=!tracking;$('backToTracking').hidden=tracking;const b=document.querySelector('.segments [data-view="'+view+'"]') || document.querySelector('[data-view="'+view+'"]');for(const v of Object.keys(headings))$(v+'View').hidden=v!==view;document.querySelectorAll('[data-view]').forEach(x=>{x.classList.toggle('selected',x===b);x.setAttribute('aria-pressed',String(x===b));x.setAttribute('aria-current',x===b?'page':'false');});$('heading').textContent=headings[view];$('trackingHeader').hidden=!['timer','day'].includes(view);$('moreNav').hidden=true;$('moreButton').setAttribute('aria-expanded','false');if(view==='reports'){$('reportPeriod').value='1';renderReports();}if(view==='day')renderDay();}
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>showView(b.dataset.view));$('moreButton').onclick=()=>{$('moreNav').hidden=!$('moreNav').hidden;$('moreButton').setAttribute('aria-expanded',String(!$('moreNav').hidden));};
$('user').onchange=async()=>{await mutate(n=>{if(n.active)throw Error('Stop the timer before switching profiles.');n.userId=$('user').value;});};for(const id of ['search','period'])$(id).addEventListener('input',renderSessions);for(const id of ['reportBrand','reportProject','reportPeriod']) $(id).onchange=renderReports;$('customDays').oninput=renderReports;$('project').onchange=()=>optionList($('descriptionOptions'),descriptionSuggestions(currentProjectID()));
function localDate(time){const d=new Date(time);return new Date(time-d.getTimezoneOffset()*60000).toISOString().slice(0,16);}
function setupPicker(id, values, create, kind, changed) {
  const input = $(id), list = $(id + 'List'), arrow = input.parentElement.querySelector('button');
  let choices = [], highlighted = -1, busy = false;
  function close() {
    list.hidden = true;
    input.setAttribute('aria-expanded','false');
    input.removeAttribute('aria-activedescendant');
    highlighted = -1;
  }
  function highlight(index) {
    highlighted = index;
    [...list.children].forEach((option,i) => option.setAttribute('aria-selected', String(i === index)));
    if (index >= 0) {
      input.setAttribute('aria-activedescendant', list.children[index].id);
      list.children[index].scrollIntoView({block:'nearest'});
    }
  }
  async function choose(choice) {
    if (!choice || busy) return;
    busy = true;
    try {
      const name = choice.create ? await create(choice.name) : choice.name;
      if (name) {input.value = name; changed();}
    } catch(error) { notify(error.message); }
    finally { busy = false; close(); }
  }
  function open(filter) {
    const typed = normalized(input.value), query = filter ? typed.toLowerCase() : '';
    choices = values().filter(v => v.toLowerCase().includes(query)).map(name => ({name}));
    if (filter && typed && !values().some(v=>sameName(v,typed))) choices.push({name:typed,create:true});
    list.replaceChildren();
    choices.forEach((choice,i) => {
      const item = el('div',choice.create ? '+ Create '+kind+' “'+choice.name+'”' : choice.name);
      item.id = id+'Option'+i; item.setAttribute('role','option'); item.setAttribute('aria-selected','false');
      item.onmousedown = e => e.preventDefault();
      item.onclick = () => choose(choice);
      list.append(item);
    });
    highlighted = -1;
    input.removeAttribute('aria-activedescendant');
    list.hidden = choices.length === 0;
    input.setAttribute('aria-expanded',String(!list.hidden));
  }
  input.onfocus = () => { input.select(); open(false); };
  input.onclick = () => { if(list.hidden) open(false); };
  input.oninput = () => { open(true); changed(); };
  input.onblur = () => {
    const exact = values().find(v=>sameName(v,input.value));
    if(exact) input.value = exact;
    close(); changed();
  };
  arrow.onmousedown = e => e.preventDefault();
  arrow.onclick = () => {
    if(input.disabled) return;
    if(!list.hidden){close();return;}
    input.focus();open(false);
  };
  input.onkeydown = e => {
    if(e.key === 'Escape' && !list.hidden) {e.preventDefault();e.stopPropagation();close();return;}
    if(e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault(); if(list.hidden) open(false);
      if(choices.length) highlight(e.key==='ArrowDown' ? (highlighted+1)%choices.length : (highlighted<=0?choices.length-1:highlighted-1));
    }
    if(e.key === 'Enter' && !list.hidden) {
      e.preventDefault(); choose(choices[highlighted<0?0:highlighted]);
    }
    if(e.key === 'Tab' && highlighted >= 0 && !choices[highlighted].create) {
      input.value=choices[highlighted].name; changed();
    }
  };
}
let remoteTypes = null;
let catalogLoadFailed = false;
const typeLabels = new Map([['Visuales','Visuals'],['Artes finales','Final artwork'],['Propuestas','Proposals']]);
function displayType(name){return typeLabels.get(name) || name;}
async function refreshCatalog() {
  try {
    const response = await fetch('/api/work-types');
    if(response.status===404) return;
    if(!response.ok) throw Error('Could not read the Notion work types. Check the connection and reload.');
    const catalog=await response.json();
    if(catalog.connected) {
      remoteTypes=catalog.options.map(o=>displayType(o.name));
      $('catalogStatus').textContent='Work types connected · Sessions saved locally.';
      if(!remoteTypes.includes($('workType').value) && !state.active) $('workType').value=remoteTypes[0] || '';
    }
  } catch(error){catalogLoadFailed=true;$('catalogStatus').textContent='Work type connection unavailable. Reload to retry.';notify(error.message);}
}
async function createType(name) {
  // When Notion is unavailable the local CSV catalog remains writable.
  if(remoteTypes !== null) {
    const response=await fetch('/api/work-types',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name})});
    if(!response.ok) throw Error('Notion is unavailable. Reload to use the offline catalog.');
    remoteTypes=(await response.json()).options.map(o=>displayType(o.name));
    name=remoteTypes.find(value=>sameName(value,name)) || name;
  }
  let saved;
  if(!await mutate(n=>{saved=C.addWorkType(n,name);})) return;
  notify(remoteTypes===null?'Work type saved on this device.':'Work type saved in Notion.');
  return saved;
}
async function createPickerProject(name) {
  if(!projectForName(name) && !await mutate(n=>n.projects.push({id:C.id(),name,client:'',brand:'',historicalMinutes:0,archived:false}))) return;
  return projectForName(name).name;
}
function syncEditorChoices() {
  optionList($('descriptionOptions'), descriptionSuggestions(projectForName($('editProject').value)?.id));
}
for(const id of ['workType','editType']) setupPicker(id,workTypes,createType,'type',()=>{});
for(const id of ['project','editProject']) setupPicker(id,()=>state.projects.filter(p=>!p.archived).map(p=>p.name),createPickerProject,'project',()=>optionList($('descriptionOptions'),descriptionSuggestions(projectForName($(id).value)?.id)));
$('editor').addEventListener('close',()=>optionList($('descriptionOptions'),descriptionSuggestions(currentProjectID())));
let editorStart, originalLength, durationChanged, lockedInterval;
function openEditor(session, range) {
  if(session) {try{C.own(state,session);}catch(e){notify(e.message);return;}}
  lockedInterval = range ? {start:range.start, end:range.end} : null;
  const locked = Boolean(lockedInterval);
  $('editTimeFields').hidden = locked;
  $('editTimeFields').disabled = locked;
  $('selectedInterval').hidden = !locked;
  if(locked) {
    const date = stamp => new Date(stamp).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
    const endLabel = date(range.start)===date(range.end) ? '' : date(range.end)+' ';
    $('selectedInterval').textContent = date(range.start)+' · '+clockTime(range.start)+'–'+endLabel+clockTime(range.end)+' · '+C.format((range.end-range.start)/1000);
  }
  editing = session?.id ?? null;
  editorStart = range?.start ?? session?.start ?? Date.now()-1800000;
  originalLength = (range?.end ?? session?.end ?? Date.now()) - editorStart;
  durationChanged = false;
  $('editTitle').textContent = session ? 'Edit session' : 'Add session';
  $('editDescription').value = session?.description ?? '';
  $('editProject').value = session ? projectName(session.projectId) : $('project').value;
  $('editStart').value = localDate(editorStart).slice(0,10);
  $('editDuration').value = C.format(Math.max(60,originalLength/1000));
  $('editType').value = session?.workType || $('workType').value || workTypes()[0];
  $('editUnits').value = session?.units ?? Number($('units').value);
  $('editError').textContent = '';
  $('deleteEdit').hidden = !session;
  syncEditorChoices();
  $('editor').showModal();
}
function editorRange(minutes) {
  if(lockedInterval) return lockedInterval;
  const date = $('editStart').value;
  const start = new Date(editorStart);
  if (date !== localDate(editorStart).slice(0,10)) {
    const [year,month,day] = date.split('-').map(Number);
    start.setFullYear(year,month-1,day);
  }
  const length = durationChanged ? minutes*60000 : originalLength;
  return {start:+start, end:+start+length};
}
$('editDuration').addEventListener('input',()=>{durationChanged=true;});
for(const id of ['manualMinutes','editDuration']) $(id).addEventListener('blur',()=>{
  const minutes=C.parseMinutes($(id).value);
  if(minutes) $(id).value=C.format(minutes*60);
});
$('cancelEdit').onclick=()=>$('editor').close();
$('editForm').onsubmit=async e=>{e.preventDefault();const project=projectForName($('editProject').value),workType=workTypes().find(t=>sameName(t,$('editType').value));if(!lockedInterval && !C.parseMinutes($('editDuration').value)){$('editError').textContent='Enter a duration such as 26, 126 or 1:26.';return;}if(!project){$('editError').textContent='Choose a project or use + to create one.';return;}if(!workType){$('editError').textContent='Choose a work type or use + to create one.';return;}const existing=state.sessions.find(s=>s.id===editing);const session={id:editing||C.id(),userId:existing?.userId||state.userId,projectId:project.id,description:$('editDescription').value.trim(),...editorRange(C.parseMinutes($('editDuration').value)),workType,units:Number($('editUnits').value),continuationOf:existing?.continuationOf};try{C.validate(session,remoteTypes ? {...state,workTypes:[...new Set([...state.workTypes,...remoteTypes])]} : state);}catch(error){$('editError').textContent=error.message;return;}if(await mutate(n=>C.upsert(n,session))){$('editor').close();notify('Session saved.');}};
$('deleteEdit').onclick=async()=>{if(editing&&await mutate(n=>C.remove(n,editing))){$('editor').close();notify('Task and tracked intervals deleted.');}};
let editingProject = null;
function openProject(project) {
  editingProject = project?.id;
  $('projectTitle').textContent = project ? 'Edit project' : 'New project';
  $('saveProject').textContent = project ? 'Save changes' : 'Create project';
  $('projectName').value = project?.name || '';
  $('brandName').value = project?.brand || '';
  $('projectEditor').showModal();
}
$('newProject').onclick=()=>openProject();
$('cancelProject').onclick=()=>$('projectEditor').close();
$('projectForm').onsubmit=async event=>{
  event.preventDefault();
  const name=normalized($('projectName').value), brand=normalized($('brandName').value);
  if(await mutate(n=>{
    if(!name || !brand) throw Error('Enter a project name and brand.');
    if(n.projects.some(p=>p.id!==editingProject && sameName(p.name,name))) throw Error('That project already exists.');
    if(editingProject) Object.assign(n.projects.find(p=>p.id===editingProject),{name,brand});
    else n.projects.push({id:C.id(),name,brand,client:'',historicalMinutes:0,archived:false});
  })) $('projectEditor').close();
};
$('profileForm').onsubmit=async e=>{e.preventDefault();if(await mutate(n=>{if(n.active)throw Error('Stop the timer before switching profiles.');const name=normalized($('profileName').value);if(!name)throw Error('Enter a name.');if(n.users.some(u=>sameName(u.name,name)))throw Error('That profile already exists.');const id=C.id();n.users.push({id,name});n.userId=id;}))$('profileForm').reset();};
for(const id of ['palette','theme'])$(id).onchange=()=>mutate(n=>{n[id]=$(id).value;});
function download(name,text,type){const url=URL.createObjectURL(new Blob([text],{type})),a=el('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('backup').onclick=()=>download('task-track-backup.json',JSON.stringify(C.personalBackup(state),null,2),'application/json');
$('export').onclick=()=>download('task-track-sessions.csv',C.csv([['ID','Project','Activity','Profile','Start','End','Minutes','Work type','Units'],...filtered().map(s=>[s.id,projectName(s.projectId),s.description,userName(s.userId),new Date(s.start).toISOString(),new Date(s.end).toISOString(),C.minutes(C.seconds(s)),s.workType,s.units])]),'text/csv;charset=utf-8');
function dayBounds(){const [y,m,d]=$('dayDate').value.split('-').map(Number);const start=new Date(y,m-1,d),end=new Date(y,m-1,d+1);return [start.getTime(),end.getTime()];}
function showReportedSession(session, timestamp) {
  setDay(new Date(timestamp));
  showView('day');
  const target=[...$('timeline').querySelectorAll('.timeblock')].find(el=>el.dataset.sessionId===session.id);
  if(target) requestAnimationFrame(()=>{
    target.classList.add('reported');
    target.focus({preventScroll:true});
    target.scrollIntoView({block:'center',inline:'nearest'});
  });
}
// Sessions arrive in start order. Each overlapping group shares the available width.
function placeDayBlocks(records,start,end) {
  let lanes=[], group=[];
  const flush=()=>{
    for(const {block,lane} of group){
      block.style.left=(lane/lanes.length*100)+'%';
      block.style.width='calc('+(100/lanes.length)+'% - 2px)';
    }
    group=[];lanes=[];
  };
  const layer=el('div',null,'dayBlocks');
  for(const session of records){
    const top=(Math.max(session.start,start)-start)/60000;
    const duration=C.dayOverlap(session,start,end)/60000;
    if(lanes.every(bottom=>bottom<=top)) flush();
    let lane=lanes.findIndex(bottom=>bottom<=top);
    if(lane<0) lane=lanes.length;
    const height=Math.min(Math.max(16,duration),(end-start)/60000-top);
    lanes[lane]=top+height;
    const block=action((session.description||'No description')+' · '+C.format(duration*60),()=>openEditor(session));
    block.className='timeblock';block.dataset.sessionId=session.id;
    block.style.top=top+'px';block.style.height=height+'px';
    block.title=block.textContent;block.style.borderLeftColor=typeColor(session.workType);
    group.push({block,lane});layer.append(block);
  }
  flush();return layer;
}
function renderDay() {
  if(!$('dayDate').value) return;
  const [start,end]=dayBounds(),records=C.daily(state,start,end),timeline=$('timeline');
  $('dayTotal').textContent=C.format(records.reduce((ms,s)=>ms+C.dayOverlap(s,start,end),0)/1000);
  timeline.replaceChildren();
  const dayMinutes=(end-start)/60000;
  timeline.style.height=dayMinutes+'px';
  for(let offset=0;offset<dayMinutes;offset+=60) {
    const cell=el('div',clockTime(start+offset*60000),'hour');
    cell.style.top=offset+'px'; timeline.append(cell);
  }
  timeline.append(placeDayBlocks(records,start,end));
  if(start<=Date.now()&&Date.now()<end){
    const line=el('div',null,'nowline'); line.style.top=((Date.now()-start)/60000)+'px';timeline.append(line);
  }
  const target=records.length?(Math.max(records[0].start,start)-start)/60000-90:(new Date().getHours()-2)*60;
  requestAnimationFrame(()=>$('timelineScroll').scrollTop=Math.max(0,target));
}
let displayedMonth;
function setDay(date) {
  $('dayDate').value=localDate(+date).slice(0,10);
  $('chooseDate').textContent=date.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
  renderDay();
}
function closeDates() {
  $('datePanel').hidden=true; $('chooseDate').setAttribute('aria-expanded','false');
}
function renderMonth() {
  const year=displayedMonth.getFullYear(), month=displayedMonth.getMonth();
  $('monthLabel').textContent=displayedMonth.toLocaleDateString('en-GB',{month:'long',year:'numeric'});
  const grid=$('dateGrid');
  grid.replaceChildren(...['Mo','Tu','We','Th','Fr','Sa','Su'].map(day=>el('span',day)));
  for(let i=0;i<(displayedMonth.getDay()+6)%7;i++) grid.append(el('span'));
  for(let day=1;day<=new Date(year,month+1,0).getDate();day++) {
    const date=new Date(year,month,day);
    const button=action(String(day),()=>{setDay(date);closeDates();$('chooseDate').focus();});
    button.setAttribute('aria-label',date.toLocaleDateString('en-GB',{dateStyle:'full'}));
    button.classList.toggle('selected',localDate(+date).slice(0,10)===$('dayDate').value);
    grid.append(button);
  }
}
$('chooseDate').onclick=()=>{
  if(!$('datePanel').hidden){closeDates();return;}
  displayedMonth=new Date(dayBounds()[0]); displayedMonth.setDate(1);
  renderMonth(); $('datePanel').hidden=false; $('chooseDate').setAttribute('aria-expanded','true');
  ($('dateGrid').querySelector('.selected') || $('dateGrid').querySelector('button')).focus();
};
for(const [id,offset] of [['previousMonth',-1],['nextMonth',1]]) $(id).onclick=()=>{displayedMonth.setMonth(displayedMonth.getMonth()+offset);renderMonth();};
document.addEventListener('click',event=>{if(!event.target.closest('.dateField')) closeDates();});
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!$('datePanel').hidden){closeDates();$('chooseDate').focus();}});
$('dayDate').onchange=renderDay;$('previousDay').onclick=()=>{const [s]=dayBounds();const d=new Date(s);d.setDate(d.getDate()-1);setDay(d);};$('nextDay').onclick=()=>{const [s]=dayBounds();const d=new Date(s);d.setDate(d.getDate()+1);setDay(d);};$('today').onclick=()=>setDay(new Date());
function timelineMinute(event){
  const rect=$('timeline').getBoundingClientRect(), [start,end]=dayBounds();
  const minutes=(end-start)/60000;
  return Math.max(0,Math.min(minutes,Math.round((event.clientY-rect.top)/rect.height*minutes/5)*5));
}
function clockTime(timestamp) {
  return new Date(timestamp).toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit',hour12:false});
}
function drawTimelineDraft() {
  $('timeline').querySelector('.draftblock')?.remove();
  if(!timelineDrag) return;
  const [dayStart,dayEnd]=dayBounds(), minutes=(dayEnd-dayStart)/60000;
  const top=Math.min(timelineDrag.start,timelineDrag.end), bottom=Math.max(timelineDrag.start,timelineDrag.end);
  const block=el('div',clockTime(dayStart+top*60000)+'–'+clockTime(dayStart+bottom*60000),'draftblock');
  block.style.top=(top/minutes*100)+'%'; block.style.height=(Math.max(5,bottom-top)/minutes*100)+'%';
  $('timeline').append(block);
}
$('timeline').onpointerdown=e=>{if(e.target.closest('.timeblock'))return;timelineDrag={pointer:e.pointerId,start:timelineMinute(e),end:timelineMinute(e)};$('timeline').setPointerCapture(e.pointerId);drawTimelineDraft();};
$('timeline').onpointermove=e=>{if(!timelineDrag||timelineDrag.pointer!==e.pointerId)return;timelineDrag.end=timelineMinute(e);drawTimelineDraft();};
$('timeline').onpointerup=e=>{
  if(!timelineDrag || timelineDrag.pointer!==e.pointerId) return;
  const first=timelineDrag.start,last=timelineMinute(e);
  timelineDrag=null; drawTimelineDraft();
  if(Math.abs(last-first)<5) return;
  const [dayStart]=dayBounds();
  const start=dayStart+Math.min(first,last)*60000,end=dayStart+Math.max(first,last)*60000;
  if(end>Date.now()){notify('Select an interval that has already ended.');return;}
  openEditor(null,{start,end});
};
$('timeline').onpointercancel=()=>{timelineDrag=null;drawTimelineDraft();};
function setManualMode(value){manualMode=value;$('manualMode').checked=value;if(value&&!$('manualMinutes').value)$('manualMinutes').value='30';render();}
$('manualMode').onchange=()=>setManualMode($('manualMode').checked);
openDatabase();
