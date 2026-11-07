import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,readdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
const desktop=process.env.USERPROFILE?join(process.env.USERPROFILE,'Desktop'):'';
const exe=process.env.GODOT_BIN||(desktop&&existsSync(desktop)?readdirSync(desktop).filter(n=>/^Godot.*console\.exe$/.test(n)).map(n=>join(desktop,n))[0]:null)||'godot';
mkdirSync('test-results',{recursive:true});
const fixtures=['tree','tree-updated','water'].map(n=>resolve(`test-results/fixtures/${n}.mgasset.zip`));
if(fixtures.some(p=>!existsSync(p)))throw new Error('Сначала выполните npm run test:e2e, чтобы получить настоящие пакеты из браузера.');
for(const [script,args] of [['import_smoke',fixtures],['scene_smoke',[]]]){
 const run=spawnSync(exe,['--headless','--log-file',resolve(`test-results/godot-${script}.log`),'--path',resolve('godot/demo'),'--script',`res://tests/${script}.gd`,'--',...args],{encoding:'utf8',timeout:30000});
 process.stdout.write(run.stdout||'');process.stderr.write(run.stderr||'');
 if(run.error||run.status!==0||!run.stdout.includes('PASS:'))throw new Error(`Проверка Godot ${script} не прошла: ${run.error?.message??run.status}`);
}
