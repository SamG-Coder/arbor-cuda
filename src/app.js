import {Engine} from './engine.js';
const $=s=>document.querySelector(s);const canvas=$('canvas'),engine=new Engine(canvas);const params=new URLSearchParams(location.search);const keys=new Set();
const controls=new Float32Array(32);let ready=false,busy=false,faulted=false,inspection=false,requestResize=false,last=0,done=0,fpsAt=0,pollAt=0,screenshotPending=false,seedPending=null;
const widths=[768,1024,1600,1920];let width=widths.includes(Number(params.get('width')))?Number(params.get('width')):1600;let seed=params.has('seed')?Number(params.get('seed')):1788;let pointer=null,buttons=0;
function fatal(e){if(faulted)return;faulted=true;console.error(e);$('#boot').hidden=false;$('#boot-status').textContent='The renderer could not start';$('#boot-detail').textContent=e?.message||String(e);$('#retry').hidden=false;}
function notice(s){$('#notice').textContent=s;$('#notice').classList.add('visible');clearTimeout(notice.timer);notice.timer=setTimeout(()=>$('#notice').classList.remove('visible'),3200);}
function togglePanel(){inspection=!inspection;$('#notes').hidden=!inspection;$('#notes-button').setAttribute('aria-expanded',String(inspection));}
function pulse(index,value=1){controls[index]=value;}
function bookmark(n){pulse(5,n);document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',Number(b.dataset.view)===n));$('#view-name').textContent=['','THE WHOLE TREE','BARK / RELIEF','LEAF / VENATION','ROOT FLARE','DISTANCE / COVERAGE'][n]||'';}
function fillInput(){controls[13]=Number(keys.has('KeyD'))-Number(keys.has('KeyA'));controls[14]=0;controls[15]=Number(keys.has('KeyW'))-Number(keys.has('KeyS'));controls[16]=Number(keys.has('ShiftLeft')||keys.has('ShiftRight'));controls[8]=Number(keys.has('BracketRight'))-Number(keys.has('BracketLeft'));controls[12]=Number(keys.has('Equal'))-Number(keys.has('Minus'));engine.input.set(controls);for(const i of [0,1,2,3,4,5,6,7,9,10,11,17])controls[i]=0;}
function clearControls(){keys.clear();controls.fill(0);pointer=null;buttons=0;}
addEventListener('blur',clearControls);addEventListener('visibilitychange',()=>{clearControls();last=0;});
canvas.addEventListener('click',()=>{canvas.focus();if(document.pointerLockElement!==canvas)canvas.requestPointerLock?.();});
addEventListener('mousemove',e=>{if(document.pointerLockElement!==canvas)return;controls[0]+=e.movementX;controls[1]+=e.movementY;});
canvas.addEventListener('pointerdown',e=>{e.preventDefault();canvas.focus();if(document.pointerLockElement!==canvas)canvas.requestPointerLock?.();});
canvas.addEventListener('contextmenu',e=>e.preventDefault());
addEventListener('keydown',e=>{if(e.target instanceof HTMLInputElement||e.target instanceof HTMLSelectElement)return;if(['Space','Tab','ArrowUp','ArrowDown'].includes(e.code))e.preventDefault();keys.add(e.code);if(e.repeat)return;
 const d=/^Digit([1-5])$/.exec(e.code);if(d){bookmark(Number(d[1]));return;}
 if(e.code==='KeyP')pulse(17);if(e.code==='KeyH'||e.code==='Tab')togglePanel();if(e.code==='KeyO')pulse(6);if(e.code==='KeyB')pulse(7);if(e.code==='KeyV')pulse(9);if(e.code==='KeyJ')pulse(10);
 if(e.code==='KeyF'){if(document.fullscreenElement)document.exitFullscreen().catch(()=>{});else document.documentElement.requestFullscreen().catch(()=>notice('Fullscreen unavailable.'));}
 if(e.code==='KeyC')document.body.classList.toggle('clean');if(e.code==='KeyK')screenshotPending=true;
});addEventListener('keyup',e=>keys.delete(e.code));
for(const b of document.querySelectorAll('[data-view]'))b.onclick=()=>bookmark(Number(b.dataset.view));$('#notes-button').onclick=togglePanel;$('#close-notes').onclick=togglePanel;$('#orbit-button').onclick=()=>pulse(6);$('#approach-button').onclick=()=>pulse(17);$('#breeze-button').onclick=()=>pulse(7);$('#debug-button').onclick=()=>pulse(9);$('#shadow-button').onclick=()=>pulse(10);$('#shot-button').onclick=()=>screenshotPending=true;
$('#quality').value=String(width);$('#quality').onchange=e=>{width=Number(e.target.value);requestResize=true;};$('#regrow').onclick=()=>{const n=Number($('#seed').value);if(!Number.isInteger(n)||n<0||n>1000000){notice('Use an integer seed between 0 and 1,000,000.');return;}seedPending=n;};$('#seed').value=String(seed);$('#retry').onclick=()=>location.reload();
addEventListener('resize',()=>{requestResize=true;});
function dimensions(){const r=canvas.getBoundingClientRect();return [width,Math.round(width*r.height/Math.max(1,r.width))];}
async function takeScreenshot(){const data=await engine.screenshotPixels();const c=document.createElement('canvas');c.width=engine.width;c.height=engine.height;c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(data),c.width,c.height),0,0);const blob=await new Promise(r=>c.toBlob(r,'image/png'));const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`ARBOR-seed-${engine.seed}-${Date.now()}.png`;a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);notice('Saved the actual GPU-computed frame.');}
async function poll(){if(poll.busy)return;poll.busy=true;try{const s=await engine.inspect();const c=s.camera;$('#spp').textContent=`${Math.round(c[9]+1)} spp`;$('#res').textContent=`${s.width} × ${s.height}`;$('#scene-memory').textContent=`${(s.sceneBytes/1048576).toFixed(2)} MiB`;$('#total-memory').textContent=`${(s.allocatedBytes/1048576).toFixed(1)} MiB`;$('#distance').textContent=`${c[3].toFixed(c[3]<1?3:2)} m`;
 const fp=c[14]*c[3]/s.height;$('#footprint').textContent=`${(fp*1000).toFixed(3)} mm / px`;
 $('#gpu-times').textContent=s.timings?s.timings.map(t=>`${t.name} ${t.ms.toFixed(2)} ms`).join('  ·  '):'GPU timestamps not available';
 $('#approach-button').classList.toggle('active',c[34]>0);$('#breeze-button').classList.toggle('active',c[11]>0);$('#orbit-button').classList.toggle('active',c[19]>0);$('#shadow-button').textContent=c[22]>0?'Lighting: full':'Lighting: unshadowed';$('#mode-name').textContent=['LIT','DETAIL BANDS','PRIMITIVE ID','NORMALS'][c[15]]||'LIT';
 window.arbor.lastInspection=s;
 }catch(e){console.warn(e);}finally{poll.busy=false;}}
