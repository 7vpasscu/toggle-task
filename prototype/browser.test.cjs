const {test,expect}=require('@playwright/test');
const C=require('./core.js');
test.beforeEach(async({page})=>{
 const now=Date.now(),state=C.seed(now);state.users.push({id:'other',name:'Perfil demo'});
 state.sessions[0].description='Solo de mi cuenta';
 state.sessions.push({...state.sessions[0],id:'secret',userId:'other',description:'Privado de otra cuenta'});
 await page.addInitScript(s=>{if(!localStorage.getItem('toggle-task.v1'))localStorage.setItem('toggle-task.v1',JSON.stringify(s));},state);
 await page.goto('/');
});
test('list and calendar isolate accounts, including equal display names',async({page})=>{
 await expect(page.locator('#sessions')).toContainText('Solo de mi cuenta');
 await expect(page.locator('#sessions')).not.toContainText('Privado de otra cuenta');
 await page.getByRole('button',{name:'Calendario',exact:true}).click();
 const date=await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('toggle-task.v1')).sessions[0];const d=new Date(s.start);return new Date(d-d.getTimezoneOffset()*60000).toISOString().slice(0,10);});
 await page.locator('#dayDate').fill(date);await page.locator('#dayDate').dispatchEvent('change');
 await expect.poll(()=>page.locator('#timelineScroll').evaluate(element=>element.scrollTop)).toBeGreaterThan(0);
 await expect(page.locator('#timeline')).toContainText('Solo de mi cuenta');
 await expect(page.locator('#timeline')).not.toContainText('Privado de otra cuenta');
 await page.locator('#moreButton').click();await page.locator('#user').selectOption('other');
 await expect(page.locator('#timeline')).toContainText('Privado de otra cuenta');
 await expect(page.locator('#timeline')).not.toContainText('Solo de mi cuenta');
 await page.getByRole('button',{name:'Lista',exact:true}).click();
 await expect(page.locator('#sessions')).not.toContainText('Solo de mi cuenta');
});
test('Ctrl+D toggles manual mode and preserves a running timer',async({page})=>{
 await page.locator('#description').fill('Temporizador conservado');await page.locator('#toggle').click();
 const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('toggle-task.v1')).active.id);
 await page.keyboard.press('Control+d');await expect(page.locator('#manualFields')).toBeVisible();
 await page.keyboard.press('Control+d');await expect(page.locator('#manualFields')).toBeHidden();
 await page.reload();await expect(page.locator('#toggle')).toHaveAttribute('aria-label','Parar temporizador');
 await page.locator('#toggle').click();
 expect(await page.evaluate(id=>JSON.parse(localStorage.getItem('toggle-task.v1')).sessions.filter(s=>s.id===id).length,before)).toBe(1);
});
test('manual entry and duration editor save without duplication',async({page})=>{
 await page.keyboard.press('Control+d');await page.locator('#description').fill('Trabajo manual');
 await page.locator('#toggle').click();await expect(page.locator('#sessions')).toContainText('Trabajo manual');
 await page.getByRole('button',{name:'Editar Trabajo manual',exact:true}).click();
 await page.locator('#editDuration').fill('00:10:00');await page.locator('#editDuration').press('Tab');
 await page.getByRole('button',{name:'Guardar sesión',exact:true}).click();
 await expect(page.locator('#editor')).not.toBeVisible();
 const entries=await page.evaluate(()=>JSON.parse(localStorage.getItem('toggle-task.v1')).sessions.filter(s=>s.description==='Trabajo manual'));
 expect(entries).toHaveLength(1);expect((entries[0].end-entries[0].start)/1000).toBe(600);
});
test('dark/light compact layouts and editor render without horizontal overflow',async({page})=>{
 await page.screenshot({path:'test-results/task-track-dark.png',fullPage:true});
 await page.getByRole('button',{name:'Editar Solo de mi cuenta',exact:true}).click();
 await page.screenshot({path:'test-results/task-track-editor.png',fullPage:true});await page.locator('#cancelEdit').click();
 await page.locator('#moreButton').click();await page.getByRole('button',{name:'Ajustes',exact:true}).click();await page.locator('#theme').selectOption('light');
 await page.getByRole('button',{name:'Lista',exact:true}).click();
 await page.screenshot({path:'test-results/task-track-light.png',fullPage:true});
 await page.setViewportSize({width:420,height:850});await page.screenshot({path:'test-results/task-track-compact.png',fullPage:true});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
