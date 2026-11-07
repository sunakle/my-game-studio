export function historyShortcut(event:Pick<KeyboardEvent,'ctrlKey'|'metaKey'|'shiftKey'|'altKey'|'code'|'key'>):'undo'|'redo'|null{
 if(!(event.ctrlKey||event.metaKey)||event.altKey)return null;
 // Physical codes also work when Z/Y produce Я/Н in the Russian layout.
 if(event.code==='KeyZ'||event.key.toLowerCase()==='z')return event.shiftKey?'redo':'undo';
 if(event.code==='KeyY'||event.key.toLowerCase()==='y')return 'redo';
 return null;
}
export function isTextEditingTarget(target:EventTarget|null):boolean{
 return target instanceof Element&&!!target.closest('textarea,select,[contenteditable=""],[contenteditable="true"],input:not([type="color"]):not([type="range"]):not([type="checkbox"]):not([type="button"]):not([type="submit"])');
}
