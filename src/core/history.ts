type Path=(string|number)[];
type Patch={path:Path;before:unknown;after:unknown;offset?:number;beforeExists?:boolean;afterExists?:boolean};
type Entry={name:string;patches:Patch[];bytes:number};
const own=(v:object,k:string)=>Object.prototype.hasOwnProperty.call(v,k);
export function differences(a:any,b:any,path:Path=[]):Patch[]{
 if(a===b)return [];
 if(a instanceof Uint8ClampedArray&&b instanceof Uint8ClampedArray&&a.length===b.length){const out:Patch[]=[];for(let i=0;i<a.length;){if(a[i]===b[i]){i++;continue;}const start=i;while(i<a.length&&a[i]!==b[i])i++;out.push({path,offset:start,before:a.slice(start,i),after:b.slice(start,i)});}return out;}
 if(a&&b&&typeof a==='object'&&typeof b==='object'&&!Array.isArray(a)&&!Array.isArray(b)&&!(a instanceof Uint8ClampedArray)&&!(b instanceof Uint8ClampedArray)){return [...new Set([...Object.keys(a),...Object.keys(b)])].flatMap(k=>own(a,k)&&own(b,k)?differences(a[k],b[k],[...path,k]):[{path:[...path,k],before:structuredClone(a[k]),after:structuredClone(b[k]),beforeExists:own(a,k),afterExists:own(b,k)}]);}
 if(Array.isArray(a)&&Array.isArray(b)&&JSON.stringify(a)===JSON.stringify(b))return [];
 return [{path,before:structuredClone(a),after:structuredClone(b)}];
}
function size(v:any):number{if(v instanceof Uint8ClampedArray)return v.byteLength;if(v&&typeof v==='object')return Object.values(v).reduce<number>((s,n)=>s+size(n),0);return typeof v==='string'?v.length*2:8;}
function apply(root:any,patches:Patch[],redo:boolean){for(const p of patches){let target=root;for(const k of p.path.slice(0,-1))target=target[k];const key=p.path.at(-1)!;const value=redo?p.after:p.before;if(p.offset!==undefined)target[key].set(value,p.offset);else if((redo?p.afterExists:p.beforeExists)===false)delete target[key];else target[key]=structuredClone(value);}}
export class History{
 undoStack:Entry[]=[];redoStack:Entry[]=[];bytes=0;limit=64*1024*1024;trimmed=false;
 add(name:string,before:unknown,after:unknown){const patches=differences(before,after);if(!patches.length)return false;const entry={name,patches,bytes:size(patches)};this.redoStack=[];this.undoStack.push(entry);this.bytes+=entry.bytes;this.trimmed=false;while(this.bytes>this.limit&&this.undoStack.length){this.bytes-=this.undoStack.shift()!.bytes;this.trimmed=true;}return true;}
 undo(root:unknown){const e=this.undoStack.pop();if(!e)return false;this.bytes-=e.bytes;apply(root,[...e.patches].reverse(),false);this.redoStack.push(e);return true;}
 redo(root:unknown){const e=this.redoStack.pop();if(!e)return false;apply(root,e.patches,true);this.undoStack.push(e);this.bytes+=e.bytes;return true;}
}