async function frame(now){requestAnimationFrame(frame);if(!ready||faulted||document.hidden||busy||params.has('test'))return;busy=true;try{
 if(requestResize){requestResize=false;await engine.resize(...dimensions());last=0;}
 if(seedPending!==null){const n=seedPending;seedPending=null;await engine.generate(n);bookmark(1);notice(`Regrown from seed ${n}.`);}
 fillInput();engine.frame(last?Math.min(.1,(now-last)/1000):1/60);last=now;await engine.device.queue.onSubmittedWorkDone();done++;
 if(now-fpsAt>1000){$('#fps').textContent=`${Math.round(done*1000/(now-fpsAt))} fps`;fpsAt=now;done=0;}
 if(now-pollAt>700){pollAt=now;poll();}
 if(screenshotPending){screenshotPending=false;await takeScreenshot();}
 }catch(e){fatal(e);}finally{busy=false;}}
async function start(){try{await engine.init({width:dimensions()[0],height:dimensions()[1],seed,recompile:params.has('compile'),onProgress:(text,f)=>{$('#boot-status').textContent=text;$('#progress').style.width=`${Math.round(f*100)}%`;},onError:fatal});ready=true;$('#boot').hidden=true;canvas.focus();window.arbor={engine,bookmark,ready:true};bookmark(1);fillInput();engine.frame(1/60);await engine.runtime.idle();fpsAt=performance.now();poll();requestAnimationFrame(frame);}catch(e){fatal(e);}}
start();
