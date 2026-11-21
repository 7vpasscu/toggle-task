(function(root){
'use strict';
const defaultTypes=['Visuals','Final artwork','Proposals'];
const id=()=>globalThis.crypto.randomUUID();
function seed(now=Date.now()){return {version:3,revision:0,userId:'demo-user',users:[{id:'demo-user',name:'Demo profile'}],projects:[{id:'demo-p1',name:'Spring campaign',client:'Studio North',brand:'Fern Studio',historicalMinutes:120,archived:false},{id:'demo-p2',name:'Collection packaging',client:'Field Goods',brand:'Field Goods',historicalMinutes:60,archived:false}],workTypes:[...defaultTypes],sessions:[{id:'sample',projectId:'demo-p1',userId:'demo-user',description:'Visual exploration',workType:'Visuals',units:2,start:now-7200000,end:now-5400000}],active:null};}
function workTypes(state){return Array.isArray(state.workTypes)&&state.workTypes.length?state.workTypes:defaultTypes;}
function cleanName(value){return String(value??'').trim().replace(/\s+/g,' ');}
function addWorkType(state,name){name=cleanName(name);if(!name||name.length>80)throw Error('Enter a work type with up to 80 characters.');const found=workTypes(state).find(t=>t.localeCompare(name,undefined,{sensitivity:'accent'})===0);if(found)return found;state.workTypes=[...workTypes(state),name];return name;}
function validate(s,state,now=Date.now()){if(!state.projects.some(p=>p.id===s.projectId))throw Error('Choose a valid project.');if(!state.users.some(u=>u.id===s.userId))throw Error('Unknown profile.');if(!Number.isFinite(s.start)||!Number.isFinite(s.end)||s.end<=s.start)throw Error('End time must be after start time.');if(s.end>now+1000)throw Error('Choose an end time in the past.');if(!Number.isInteger(s.units)||s.units<0||s.units>100000)throw Error('Enter a whole number from 0 to 100000 for units.');if(!workTypes(state).includes(s.workType))throw Error('Choose a valid work type.');if(typeof s.description!=='string'||s.description.length>500)throw Error('Use up to 500 characters.');return s;}
function start(state,draft,now=Date.now()){if(state.active)throw Error('A timer is already running.');const p=state.projects.find(p=>p.id===draft.projectId);if(!p||p.archived)throw Error('Choose an active project.');if(!Number.isInteger(draft.units)||draft.units<0||draft.units>100000)throw Error('Check the number of units.');if(!workTypes(state).includes(draft.workType))throw Error('Select an existing work type or create one.');state.active={...draft,id:id(),userId:state.userId,start:now};return state.active;}
function own(state,s){if(!state.users.some(u=>u.id===state.userId)||!s||s.userId!==state.userId)throw Error('This session belongs to another profile.');return s;}
function mine(state){return state.users.some(u=>u.id===state.userId)?state.sessions.filter(s=>s.userId===state.userId):[];}
function logicalID(s){return s.continuationOf||s.id;}
function rootFor(state,s){const root=state.sessions.find(x=>x.id===logicalID(s)&&x.userId===s.userId);return root||s;}
function stop(state,now=Date.now()){if(!state.active)return null;own(state,state.active);const s={...state.active,end:Math.max(now,state.active.start+1)};validate(s,state,now);state.sessions.unshift(s);state.active=null;return s;}
function upsert(state,s,now=Date.now()){own(state,s);const existing=state.sessions.find(x=>x.id===s.id);if(existing)own(state,existing);validate(s,state,now);const i=state.sessions.findIndex(x=>x.id===s.id);if(i<0)state.sessions.unshift(s);else state.sessions[i]=s;}
function remove(state,id){const target=own(state,state.sessions.find(s=>s.id===id));const logical=logicalID(target);state.sessions=state.sessions.filter(s=>s.userId!==state.userId||logicalID(s)!==logical);}
function daily(state,start,end){return mine(state).filter(s=>dayOverlap(s,start,end)>0).sort((a,b)=>a.start-b.start);}
function personalBackup(state){return {...state,users:state.users.filter(u=>u.id===state.userId),sessions:mine(state),active:state.active?.userId===state.userId?state.active:null};}
function dayOverlap(s,start,end){return Math.max(0,Math.min(s.end,end)-Math.max(s.start,start));}
function seconds(s){return Math.max(0,Math.floor((s.end-s.start)/1000));}
function minutes(seconds){return Math.max(0,Math.round(seconds/60));}
function format(seconds){const total=minutes(seconds);return [Math.floor(total/60),total%60].map(v=>String(v).padStart(2,'0')).join(':');}
function parseMinutes(raw) {
  const input = String(raw ?? '').trim();
  if (/^\d{1,2}$/.test(input)) return Number(input) || null;
  const match = /^(\d{1,4}):?([0-5]\d)$/.exec(input);
  if (!match) return null;
  const minutes = Number(match[1])*60 + Number(match[2]);
  return minutes > 0 && minutes <= 100000 ? minutes : null;
}
function csv(rows){const safe=v=>{let t=String(v??'');if(/^[=+@\-\t\r]/.test(t))t="'"+t;return '"'+t.replaceAll('"','""')+'"';};return '\uFEFF'+rows.map(r=>r.map(safe).join(',')).join('\r\n');}
const api={seed,validate,start,stop,upsert,remove,own,mine,daily,personalBackup,dayOverlap,seconds,minutes,format,parseMinutes,logicalID,rootFor,addWorkType,csv,id,types:defaultTypes};if(typeof module!=='undefined')module.exports=api;else root.Tracker=api;
})(globalThis);
