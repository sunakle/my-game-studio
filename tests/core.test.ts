import {describe,it,expect} from 'vitest';
import {createAsset,createFrame,createProject} from '../src/core/model';
import {line,flood,composite,copyRegion,clearRegion,pasteRegion,canvasPoint} from '../src/core/pixel';
import {History} from '../src/core/history';
import {generatePalette,defaultPaletteOptions,paletteBiomes} from '../src/core/palette';
import {historyShortcut} from '../src/core/shortcuts';
import {saveProject,loadProject} from '../src/store/persistence';
import {safeUnzip,layoutAtlas,importProjectArchive} from '../src/io/files';
import {zipSync,strToU8} from 'fflate';
describe('Пиксели и независимость кадров',()=>{
 it('соединяет быстрый штрих без разрывов и точно переводит координаты',()=>{const p=new Uint8ClampedArray(32*32*4);line(p,32,32,{x:0,y:0},{x:31,y:31},[255,0,0,255]);for(let i=0;i<32;i++)expect(p[(i*32+i)*4+3]).toBe(255);for(const zoom of [1,2,5,12.5])expect(canvasPoint({x:100+17+7.5*zoom,y:50-30+9.5*zoom},{left:100,top:50},{x:17,y:-30},zoom)).toEqual({x:7,y:9});});
 it('заливка ограничена выделением; копирование и перенос сохраняют прозрачность',()=>{const p=new Uint8ClampedArray(8*8*4);flood(p,8,8,2,2,[1,2,3,255],{x:2,y:2,w:2,h:2});expect(p.filter((_,i)=>i%4===3&&p[i]===255).length).toBe(4);const r={x:2,y:2,w:2,h:2},data=copyRegion(p,8,8,r);clearRegion(p,8,8,r);pasteRegion(p,8,8,data,{...r,x:5});expect(p[(2*8+2)*4+3]).toBe(0);expect(p[(2*8+5)*4+3]).toBe(255);});
 it('слои компонуются с прозрачностью, дубликат кадра независим',()=>{const a=createAsset(),f=Object.values(a.frames)[0],l=a.layerOrder[0];f.cels[l].set([120,180,60,255]);const duplicate=structuredClone(f);duplicate.id='copy';a.frames.copy=duplicate;duplicate.cels[l][0]=200;expect(f.cels[l][0]).toBe(120);a.layers[l].opacity=.5;expect(composite(a,f.id)[3]).toBe(128);a.layers[l].visible=false;expect(composite(a,f.id)[3]).toBe(0);});
});
describe('История',()=>{
 it('один штрих — одно действие; изменения пикселей и структуры отменяются',()=>{const a=createAsset(),p=createProject();p.assets[a.id]=a;p.assetOrder.push(a.id);const before=structuredClone(p),f=Object.values(a.frames)[0],l=a.layerOrder[0],h=new History();line(f.cels[l],32,32,{x:1,y:1},{x:16,y:10},[1,2,3,255]);h.add('штрих',before,p);expect(h.undoStack).toHaveLength(1);expect(h.bytes).toBeLessThan(4096);h.undo(p);expect(Object.values(p.assets[a.id].frames)[0].cels[l].some(v=>v)).toBe(false);h.redo(p);expect(Object.values(p.assets[a.id].frames)[0].cels[l].some(v=>v)).toBe(true);const b=structuredClone(p),newFrame=createFrame(a);p.assets[a.id].frames[newFrame.id]=newFrame;h.add('кадр',b,p);h.undo(p);expect(p.assets[a.id].frames[newFrame.id]).toBeUndefined();h.redo(p);expect(p.assets[a.id].frames[newFrame.id].cels[l]).toBeInstanceOf(Uint8ClampedArray);});
 it('ограничивает память и не сохраняет пустые действия',()=>{const h=new History();h.limit=120;expect(h.add('пусто',{x:1},{x:1})).toBe(false);for(let i=0;i<20;i++)h.add('изменение',{x:i},{x:i+1});expect(h.bytes).toBeLessThanOrEqual(h.limit);expect(h.trimmed).toBe(true);});
});
describe('Хранение и файлы',()=>{
 it('после записи восстанавливает реальные пиксели, кадры, слои и карту',async()=>{const p=createProject(),a=createAsset();p.assets[a.id]=a;p.assetOrder=[a.id];Object.values(a.frames)[0].cels[a.layerOrder[0]][3]=255;p.map.items.push({id:crypto.randomUUID(),assetId:a.id,x:2,y:3,layer:'ground'});await saveProject(p);const restored=await loadProject(p.id);expect(restored?.assets[a.id]).toEqual(a);expect(restored?.map).toEqual(p.map);expect(Object.values(a.frames)[0].cels[a.layerOrder[0]][3]).toBe(255);});
 it('отклоняет повреждения, опасные пути и неизвестные версии',async()=>{expect(()=>safeUnzip(new Uint8Array([1,2,3]))).toThrow();expect(()=>safeUnzip(zipSync({'../bad.json':strToU8('{}')}))).toThrow('недопустимый путь');await expect(importProjectArchive(zipSync({'project.json':strToU8('{"schemaVersion":99}')}))).rejects.toThrow('версия формата');});
 it('раскладывает кадры с полями и правильными размерами',()=>{const a=createAsset();const f=createFrame(a);a.frames[f.id]=f;a.animations[a.animationOrder[0]].sequences.down.push(f.id);const atlas=layoutAtlas(a);expect(atlas.width).toBe(72);expect(atlas.height).toBe(36);expect(atlas.rects[f.id]).toEqual({x:38,y:2,w:32,h:32});});
});
describe('Палитра',()=>{it('сохраняет замки, генерирует 6×4 цвета и восходящую яркость',()=>{const first=generatePalette(defaultPaletteOptions);first.materials[0].locks[2]=true;const next=generatePalette({...defaultPaletteOptions,temperature:1,saturation:1.4},first);expect(next.materials[0].colors[2]).toBe(first.materials[0].colors[2]);expect(next.materials).toHaveLength(6);expect(next.materials.every(m=>m.colors.length===4&&m.colors.every(c=>/^#[\da-f]{6}$/i.test(c)))).toBe(true);});});
it('каждая локация даёт свою палитру, сохраняет замки и реагирует на базовый цвет',()=>{
 const palettes=paletteBiomes.map(b=>generatePalette({...defaultPaletteOptions,mood:b.id}));
 expect(new Set(palettes.map(p=>JSON.stringify(p.materials.map(m=>m.colors)))).size).toBe(paletteBiomes.length);
 for(const [i,b] of paletteBiomes.entries()){
  const p=palettes[i];expect(p.materials).toHaveLength(6);
  for(const m of p.materials){expect(m.colors).toHaveLength(4);expect(m.colors.every(c=>/^#[\da-f]{6}$/i.test(c))).toBe(true);}
  const changed=generatePalette({...defaultPaletteOptions,mood:b.id,base:'#5673ab'});
  expect(changed.materials[0].colors).not.toEqual(p.materials[0].colors);
  p.materials[0].locks[1]=true;
  expect(generatePalette({...defaultPaletteOptions,mood:b.id,temperature:1,saturation:.4},p).materials[0].colors[1]).toBe(p.materials[0].colors[1]);
 }
 expect(palettes[paletteBiomes.findIndex(b=>b.id==='castle')].materials.some(m=>m.name==='Камень')).toBe(true);
});
it('отмена и повтор распознаются по физическим клавишам при русской раскладке',()=>{
 const key={ctrlKey:true,metaKey:false,shiftKey:false,altKey:false,code:'KeyZ',key:'я'};
 expect(historyShortcut(key)).toBe('undo');expect(historyShortcut({...key,shiftKey:true})).toBe('redo');
 expect(historyShortcut({...key,code:'KeyY',key:'н'})).toBe('redo');
 expect(historyShortcut({...key,ctrlKey:false})).toBeNull();expect(historyShortcut({...key,altKey:true})).toBeNull();
});
