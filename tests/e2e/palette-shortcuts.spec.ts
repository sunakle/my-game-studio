import {test,expect,type Page} from '@playwright/test';

async function paintedPixels(page:Page){
 await page.getByRole('button',{name:'Сохранить',exact:true}).click();
 await expect(page.getByText('Сохранено на устройстве',{exact:true})).toBeVisible();
 return page.evaluate(async()=>{const db=await new Promise<IDBDatabase>((resolve,reject)=>{const r=indexedDB.open('my-game-studio',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});const cels=await new Promise<Uint8ClampedArray[]>((resolve,reject)=>{const r=db.transaction('cels').objectStore('cels').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});db.close();return cels.reduce((sum,cel)=>sum+Array.from(cel).filter((v,i)=>i%4===3&&v>0).length,0);});
}

test('локации, отсутствие демонстрационной сцены, глобальная отмена и русский Ctrl+Z',async({page})=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/');
 await page.getByRole('button',{name:'Создать первый холст'}).click();await page.getByRole('button',{name:'Создать холст',exact:true}).click();
 await page.getByRole('button',{name:'Масштаб 1:1',exact:true}).click();const box=(await page.getByLabel('Холст для рисования').boundingBox())!;
 await page.mouse.click(box.x+Math.floor((box.width-32)/2)+7.5,box.y+Math.floor((box.height-32)/2)+9.5);
 expect(await paintedPixels(page)).toBe(1);
 // Save moves focus to the app header, outside the editor.
 await page.keyboard.press('Control+z');expect(await paintedPixels(page)).toBe(0);
 await page.keyboard.press('Control+Shift+z');expect(await paintedPixels(page)).toBe(1);
 await page.keyboard.press('Control+z');expect(await paintedPixels(page)).toBe(0);
 await page.keyboard.press('Control+y');expect(await paintedPixels(page)).toBe(1);
 // The non-text color input must not swallow drawing undo.
 await page.getByLabel('Цвет кисти').focus();
 await page.getByLabel('Цвет кисти').dispatchEvent('keydown',{key:'я',code:'KeyZ',ctrlKey:true,bubbles:true,cancelable:true});
 expect(await paintedPixels(page)).toBe(0);await page.keyboard.press('Control+y');expect(await paintedPixels(page)).toBe(1);
 const input=page.getByLabel('Название слоя');await input.click();await page.keyboard.press('End');await page.keyboard.type(' тест');await page.keyboard.press('Control+z');
 expect(await paintedPixels(page)).toBe(1);
 await page.getByRole('button',{name:'Палитры',exact:true}).click();const biomes=page.getByLabel('Биом / локация');
 await expect(biomes.locator('option')).toHaveCount(23);await expect(biomes.locator('optgroup')).toHaveCount(4);
 await biomes.selectOption('castle');await expect(page.locator('.palette-material').filter({hasText:'Металл'})).toBeVisible();
 const castle=await page.locator('.palette-material input[type=color]').evaluateAll(nodes=>nodes.map(n=>(n as HTMLInputElement).value));
 await biomes.selectOption('kremlin');await expect(page.locator('.palette-material').filter({hasText:'Кирпич'})).toBeVisible();
 const kremlin=await page.locator('.palette-material input[type=color]').evaluateAll(nodes=>nodes.map(n=>(n as HTMLInputElement).value));expect(kremlin).not.toEqual(castle);
 await expect(page.locator('.palette-layout canvas')).toHaveCount(0);await expect(page.getByText('Небольшая сцена · предпросмотр палитры')).toHaveCount(0);
 await page.getByRole('button',{name:'Сохранить вариант',exact:true}).click();await expect(page.getByRole('status')).toContainText('палитры сохранён');
 await page.screenshot({path:'test-results/palette-update.png'});expect(errors).toEqual([]);
});
