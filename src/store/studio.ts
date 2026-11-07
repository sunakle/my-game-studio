import {createProject,type Project} from '../core/model';
import {History} from '../core/history';
import {saveProject} from './persistence';
export class Studio{
 project:Project=createProject();history=new History();version=0;revision=0;savedRevision=-1;status='Не сохранено';listeners=new Set<()=>void>();before:Project|null=null;label='';timer:ReturnType<typeof setTimeout>|undefined;saveQueue=Promise.resolve();ready=false;
 subscribe=(fn:()=>void)=>{this.listeners.add(fn);return ()=>{this.listeners.delete(fn);}};
 snapshot=()=>this.version;
 emit=()=>{this.version++;this.listeners.forEach(fn=>fn());};
 begin(label:string){if(this.before)this.finish();this.before=structuredClone(this.project);this.label=label;}
 finish(){if(!this.before)return;const changed=this.history.add(this.label,this.before,this.project);this.before=null;if(changed){this.revision++;this.status=this.history.trimmed?'Старые действия удалены из истории · не сохранено':'Есть изменения';this.project.updatedAt=new Date().toISOString();this.schedule();}this.emit();}
 change(label:string,fn:(p:Project)=>void){this.begin(label);try{fn(this.project);this.finish();}catch(e){if(this.before)this.project=this.before;this.before=null;throw e;}}
 undo(){if(this.before)this.finish();if(this.history.undo(this.project)){this.revision++;this.status='Есть изменения';this.schedule();this.emit();}}
 redo(){if(this.history.redo(this.project)){this.revision++;this.status='Есть изменения';this.schedule();this.emit();}}
 schedule(){clearTimeout(this.timer);this.timer=setTimeout(()=>{void this.save().catch(()=>{});},1000);}
 save(){clearTimeout(this.timer);if(this.before)this.finish();clearTimeout(this.timer);const revision=this.revision,snapshot=structuredClone(this.project);this.status='Сохраняю…';this.emit();const job=this.saveQueue.then(async()=>{try{const date=await saveProject(snapshot);if(this.project.id===snapshot.id){this.savedRevision=revision;this.status=this.revision===revision?'Сохранено на устройстве':'Есть изменения';this.project.updatedAt=date;this.emit();}}catch(e){this.status='Не удалось сохранить · скачайте архив';this.emit();throw e;}});this.saveQueue=job.catch(()=>{});return job;}
 async open(p:Project){if(this.ready)await this.save();clearTimeout(this.timer);this.project=p;this.history=new History();this.before=null;this.revision=0;this.savedRevision=-1;this.ready=true;this.status='Проект открыт';this.emit();await this.save();}
}
export const studio=new Studio();
