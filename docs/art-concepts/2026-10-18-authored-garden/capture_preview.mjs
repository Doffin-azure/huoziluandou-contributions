// Optional review export. Uses an isolated, locally started headless Chrome.
// No npm dependencies. CHROME_DEBUG_URL can select a different local endpoint.
import fs from 'node:fs/promises';
import {fileURLToPath, pathToFileURL} from 'node:url';
import path from 'node:path';

const folder = path.dirname(fileURLToPath(import.meta.url));
const endpoint = process.env.CHROME_DEBUG_URL || 'http://127.0.0.1:9337';
const target = await (await fetch(endpoint + '/json/new?about:blank', {method:'PUT'})).json();
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve,reject) => {socket.onopen=resolve;socket.onerror=reject});
let serial=0;
const pending=new Map();
const errors=[];
socket.onmessage=event=>{
  const message=JSON.parse(event.data);
  if(message.method==='Runtime.exceptionThrown') errors.push(message.params.exceptionDetails);
  if(!message.id)return;
  const request=pending.get(message.id);if(!request)return;
  pending.delete(message.id);clearTimeout(request.timer);
  message.error?request.reject(new Error(JSON.stringify(message.error))):request.resolve(message.result);
};
function send(method,params={}){
  return new Promise((resolve,reject)=>{
    const id=++serial;
    const timer=setTimeout(()=>{pending.delete(id);reject(new Error('CDP timeout: '+method))},15000);
    pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
  });
}
async function evaluate(expression){
  const result=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
  if(result.exceptionDetails)throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function navigate(query,width,height){
  await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:pathToFileURL(path.join(folder,'index.html')).href+query});
  for(let i=0;i<60;i++){
    try{if(await evaluate('!!window.gardenPreview && document.readyState === "complete"'))break}catch{}
    await new Promise(resolve=>setTimeout(resolve,100));
  }
  await evaluate('document.fonts.ready.then(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))))');
}
async function screenshot(file){
  const result=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,fromSurface:true});
  await fs.writeFile(path.join(folder,file),Buffer.from(result.data,'base64'));
}
try{
  await send('Page.enable');await send('Runtime.enable');
  await navigate('?export=1',1270,1160);await screenshot('01-spatial-plan.png');
  await navigate('?export=1&routes=1',1270,1160);await screenshot('02-nodes-and-gates.png');
  await navigate('',1600,1320);await screenshot('03-interactive-preview.png');
  const checks=await evaluate(`(()=>{
    document.getElementById('route').click();
    document.querySelector('[data-choice="0,0"]').click();
    document.querySelector('[data-choice="1,1"]').click();
    document.querySelector('[data-choice="2,0"]').click();
    const sealCount=[...document.querySelectorAll('.gate-closed')].filter(el=>getComputedStyle(el).display!=='none').length;
    document.querySelector('[data-node="g1_b1_1"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));
    const detail=document.getElementById('detail').textContent;
    document.getElementById('roof').click();
    document.getElementById('sight').click();
    document.getElementById('east').click();
    return {selected:window.gardenPreview.picks,sealed_gates:sealCount,summary:document.getElementById('route-summary').textContent,detail,roofHidden:document.body.classList.contains('roof-off'),sightShown:document.body.classList.contains('sight-on'),viewBox:document.querySelector('svg').getAttribute('viewBox')};
  })()`);
  if(checks.sealed_gates!==6||!checks.roofHidden||!checks.sightShown)throw new Error(JSON.stringify(checks));
  await evaluate('window.gardenPreview.mode(false); document.getElementById("roof").click(); document.getElementById("sight").click();');
  await screenshot('04-architectural-detail.png');
  await navigate('',720,1200);
  const responsive=await evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth,svg:!!window.gardenPreview})');
  if(responsive.scroll>responsive.width)throw new Error('Horizontal overflow: '+JSON.stringify(responsive));
  if(errors.length)throw new Error(JSON.stringify(errors));
  console.log(JSON.stringify({checks,responsive,browser_errors:errors.length},null,2));
}finally{
  socket.close();await fetch(endpoint+'/json/close/'+target.id);
}
