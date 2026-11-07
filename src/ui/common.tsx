import {useEffect,useRef} from 'react';
import {X} from 'lucide-react';
import type {Asset} from '../core/model';
import {composite} from '../core/pixel';
import {surface} from '../io/files';
export function Thumb({asset,frameId,size=48,native=false}:{asset:Asset;frameId?:string;size?:number;native?:boolean}){const ref=useRef<HTMLCanvasElement>(null);useEffect(()=>{const c=ref.current;if(!c)return;const id=frameId??Object.keys(asset.frames)[0];c.width=asset.width;c.height=asset.height;c.getContext('2d')!.drawImage(surface(composite(asset,id),asset.width,asset.height),0,0);});return <canvas ref={ref} className="thumb" style={native?{width:asset.width,height:asset.height}:{width:Math.max(1,asset.width/Math.max(asset.width,asset.height)*size),height:Math.max(1,asset.height/Math.max(asset.width,asset.height)*size)}}/>;}
export function Modal({title,children,onClose}:{title:string;children:React.ReactNode;onClose:()=>void}){const ref=useRef<HTMLDialogElement>(null);useEffect(()=>{const d=ref.current;d?.showModal();return ()=>d?.close();},[]);return <dialog ref={ref} onCancel={onClose} onClick={e=>{if(e.target===e.currentTarget)onClose();}}><header><h2>{title}</h2><button className="icon" aria-label="Закрыть" onClick={onClose}><X size={18}/></button></header>{children}</dialog>;}
export function Empty({title,children}:{title:string;children:React.ReactNode}){return <div className="empty"><span className="empty-mark">✦</span><h2>{title}</h2><p>{children}</p></div>;}
