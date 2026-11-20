const {test,expect}=require('@playwright/test');
const C=require('./core.js');
test.beforeEach(async({page})=>{
 const now=Date.now(),state=C.seed(now);state.users.push({id:'other',name:'Demo profile'});
 state.sessions[0].description='My entry';
 state.sessions.push({...state.sessions[0],id:'secret',userId:'other',description:'Other worker entry'});
 await page.addInitScript(s=>{if(!localStorage.getItem('toggle-task.v1'))localStorage.setItem('toggle-task.v1',JSON.stringify(s));},state);
 await page.goto('/');
});
test('list and calendar isolate accounts, including equal display names',async({page})=>{
 await expect(page.locator('#sessions')).toContainText('My entry');
 await expect(page.locator('#sessions')).not.toContainText('Other worker entry');
 await page.getByRole('button',{name:'Calendar',exact:true}).click();
 const date=await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('toggle-task.v1')).sessions[0];const d=new Date(s.start);return new Date(d-d.getTimezoneOffset()*60000).toISOString().slice(0,10);});
 await page.locator('#dayDate').evaluate((el,date)=>{el.value=date;el.dispatchEvent(new Event('change'));},date);
 await expect(page.locator('#timeline')).toContainText('My entry');
 await expect(page.locator('#timeline')).not.toContainText('Other worker entry');
 await page.locator('#moreButton').click();await page.locator('#user').selectOption('other');
 await expect(page.locator('#timeline')).toContainText('Other worker entry');
 await expect(page.locator('#timeline')).not.toContainText('My entry');
 await page.getByRole('button',{name:'List',exact:true}).click();
 await expect(page.locator('#sessions')).not.toContainText('My entry');
});
test('Ctrl+D toggles manual mode and preserves a running timer',async({page})=>{
 await page.locator('#description').fill('Running timer');await page.locator('#toggle').click();
 const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('toggle-task.v1')).active.id);
 await page.keyboard.press('Control+d');await expect(page.locator('#manualDurationWrap')).toBeVisible();
 await page.keyboard.press('Control+d');await expect(page.locator('#manualDurationWrap')).toBeHidden();
 await page.reload();await expect(page.locator('#toggle')).toHaveAttribute('aria-label','Stop timer');
 await page.locator('#toggle').click();
 expect(await page.evaluate(id=>JSON.parse(localStorage.getItem('toggle-task.v1')).sessions.filter(s=>s.id===id).length,before)).toBe(1);
});
test('manual entry and duration editor save without duplication',async({page})=>{
 await page.keyboard.press('Control+d');await page.locator('#description').fill('Manual entry'); await page.locator('#manualMinutes').fill('26');
 await page.locator('#toggle').click();await expect(page.locator('#sessions')).toContainText('Manual entry');
 await page.getByRole('button',{name:'Edit Manual entry',exact:true}).click();
 await page.locator('#editStart').fill('2020-05-10'); await page.locator('#editDuration').fill('126');await page.locator('#editDuration').press('Tab');
 await page.getByRole('button',{name:'Save session',exact:true}).click();
 await expect(page.locator('#editor')).not.toBeVisible();
 const entries=await page.evaluate(()=>JSON.parse(localStorage.getItem('toggle-task.v1')).sessions.filter(s=>s.description==='Manual entry'));
 expect(entries).toHaveLength(1);expect((entries[0].end-entries[0].start)/1000).toBe(5160);
});
test('dark/light compact layouts and editor render without horizontal overflow',async({page})=>{
 await page.screenshot({path:'test-results/task-track-dark.png',fullPage:true});
 await page.getByRole('button',{name:'Edit My entry',exact:true}).click();
 await page.screenshot({path:'test-results/task-track-editor.png',fullPage:true});await page.locator('#cancelEdit').click();
 await page.locator('#moreButton').click();await page.getByRole('button',{name:'Settings',exact:true}).click();await page.locator('#theme').selectOption('light'); await page.locator('#moreButton').click(); await page.locator('#backToTracking').click();
 await page.getByRole('button',{name:'List',exact:true}).click();
 await page.screenshot({path:'test-results/task-track-light.png',fullPage:true});
 await page.setViewportSize({width:420,height:850});await page.screenshot({path:'test-results/task-track-compact.png',fullPage:true});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('editable project, type and units share one row and follow keyboard order', async ({page}) => {
  for(const manual of [false,true]){
    await page.locator('#manualMode').setChecked(manual);
    const project=page.locator('#project'), type=page.locator('#workType'), units=page.locator('#units');
    await project.focus();
    await expect(page.getByRole('option',{name:'Spring campaign',exact:true})).toBeVisible();
    await project.fill('ring');
    await expect(page.locator('#projectList [role=option]').first()).toHaveText('Spring campaign');
    await project.press('Enter'); await project.press('Tab'); await expect(type).toBeFocused();
    await type.fill('art'); await type.press('Enter'); await expect(type).toHaveValue('Final artwork');
    await type.press('Tab'); await expect(units).toBeFocused();
    await expect(units).toHaveAttribute('type','text');
    const boxes=await Promise.all([project,type,units].map(input=>input.boundingBox()));
    expect(Math.max(...boxes.map(b=>b.y))-Math.min(...boxes.map(b=>b.y))).toBeLessThan(2);
  }
  await page.locator('#workType').fill('Lettering');
  await page.getByRole('option',{name:'+ Create type “Lettering”'}).click();
  await page.reload(); await page.locator('#workType').fill('eTTe');
  await expect(page.getByRole('option',{name:'Lettering',exact:true})).toBeVisible();
  await page.locator('#workType').fill(' lettering ');
  await expect(page.locator('#workTypeList')).not.toContainText('Create');
});
test('connected type picker reads and extends the catalog', async ({page})=>{
  let options=[{name:'Artes finales',color:'orange'},{name:'Rendering',color:'blue'}];
  let creations=0;
  await page.route('**/api/work-types',route=>{
    if(route.request().method()==='POST'){
      creations++; options.push({name:route.request().postDataJSON().name,color:'default'});
    }
    return route.fulfill({json:{connected:true,options}});
  });
  await page.reload();
  await expect(page.locator('#catalogStatus')).toContainText('Work types connected');
  await page.locator('#workType').focus();
  await expect(page.locator('#workTypeList')).toContainText('Rendering');
  await expect(page.locator('#workTypeList')).not.toContainText('Proposals');
  await page.locator('#workType').fill('Motion studies');
  await page.getByRole('option',{name:'+ Create type “Motion studies”'}).click();
  await expect(page.locator('#workType')).toHaveValue('Motion studies');
  await expect.poll(()=>creations).toBe(1);
  await page.reload();
  await page.locator('#workType').fill('stud');
  await expect(page.getByRole('option',{name:'Motion studies',exact:true})).toBeVisible();
});
test('calendar drag proposes a session, and resuming a task keeps one list row per day',async({page})=>{
  await page.getByRole('button',{name:'Calendar',exact:true}).click();
  await page.locator('#previousDay').click();
  const box=await page.locator('#timelineScroll').boundingBox();
  await page.mouse.move(box.x+40,box.y+25); await page.mouse.down();
  await page.mouse.move(box.x+40,box.y+55,{steps:5}); await page.mouse.up();
  await expect(page.locator('#editor')).toBeVisible(); await expect(page.locator('#editDuration')).toHaveValue('00:30');
  await page.locator('#cancelEdit').click();
  await page.getByRole('button',{name:'List',exact:true}).click();
  await page.keyboard.press('Control+d'); await page.locator('#description').fill('Resume test');
  await page.locator('#manualMinutes').fill('10');await page.locator('#toggle').click();
  await page.getByRole('button',{name:'Resume Resume test',exact:true}).click();
  await expect(page.locator('#toggle')).toHaveAttribute('aria-label','Stop timer');await page.locator('#toggle').click();
  await expect(page.getByRole('button',{name:'Edit Resume test',exact:true})).toHaveCount(1);
});
test('Reports opens on the calendar day and clips time to the chosen range',async({page})=>{
  const anchor=await page.evaluate(()=>{
    const state=JSON.parse(localStorage.getItem('toggle-task.v1'));
    const day=new Date();day.setDate(day.getDate()-10);day.setHours(0,0,0,0);
    const start=+day-30*60000,end=+day+15*60000;
    const seed=state.sessions[0];
    state.sessions=[{...seed,start,end},{...seed,id:'hidden',userId:'other',start,end}];
    localStorage.setItem('toggle-task.v1',JSON.stringify(state));
    return day.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
  });
  await page.reload();
  await page.getByRole('button',{name:'Calendar',exact:true}).click();
  for(let i=0;i<10;i++) await page.locator('#previousDay').click();
  await page.locator('#moreButton').click();
  await expect(page.locator('#moreNav')).not.toContainText('Daily summary');
  await page.getByRole('button',{name:'Reports',exact:true}).click();
  await expect(page.locator('#reportRange')).toHaveText(anchor);
  await expect(page.locator('#reports h1')).toHaveText('00:15');
  await page.locator('#reportPeriod').selectOption('custom');
  await page.locator('#customDays').fill('2');
  await expect(page.locator('#reports h1')).toHaveText('00:45');
  await page.locator('#moreButton').click();await page.locator('#backToTracking').click();
  await page.locator('#moreButton').click();await page.getByRole('button',{name:'Reports',exact:true}).click();
  await expect(page.locator('#reports h1')).toHaveText('00:15');
});
