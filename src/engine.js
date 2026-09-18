import {GpuRuntime} from '../vendor/cuda-webshader/runtime/runtime.js';
export const ABI=Object.freeze({CAPACITY:32768,NODE_COUNT:65536,PS:24,CS:20,CURVES:2109,WOOD_COUNT:5124,LEAF_COUNT:24192,ROCK_COUNT:96,OBJECT_COUNT:29412});
/** Browser transport. Tree generation, visibility, surfaces, lighting and camera are CUDA. */
export class Engine {
 constructor(canvas){this.canvas=canvas;this.buffers={};this.kernels={};this.input=new Float32Array(32);this.frames=0;this.errors=[];this.disposed=false;this.timings=null;this.timingBusy=false;}
 async init({width=1600,height=900,seed=1788,device=null,adapter=null,recompile=false,onProgress=()=>{},onError=()=>{}}={}){
  const ownsDevice=!device;
  if(!device){
   if(!globalThis.navigator?.gpu)throw Error('WebGPU is unavailable. Use an up-to-date Chrome or Edge with hardware acceleration, on localhost or HTTPS.');
   adapter=await navigator.gpu.requestAdapter({powerPreference:'high-performance'});if(!adapter)throw Error('No WebGPU adapter was returned. Check browser hardware acceleration and graphics drivers.');
   device=await adapter.requestDevice({requiredFeatures:adapter.features.has('timestamp-query')?['timestamp-query']:[]});
  }
  this.device=device;this.adapter=adapter;this.runtime=new GpuRuntime(device,{adapter,ownsDevice,uniformCapacity:262144,onError:e=>{this.errors.push(String(e?.message||e));onError(e);}});this.info=this.runtime.describe();this.context=this.canvas?.getContext('webgpu')??null;
  const manifestResponse=await fetch(new URL('../generated/manifest.json',import.meta.url));if(!manifestResponse.ok)throw Error('Missing shader manifest. Extract the whole ZIP and start the local server.');this.manifest=await manifestResponse.json();
  const sources=new Map();let compile;if(recompile)({compile}=await import('../vendor/cuda-webshader/compiler/compiler.js'));
  for(let i=0;i<this.manifest.length;i++){
   const spec=this.manifest[i];onProgress(`Compiling ${spec.entry}`,i/(this.manifest.length+2));let artifact;
   if(recompile){for(const f of spec.dependencies)if(!sources.has(f)){const r=await fetch(new URL(`../kernels/${f}.cu`,import.meta.url));if(!r.ok)throw Error(`Missing CUDA source ${f}`);sources.set(f,await r.text());}artifact=compile(spec.dependencies.map(f=>sources.get(f)).join('\n'),{entry:spec.entry,workgroupSize:spec.workgroupSize});}
   else{const r=await fetch(new URL(`../generated/${spec.entry}.json`,import.meta.url));if(!r.ok)throw Error(`Missing generated kernel ${spec.entry}`);artifact=await r.json();}
   this.kernels[spec.entry]=await this.runtime.kernel(artifact);
  }
  const a=ABI;for(const [name,n]of Object.entries({B:a.CURVES*a.CS,P:a.CAPACITY*a.PS,Keys:a.CAPACITY,Order:a.CAPACITY,Nodes:a.NODE_COUNT*8,C:64,I:32}))this.buffers[name]=this.runtime.createBuffer(n*4,{label:`ARBOR ${name}`});
  if(device.features.has('timestamp-query')){this.querySet=device.createQuerySet({type:'timestamp',count:6});this.queryResolve=device.createBuffer({size:256,usage:GPUBufferUsage.QUERY_RESOLVE|GPUBufferUsage.COPY_SRC});this.queryRead=device.createBuffer({size:48,usage:GPUBufferUsage.COPY_DST|GPUBufferUsage.MAP_READ});}
  await this.resize(width,height);onProgress('Growing branches and leaves',.89);await this.generate(seed);onProgress('Ready',1);return this;
 }
 bind(entry,scalars={}){const k=this.kernels[entry];if(!k)throw Error(`Unknown kernel ${entry}`);const b=Object.fromEntries(k.artifact.metadata.bindings.map(x=>{const v=this.buffers[x.name];if(!v)throw Error(`Unbound ${entry}.${x.name}`);return [x.name,v];}));return k.bind(b,scalars);}
 async generate(seed=1788){
  if(!Number.isInteger(seed)||seed<0||seed>1000000)throw Error('Seed must be an integer from 0 to 1,000,000.');await this.runtime.idle();this.seed=seed;
  const b=this.runtime.batch({label:'ARBOR / grow once, sort, build all BVH levels'});for(const [level,count]of [9,12,72,288,1728].entries())b.dispatch(this.bind('growTree',{level,seed}),[Math.ceil(count/64)]);
  b.dispatch(this.bind('makePrimitives',{seed}),[256*2]).dispatch(this.bind('makeKeys'),[256]);
  for(let span=2;span<=ABI.CAPACITY;span*=2)for(let distance=span/2;distance>=1;distance/=2)b.dispatch(this.bind('sortPass',{distance,span}),[256]);
  b.dispatch(this.bind('makeBounds'),[256]);for(let first=ABI.CAPACITY/2;first>=1;first/=2)b.dispatch(this.bind('reduceBounds',{first}),[Math.ceil(first/128)]);
  b.dispatch(this.bind('initCamera',{seed}),[1]).clear(this.buffers.History).submit();await this.runtime.idle();
 }
 async resize(width,height){
  if(!Number.isFinite(width)||!Number.isFinite(height))throw Error('Invalid render dimensions.');width=Math.max(320,Math.ceil(width/64)*64);height=Math.max(192,Math.ceil(height/8)*8);
  const max=this.device.limits.maxTextureDimension2D;if(width>max||height>max||width*height*16>this.device.limits.maxStorageBufferBindingSize)throw Error('Resolution exceeds the adapter limits. Choose a lower width.');
  if(this.width===width&&this.height===height)return;await this.runtime.idle();
  for(const key of ['Hit','Linear','Guide','Filtered','History','Pixels'])if(this.buffers[key])this.runtime.destroyBuffer(this.buffers[key]);
  this.width=width;this.height=height;for(const name of ['Hit','Linear','Guide','Filtered','History'])this.buffers[name]=this.runtime.createBuffer(width*height*16,{label:name});this.buffers.Pixels=this.runtime.createBuffer(width*height*4,{label:'CUDA computed RGBA image'});
  if(this.canvas){this.canvas.width=width;this.canvas.height=height;}if(this.context)this.context.configure({device:this.device,format:'rgba8unorm',usage:GPUTextureUsage.COPY_DST|GPUTextureUsage.RENDER_ATTACHMENT,alphaMode:'opaque'});
  this.calls={};for(const name of ['tracePixels','shadePixels','filterLighting','resolvePixels'])this.calls[name]=this.bind(name,{width,height});this.calls.updateCamera=this.bind('updateCamera',{width,height,delta:1/60});
 }
 batch(label,index,timed){return this.runtime.batch({label,...(timed?{timestampWrites:{querySet:this.querySet,beginningOfPassWriteIndex:index*2,endOfPassWriteIndex:index*2+1}}:{})});}
 frame(dt=1/60,{present=true}={}){
  if(this.disposed)throw Error('Renderer was disposed.');this.runtime.write(this.buffers.I,this.input);this.calls.updateCamera.setScalars({width:this.width,height:this.height,delta:Math.max(0,Math.min(.1,dt))});
  const timed=!!this.querySet&&!this.timingBusy&&this.frames%24===0;const grid=[Math.ceil(this.width/8),Math.ceil(this.height/8)];
  this.batch('ARBOR / visibility',0,timed).dispatch(this.calls.updateCamera,[1]).dispatch(this.calls.tracePixels,grid).submit();
  this.batch('ARBOR / materials and light',1,timed).dispatch(this.calls.shadePixels,grid).submit();
  const resolve=this.batch('ARBOR / progressive resolve',2,timed).dispatch(this.calls.filterLighting,grid).dispatch(this.calls.resolvePixels,grid);resolve.endPass();
  if(present&&this.context)resolve.encoder.copyBufferToTexture({buffer:this.buffers.Pixels.gpuBuffer,bytesPerRow:this.width*4,rowsPerImage:this.height},{texture:this.context.getCurrentTexture()},[this.width,this.height]);
  if(timed){resolve.encoder.resolveQuerySet(this.querySet,0,6,this.queryResolve,0);resolve.encoder.copyBufferToBuffer(this.queryResolve,0,this.queryRead,0,48);}resolve.submit();if(timed)this.readTimes();this.frames++;
 }
 async readTimes(){this.timingBusy=true;try{await this.queryRead.mapAsync(GPUMapMode.READ);const t=new BigUint64Array(this.queryRead.getMappedRange());this.timings=['Visibility','Lighting','Resolve'].map((name,i)=>({name,ms:Number(t[2*i+1]-t[2*i])/1e6}));this.queryRead.unmap();}catch(e){this.timings=null;}finally{this.timingBusy=false;}}
 async inspect(){const c=await this.runtime.read(this.buffers.C);const allocatedBytes=Object.values(this.buffers).reduce((n,b)=>n+b.byteLength,0);const sceneBytes=['B','P','Keys','Order','Nodes'].reduce((n,k)=>n+this.buffers[k].byteLength,0);return {camera:Array.from(c),allocatedBytes,sceneBytes,width:this.width,height:this.height,timings:this.timings,frames:this.frames,seed:this.seed,geometry:ABI,adapter:this.info};}
 async screenshotPixels(){return this.runtime.read(this.buffers.Pixels,Uint8Array);}
 async dispose(){if(this.disposed)return;await this.runtime.idle();this.disposed=true;this.querySet?.destroy();this.queryRead?.destroy();this.queryResolve?.destroy();this.runtime.dispose();}
}
