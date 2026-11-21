const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'compare.html'),'utf8'),source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const elements=new Map(),el=id=>{if(!elements.has(id))elements.set(id,{value:id==='stage'?'all':'50',style:{},dataset:{},classList:{toggle(){}}});return elements.get(id)};
const buttons=['A','B','P','D','C'].map(v=>({dataset:{view:v},classList:{toggle(){}}}));
const ctx=vm.createContext({document:{getElementById:el,querySelectorAll:()=>buttons},location:{pathname:path.join(root,'compare.html')}});vm.runInContext(source,ctx);
let count=0;
for(const stage of ['all','junction','rhythm','roots','waterfall','path'])for(const v of ['A','B','P','D','C']){el('stage').value=stage;vm.runInContext(`view='${v}';update()`,ctx);for(const id of ['before','after','beforeManifest','afterManifest','target']){const url=el(id).src||el(id).href;if(!fs.existsSync(path.resolve(root,url)))throw Error(id+' missing '+url);}count++;}
el('slider').value='37';el('slider').oninput();if(el('line').style.left!=='37%'||el('clip').style.clipPath!=='inset(0 63% 0 0)')throw Error('slider state');el('mode').onclick();if(el('paired').style.display!=='grid')throw Error('paired state');el('mode').onclick();if(el('viewer').style.display!=='block')throw Error('viewer state');
const result={states_checked:count,all_images_manifests_targets_exist:true,slider_and_mode_state_passed:true,validation_mode:'JavaScript state and filesystem paths',browser_rendering_tested_by_this_script:false};fs.writeFileSync(path.join(root,'checks/compare_audit.json'),JSON.stringify(result,null,2)+'\n');console.log(result);
