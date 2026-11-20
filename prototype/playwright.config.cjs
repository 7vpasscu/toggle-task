const {defineConfig}=require('@playwright/test');
module.exports=defineConfig({testDir:'.',testMatch:'browser.test.cjs',workers:1,use:{baseURL:'http://127.0.0.1:4173',channel:process.platform==='win32'?'msedge':undefined,viewport:{width:1280,height:1000}},webServer:{command:'node server.cjs',url:'http://127.0.0.1:4173',reuseExistingServer:true}});
