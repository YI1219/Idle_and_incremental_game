const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'..'),page=fs.readFileSync(path.join(root,'compare.html'),'utf8');
const els={}; const seen=new Set();
function element(id){return els[id]??=({value:({phase:'1',view:'game',water:'000',waterView:'whole',control:'brush_fine'})[id]||'',events:{},addEventListener(k,fn){this.events[k]=fn},getAttribute(k){return this[k]}})}
const context={document:{getElementById:element}};
vm.createContext(context);vm.runInContext(page.match(/<script>([\s\S]*?)<\/script>/)[1],context);
for(const v of ['game','close','whole','reverse','cliff_close']){element('view').value=v;element('view').events.change();seen.add(element('before').src);seen.add(element('after').src)}
for(let i=0;i<16;i++){element('phase').value=String(i);element('phase').events.input();seen.add(element('phaseImage').src);if(!element('phaseLabel').textContent)throw Error('missing phase label')}
for(const t of ['000','010','060'])for(const v of ['whole','outlet']){element('water').value=t;element('waterView').value=v;element('water').onchange();seen.add(element('waterImage').src)}
element('phase').value='0';element('prev').onclick();if(Number(element('phase').value)!==0)throw Error('prev boundary');
element('phase').value='15';element('next').onclick();if(Number(element('phase').value)!==15)throw Error('next boundary');
for(const c of ['brush_fine','brush_wide','zoom_near','zoom_far','right_drag_orbit']){element('control').value=c;element('control').onchange();seen.add(element('controlImage').src)}
for(const m of page.matchAll(/(?:href|src)="([^"#]+)"/g)){if(!m[1].includes(':'))seen.add(m[1])}
for(const p of seen)if(!fs.existsSync(path.join(root,p)))throw Error('missing '+p);
if(/WATERROWS|PHASEDATA|OPTIONS/.test(page))throw Error('unexpanded template');
console.log(JSON.stringify({javascript_states:32,phase_boundaries:2,resource_paths:seen.size,all_exist:true,browser_rendered:false}));
