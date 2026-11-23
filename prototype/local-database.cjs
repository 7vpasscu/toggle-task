const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const codec=require('../macos/ToggleTask/Sources/ToggleTask/Resources/task-track-csv.js');
const base=process.env.LOCALAPPDATA || (process.platform==='darwin'?path.join(os.homedir(),'Library','Application Support'):(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local','share')));
const directory=process.env.TASK_TRACK_DATA_DIR||path.join(base,'TaskTrack','Preview');
const file=path.join(directory,'task-track.csv');
const fingerprint=text=>crypto.createHash('sha256').update(text).digest('hex');
function read(){
  let text;
  try{text=fs.readFileSync(file,'utf8');}catch(e){if(e.code==='ENOENT')return {state:null,tag:null,file};throw e;}
  return {state:codec.decode(text),tag:fingerprint(text),file};
}
function write(state,expected){
  // Local server is the sole writer. Check and replace synchronously to serialize tabs.
  const before=read();
  if(before.tag!==expected)throw Object.assign(Error('The CSV changed. Reload before saving.'),{status:409});
  const text=codec.encode(state);codec.decode(text);
  fs.mkdirSync(directory,{recursive:true,mode:0o700});
  const temp=file+'.'+crypto.randomUUID()+'.tmp';
  try{
    fs.writeFileSync(temp,text,{encoding:'utf8',mode:0o600,flag:'wx'});
    fs.renameSync(temp,file);
  }finally{fs.rmSync(temp,{force:true});}
  return {tag:fingerprint(text),file};
}
module.exports={read,write,codec};
