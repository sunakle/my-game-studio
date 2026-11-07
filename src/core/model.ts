export type Point={x:number;y:number};
export type Rect=Point & {w:number;h:number};
export type Direction='down'|'left'|'right'|'up';
export const directions:Direction[]=['down','left','right','up'];
export const directionNames:Record<Direction,string>={down:'Вниз',left:'Влево',right:'Вправо',up:'Вверх'};
export type Layer={id:string;name:string;visible:boolean;locked:boolean;opacity:number};
export type Frame={id:string;durationMs:number;cels:Record<string,Uint8ClampedArray>;pivotOffset:Point;events:{id:string;name:string;offsetMs:number}[]};
export type Animation={id:string;name:string;speed:number;loop:boolean;sequences:Record<Direction,string[]>};
export type Asset={id:string;name:string;kind:'tile'|'object'|'character'|'effect';technique:'pixel'|'painted'|'vector';origin:'own'|'demo'|'imported';width:number;height:number;layers:Record<string,Layer>;layerOrder:string[];frames:Record<string,Frame>;animations:Record<string,Animation>;animationOrder:string[];pivot:Point;collision:Rect|null;paletteId:string;paletteVersion:number;selection:Rect|null;notes:string};
export type Material={id:string;name:string;colors:string[];locks:boolean[]};
export type Palette={id:string;name:string;version:number;materials:Material[]};
export const taskStatuses=['Запланировано','Рисую','Проверка','Готово','Экспортировано','Проверено в Godot'] as const;
export type Task={id:string;name:string;purpose:string;priority:'Высокий'|'Средний'|'Низкий';width:number;height:number;palette:string;technique:string;variants:number;frames:number;pivot:string;seams:string;collision:string;dependencies:string[];criteria:string;status:typeof taskStatuses[number];assetId:string};
export type MapItem={id:string;assetId:string;x:number;y:number;layer:'ground'|'objects'};
export type Project={schemaVersion:1;id:string;name:string;createdAt:string;updatedAt:string;assets:Record<string,Asset>;assetOrder:string[];palettes:Record<string,Palette>;tasks:Task[];map:{width:number;height:number;items:MapItem[];background:string};style:{grid:number;characterWidth:number;characterHeight:number;light:string;cameraAngle:number;pixelsPerUnit:number;confirmed:boolean};workspace:{grid:boolean;onion:boolean;panels:boolean;zoom:number;views:Record<string,{zoom:number;x:number;y:number}>}};
export const uid=()=>crypto.randomUUID();
export function createFrame(asset:Pick<Asset,'width'|'height'|'layerOrder'>):Frame{return {id:uid(),durationMs:125,cels:Object.fromEntries(asset.layerOrder.map(id=>[id,new Uint8ClampedArray(asset.width*asset.height*4)])),pivotOffset:{x:0,y:0},events:[]};}
export function createAsset(name='Новый спрайт',width=32,height=32):Asset{
 const layer:Layer={id:uid(),name:'Основной слой',visible:true,locked:false,opacity:1};
 const a:Asset={id:uid(),name,kind:'tile',technique:'pixel',origin:'own',width,height,layers:{[layer.id]:layer},layerOrder:[layer.id],frames:{},animations:{},animationOrder:[],pivot:{x:width/2,y:height},collision:null,paletteId:'',paletteVersion:0,selection:null,notes:''};
 const frame=createFrame(a);a.frames[frame.id]=frame;
 const animation:Animation={id:uid(),name:'idle',speed:1,loop:true,sequences:{down:[frame.id],left:[],right:[],up:[]}};
 a.animations[animation.id]=animation;a.animationOrder=[animation.id];return a;
}
export function forestTasks():Task[]{const specs:[string,string,number,number,string,string,string[]][]=[
 ['Трава','Базовая поверхность леса',32,32,'Не ставьте крупные пятна у одинаковых краёв. Проверьте 3×3 и 5×5.','Края бесшовны; три варианта без заметной сетки.',[]],
 ['Грунтовая дорожка','Направление движения по лесу',32,32,'Согласуйте края с травой. Начните с основного материала.','Прямая, внешние и внутренние углы, окончание.',['Трава']],
 ['Переходы','Стыки травы и дорожки',32,32,'Проверьте соседние границы и каждый угол.','Базовый явно описанный набор переходов.',['Трава','Грунтовая дорожка']],
 ['Дерево','Вертикальная доминанта',64,96,'Разделите крону и ствол. Опора — контакт ствола с землёй.','Читаемый силуэт; масштаб рядом с персонажем; контактная тень.',['Персонаж']],
 ['Куст','Низкая растительность',32,32,'Не перегружайте мелкими деталями.','Два силуэта; различимость на траве.',['Трава']],
 ['Камни','Малый и большой камень',32,32,'Одинаковое направление света.','Два размера, различимые силуэты.',['Трава']],
 ['Вода','Небольшой лесной водоём',32,32,'Спокойный рисунок; проверьте скачок в петле.','Четыре кадра с одинаковой фазой на стыках.',[]],
 ['Берег','Граница воды и суши',32,32,'Согласуйте края с водой и землёй.','Прямой берег и углы.',['Вода','Трава']],
 ['Руины','Фрагмент старой постройки',64,64,'Согласуйте камень и перспективу.','Стена, проход и читаемая коллизия.',['Камни']],
 ['Персонаж','Эталон масштаба',32,48,'Одинаковое положение стоп во всех кадрах.','idle и walk в четырёх направлениях.',[]]];
 return specs.map(([name,purpose,width,height,seams,criteria,dependencies])=>({id:uid(),name,purpose,priority:['Трава','Персонаж'].includes(name)?'Высокий':'Средний',width,height,palette:name==='Вода'?'Вода':'Лесная палитра',technique:'Пиксельная графика',variants:name==='Трава'?3:1,frames:name==='Вода'?4:name==='Персонаж'?4:1,pivot:'Снизу по центру',seams,collision:['Дерево','Камни','Руины'].includes(name)?'Прямоугольник у основания':'Нет',dependencies,criteria,status:'Запланировано',assetId:''}));
}
export function createProject(name='Лесная мастерская'):Project{const now=new Date().toISOString();return {schemaVersion:1,id:uid(),name,createdAt:now,updatedAt:now,assets:{},assetOrder:[],palettes:{},tasks:forestTasks(),map:{width:16,height:12,items:[],background:'#313c31'},style:{grid:32,characterWidth:32,characterHeight:48,light:'Сверху слева',cameraAngle:45,pixelsPerUnit:32,confirmed:false},workspace:{grid:true,onion:false,panels:true,zoom:10,views:{}}};}
export function validateDimensions(w:number,h:number){if(!Number.isInteger(w)||!Number.isInteger(h)||w<1||h<1||w>1024||h>1024)throw new Error('Размер холста — от 1 до 1024 пикселей по каждой стороне.');}
export const allFrameIds=(a:Asset)=>[...new Set(a.animationOrder.flatMap(id=>directions.flatMap(d=>a.animations[id].sequences[d])))];
