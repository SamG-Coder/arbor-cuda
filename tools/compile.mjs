import fs from 'node:fs/promises';
import {compile} from '../vendor/cuda-webshader/compiler/compiler.js';
const root=new URL('../',import.meta.url);
const files=['common','tree','cache','surface','camera','trace','shade'];
const groups={tree:{growTree:64,makePrimitives:64},cache:{makeKeys:128,sortPass:128,makeBounds:128,reduceBounds:128},camera:{initCamera:1,updateCamera:1},trace:{tracePixels:[8,8,1]},shade:{shadePixels:[8,8,1],filterLighting:[8,8,1],resolvePixels:[8,8,1]}};
const deps={tree:['common','tree'],cache:['common','tree','cache'],camera:['common','camera'],trace:['common','tree','surface','trace'],shade:['common','tree','surface','trace','shade']};
const text=Object.fromEntries(await Promise.all(files.map(async f=>[f,await fs.readFile(new URL(`kernels/${f}.cu`,root),'utf8')])));
await fs.mkdir(new URL('generated/',root),{recursive:true});let manifest=[],failed=0;
for(const [file,entries] of Object.entries(groups)) for(const [entry,block] of Object.entries(entries)) {
 const workgroupSize=Array.isArray(block)?block:[block,1,1];
 try {const artifact=compile(deps[file].map(f=>text[f]).join('\n'),{entry,workgroupSize});const {ast,kernel,...portable}=artifact;
 await fs.writeFile(new URL(`generated/${entry}.json`,root),JSON.stringify(portable));await fs.writeFile(new URL(`generated/${entry}.wgsl`,root),artifact.wgsl);
 manifest.push({entry,file,workgroupSize,dependencies:deps[file],bindings:artifact.metadata.bindings.map(x=>x.name)});console.log(`OK ${entry} / ${artifact.wgsl.length} WGSL bytes / ${artifact.metadata.bindings.length} buffers`);
 }catch(e){console.error(`FAILED ${entry}: ${e.stack||e}`);failed++;}
}
await fs.writeFile(new URL('generated/manifest.json',root),JSON.stringify(manifest,null,2));
await fs.writeFile(new URL('Arbor.cu',root),'// ARBOR: combined source, generated from kernels/*.cu.\n'+files.map(f=>`\n// === ${f.toUpperCase()} ===\n${text[f]}`).join('\n'));
if(failed)process.exitCode=1;
