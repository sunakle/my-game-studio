import {converter,clampChroma,formatHex} from 'culori';
import {uid,type Palette,type Material} from './model';
const oklch=converter('oklch');
export type PaletteOptions={base:string;mood:'forest'|'mist'|'autumn';saturation:number;contrast:number;temperature:number};
export const defaultPaletteOptions:PaletteOptions={base:'#6e9951',mood:'forest',saturation:1,contrast:1,temperature:0};
export function generatePalette(options:PaletteOptions,previous?:Palette):Palette{
 const base=oklch(options.base)!;const names=['Трава','Листва','Кора','Земля','Камень','Вода'];const hues=[base.h??130,(base.h??130)+12,58,72,240,218];
 const materials:Material[]=names.map((name,index)=>{const old=previous?.materials[index];return {id:old?.id??uid(),name,locks:old?.locks??[false,false,false,false],colors:[.22,.36,.53,.73].map((light,i)=>{
 if(old?.locks[i])return old.colors[i];const mood=options.mood==='mist'?.65:options.mood==='autumn'?.85:1;const chroma=(index<2?.11:index===5?.065:.035)*options.saturation*mood;
 const l=Math.max(.08,Math.min(.94,.48+(light-.48)*options.contrast+(index===0?.05:0)));
 const hue=(hues[index]+(options.mood==='autumn'&&index<2?-52:0)+options.temperature*(i>1?-15:10)+360)%360;
 return formatHex(clampChroma({mode:'oklch',l,c:chroma,h:hue},'oklch'))??'#000000';})};});
 return {id:previous?.id??uid(),name:previous?.name??'Лес · мягкий дневной свет',version:(previous?.version??0)+1,materials};
}
