import {converter,clampChroma,formatHex} from 'culori';
import {uid,type Palette,type Material} from './model';

const oklch=converter('oklch');
const nature=['Трава','Листва','Кора','Земля','Камень','Вода'];
const architecture=['Мох','Зелень','Дерево','Грунт','Камень','Металл'];
type Biome={id:string;label:string;group:string;names?:string[];hues?:number[];chroma?:number[];lightness?:number[];saturation?:number;hueShift?:number};

// Each preset changes material colors. Original IDs stay compatible.
export const paletteBiomes=[
 {id:'forest',label:'Тихий лес',group:'Леса'},
 {id:'mist',label:'Лес в тумане',group:'Леса',saturation:.65,lightness:[.09,.07,.04,.04,.08,.06]},
 {id:'autumn',label:'Тёплая осень',group:'Леса',saturation:.85,hueShift:-52},
 {id:'birch',label:'Берёзовая роща',group:'Леса',hues:[125,105,85,72,235,218],lightness:[.06,.08,.18,.02,.03,.03]},
 {id:'pine',label:'Сосновый бор',group:'Леса',hues:[135,155,48,62,225,210],lightness:[-.03,-.05,-.02,0,0,-.02]},
 {id:'taiga',label:'Хвойная тайга',group:'Леса',hues:[155,165,55,85,245,230],saturation:.78,lightness:[-.06,-.08,-.03,-.03,-.02,-.04]},
 {id:'enchanted',label:'Сказочный лес',group:'Леса',hues:[155,185,315,280,270,220],chroma:[.11,.13,.06,.06,.05,.10]},
 {id:'meadow',label:'Луговое разнотравье',group:'Природные локации',names:['Трава','Цветы','Дерево','Земля','Камень','Вода'],hues:[115,340,65,78,230,225],chroma:[.12,.14,.04,.05,.025,.07],lightness:[.08,.07,.02,.04,.02,.04]},
 {id:'marsh',label:'Болото и камыши',group:'Природные локации',names:['Мох','Камыши','Коряги','Торф','Камень','Вода'],hues:[120,95,62,82,160,170],saturation:.7,lightness:[-.07,-.03,-.05,-.08,-.02,-.08]},
 {id:'lake',label:'Озёрный край',group:'Природные локации',hues:[140,150,62,82,235,235],chroma:[.09,.10,.035,.04,.03,.10],lightness:[.03,0,0,.04,.03,.06]},
 {id:'river',label:'Речная долина',group:'Природные локации',names:['Луг','Ивы','Дерево','Песок','Галька','Вода'],hues:[125,145,65,85,235,205],lightness:[.08,.03,0,.12,.05,.05]},
 {id:'winter',label:'Заснеженный лес',group:'Природные локации',names:['Снег','Хвоя','Кора','Мёрзлая земля','Камень','Лёд'],hues:[245,165,65,260,250,230],chroma:[.025,.055,.025,.025,.02,.045],lightness:[.18,-.04,-.01,.02,.08,.15]},
 {id:'mountains',label:'Горные скалы',group:'Природные локации',names:['Лишайник','Хвоя','Дерево','Грунт','Скалы','Вода'],hues:[105,155,58,75,255,215],saturation:.65,lightness:[-.02,-.05,-.03,-.02,.03,0]},
 {id:'castle',label:'Светлый каменный замок',group:'Замки и руины',names:architecture,hues:[125,140,62,75,88,235],chroma:[.065,.075,.04,.035,.025,.025],lightness:[.01,0,-.02,.02,.16,.05]},
 {id:'fortress',label:'Мрачная крепость',group:'Замки и руины',names:architecture,hues:[140,150,50,65,255,250],saturation:.5,lightness:[-.06,-.08,-.07,-.08,-.10,-.08]},
 {id:'ruins',label:'Заросшие руины',group:'Замки и руины',names:architecture,hues:[125,145,58,75,105,235],saturation:.75,lightness:[.01,0,-.05,-.01,.02,-.03]},
 {id:'dungeon',label:'Подземелье',group:'Замки и руины',names:['Мох','Плесень','Дерево','Пыль','Камень','Металл'],hues:[155,175,45,65,270,250],saturation:.45,lightness:[-.12,-.12,-.10,-.10,-.13,-.11]},
] as const satisfies readonly Biome[];

export type PaletteMood=typeof paletteBiomes[number]['id'];
export type PaletteOptions={base:string;mood:PaletteMood;saturation:number;contrast:number;temperature:number};
export const defaultPaletteOptions:PaletteOptions={base:'#6e9951',mood:'forest',saturation:1,contrast:1,temperature:0};
const presetReferenceHue=oklch(defaultPaletteOptions.base)!.h??130;
export const biomeGroups=[...new Set(paletteBiomes.map(b=>b.group))];
export const biomeName=(id:PaletteMood)=>paletteBiomes.find(b=>b.id===id)?.label??'Тихий лес';

export function generatePalette(options:PaletteOptions,previous?:Palette):Palette{
 const base=oklch(options.base)!;
 const preset:Biome=paletteBiomes.find(b=>b.id===options.mood)??paletteBiomes[0];
 const names=preset.names??nature;
 const hues=preset.hues??[base.h??130,(base.h??130)+12,58,72,240,218];
 const materials:Material[]=names.map((name,index)=>{
  const old=previous?.materials[index];
  return {id:old?.id??uid(),name,locks:old?.locks??[false,false,false,false],colors:[.22,.36,.53,.73].map((light,i)=>{
   if(old?.locks[i])return old.colors[i];
   const chroma=(preset.chroma?.[index]??(index<2?.11:index===5?.065:.035))*options.saturation*(preset.saturation??1);
   const l=Math.max(.08,Math.min(.94,.48+(light-.48)*options.contrast+(index===0?.05:0)+(preset.lightness?.[index]??0)));
   const customHueShift=preset.hues&&index<2?(base.h??presetReferenceHue)-presetReferenceHue:0;
   const hue=(hues[index]+customHueShift+(index<2?(preset.hueShift??0):0)+options.temperature*(i>1?-15:10)+720)%360;
   return formatHex(clampChroma({mode:'oklch',l,c:chroma,h:hue},'oklch'))??'#000000';
  })};
 });
 return {id:previous?.id??uid(),name:previous?.name??(options.mood==='forest'?'Лес · мягкий дневной свет':preset.label),version:(previous?.version??0)+1,materials};
}
