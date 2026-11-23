const {defineConfig}=require('@playwright/test');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
// Isolate integration tests from the user's running preview and its database.
process.env.TASK_TRACK_TEST_DIR ||= fs.mkdtempSync(path.join(os.tmpdir(),'task-track-browser-'));
module.exports=defineConfig({testDir:'.',testMatch:'browser.test.cjs',workers:1,
 use:{baseURL:'http://127.0.0.1:4187',channel:process.platform==='win32'?'msedge':undefined,viewport:{width:1280,height:1000}},
 webServer:{command:'node server.cjs',url:'http://127.0.0.1:4187',reuseExistingServer:false,
 env:{TASK_TRACK_PORT:'4187',TASK_TRACK_DATA_DIR:process.env.TASK_TRACK_TEST_DIR,TASK_TRACK_NOTION_TOKEN:'',TASK_TRACK_NOTION_SOURCE:''}}});

