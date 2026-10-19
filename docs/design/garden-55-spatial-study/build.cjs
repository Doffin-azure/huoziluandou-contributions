// Spatial discussion prototype. Does not load the game or change its saves.
const fs = require('node:fs');
const path = require('node:path');
const out = __dirname;
const types = { start:'起点', battle:'普通战', elite:'精英', event:'事件', rest:'火堆', shop:'商店', treasure:'宝藏', boss:'首领' };
const symbols = { start:'始', battle:'战', elite:'镇', event:'问', rest:'息', shop:'市', treasure:'藏', boss:'渊' };
const colors = { start:'#d5bd80', battle:'#c77a64', elite:'#e19b5c', event:'#a9bdac', rest:'#98b8c3', shop:'#d4bc75', treasure:'#b3a1c2', boss:'#e8a27b' };
const matrix = [
 ['battle','battle','battle'], ['event','battle','shop','battle'], ['battle','event','battle','rest'],
 ['event','battle','event'], ['battle','rest','event','battle'], ['elite','event','battle','shop'],
 ['battle','event','elite'], ['shop','battle','rest','event'], ['treasure','treasure','treasure'],
 ['battle','event','elite','battle'], ['rest','elite','event','battle'], ['event','shop','battle'],
 ['elite','battle','rest','event'], ['battle','elite','event'], ['rest','rest','rest']
];
const omitted = [1,-1,-1,2,-1,-1,0,-1,3,-1,-1,1,-1,2,0];
const bankCrossings = new Set([1,4,7,10,12]);
const names = ['门前夹院','南岸花径','照壁书庭','枫下石庭','曲廊过院','临池前庭','碑廊夹庭','莲浦水院','藏字水榭','北岸石庭','松风侧院','后园书斋','镇碑前院','终庭外廊','息灯前庭'];
const nodes = [{id:'start', kind:'start', x:33, y:104, row:-1, lane:1.5, w:13, h:5, name:'入园门厅'}];
const rows=[];
for(let r=0;r<15;r++) {
 const lanes=[0,1,2,3].filter(l=>l!==omitted[r]);
 const row=lanes.map((lane,i)=>{
  const kind=matrix[r][i];
  const x=[9,24,42,57][lane]+[-1,0,1,0,-1][(r+lane)%5];
  return {id:`n${String(nodes.length+i+1).padStart(2,'0')}`,kind,x,y:96-r*6,row:r,lane,w:kind==='elite'?9:7,h:['battle','elite'].includes(kind)?5:3,name:`${names[r]}·${'西中东外'[lane]}`};
 });
 rows.push(row); nodes.push(...row);
}
nodes.push({id:'boss',kind:'boss',x:33,y:4,row:15,lane:1.5,w:13,h:5,name:'终庭镇守'});
nodes.forEach((n,i)=>n.number=i+1);
const byId=Object.fromEntries(nodes.map(n=>[n.id,n]));
const edges=[];
function add(a,b) {
 if(edges.some(e=>e.from===a.id&&e.to===b.id)) return;
 const mid=Math.round((a.y+b.y)/2);
 const points=[[a.x,a.y],[a.x,mid],[b.x,mid],[b.x,b.y]].filter((p,i,ps)=>i===0||p[0]!==ps[i-1][0]||p[1]!==ps[i-1][1]);
 edges.push({id:`${a.id}-${b.id}`,from:a.id,to:b.id,points,waterBridge:(a.x<33)!==(b.x<33)&&!['start','boss'].includes(a.id)&&!['start','boss'].includes(b.id)});
}
for(const b of rows[0]) add(nodes[0],b);
for(let r=0;r<14;r++) {
 const a=rows[r], b=rows[r+1];
 const sameBank=(u,v)=>(u.lane<2)===(v.lane<2);
 for(const u of a) add(u,b.filter(v=>sameBank(u,v)).sort((v,w)=>Math.abs(u.x-v.x)-Math.abs(u.x-w.x))[0]);
 for(const v of b) if(!edges.some(e=>e.to===v.id)) add([...a].filter(u=>sameBank(u,v)).sort((u,w)=>Math.abs(u.x-v.x)-Math.abs(w.x-v.x))[0],v);
 // A side route opens into a real junction. There is no invisible lane divider.
 if(r%3!==2) {
  const bank=r%2;
  const aa=a.filter(u=>(u.lane<2?0:1)===bank), bb=b.filter(u=>(u.lane<2?0:1)===bank);
  if(aa.length===2&&bb.length===2) add(aa[r%2],bb[1-r%2]);
 }
 if(bankCrossings.has(r)) {
  const left=a.filter(n=>n.lane<2).at(-1), right=b.find(n=>n.lane>=2);
  add(left,right);
 }
}
for(const a of rows.at(-1)) add(a,nodes.at(-1));
const cells=new Set();
const key=(x,y)=>`${x},${y}`;
function paintRect(n) {for(let x=n.x-(n.w-1)/2;x<=n.x+(n.w-1)/2;x++)for(let y=n.y-(n.h-1)/2;y<=n.y+(n.h-1)/2;y++)cells.add(key(x,y));}
for(const n of nodes) paintRect(n);
for(const e of edges) for(let i=1;i<e.points.length;i++) {
 const [ax,ay]=e.points[i-1], [bx,by]=e.points[i], count=Math.abs(ax-bx)+Math.abs(ay-by);
 for(let j=0;j<=count;j++) cells.add(key(ax+Math.sign(bx-ax)*j,ay+Math.sign(by-ay)*j));
}
// Two substantial banks rather than a separate island for every encounter.
// Non-walkable dry areas are raised planted beds with a visible stone rim.
const bankBands=[[8,26,28,40],[27,44,26,39],[45,62,25,42],[63,80,28,39],[81,100,29,37]];
const bankRects=bankBands.flatMap(([top,bottom,west,east])=>[[3,top,west-2,bottom-top+1],[east,top,64-east,bottom-top+1]]);
const beds=new Set();
for(const [left,top,width,height]of bankRects)for(let x=left;x<left+width;x++)for(let y=top;y<top+height;y++)if(!cells.has(key(x,y)))beds.add(key(x,y));
const bedGroups=[];const remaining=new Set(beds);
while(remaining.size){const queue=[remaining.values().next().value];remaining.delete(queue[0]);for(let i=0;i<queue.length;i++){const[x,y]=queue[i].split(',').map(Number);for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const k=key(x+dx,y+dy);if(remaining.has(k)){remaining.delete(k);queue.push(k);}}}bedGroups.push(queue);}
const steps=[[1,0],[-1,0],[0,1],[0,-1]];
const blockedLinks=new Set();
const pair=(a,b)=>[a,b].sort().join('|');
for(const n of nodes) {
 const left=n.x-(n.w-1)/2,right=n.x+(n.w-1)/2,top=n.y-(n.h-1)/2,bottom=n.y+(n.h-1)/2;
 for(let x=left;x<=right;x++)for(let y=top;y<=bottom;y++)for(const [dx,dy] of steps) {
  const nx=x+dx,ny=y+dy;
  if(nx>=left&&nx<=right&&ny>=top&&ny<=bottom)continue;
  if(x===n.x&&dx===0)continue; // The drawn north/south doorway.
  if(cells.has(key(nx,ny)))blockedLinks.add(pair(key(x,y),key(nx,ny)));
 }
}
function pathOnFloor(from,to) {
 const a=key(...from),b=key(...to),prev=new Map([[a,null]]),queue=[a];
 for(let i=0;i<queue.length&&!prev.has(b);i++) {
  const [x,y]=queue[i].split(',').map(Number);
  for(const [dx,dy] of steps) {const next=key(x+dx,y+dy);if(cells.has(next)&&!prev.has(next)&&!blockedLinks.has(pair(queue[i],next))){prev.set(next,queue[i]);queue.push(next);}}
 }
 if(!prev.has(b))return [];
 const route=[];for(let at=b;at!==null;at=prev.get(at))route.push(at.split(',').map(Number));return route.reverse();
}
function recommended(weight) {
 const cost={start:0},previous={};
 for(const n of nodes)for(const e of edges.filter(e=>e.from===n.id)) {
  if(cost[n.id]===undefined)continue;
  const next=byId[e.to],value=cost[n.id]+(weight[next.kind]??1);
  if(cost[next.id]===undefined||value<cost[next.id]){cost[next.id]=value;previous[next.id]=n.id;}
 }
 let ids=[];for(let id='boss';id;id=previous[id])ids.push(id);ids.reverse();
 const routeEdges=ids.slice(1).map((id,i)=>edges.find(e=>e.from===ids[i]&&e.to===id));
 return {ids,edges:routeEdges.map(e=>e.id),counts:ids.reduce((s,id)=>(s[byId[id].kind]=(s[byId[id].kind]||0)+1,s),{})};
}
const examples={quiet:recommended({battle:4,elite:20,event:1,shop:1,rest:1,treasure:1}),risk:recommended({battle:3,elite:-12,event:2,shop:2,rest:0,treasure:-3}),events:recommended({battle:3,elite:10,event:-8,shop:2,rest:1,treasure:1})};
const errors=[];
if(nodes.length!==55)errors.push('node count');
for(const e of edges) {
 if(!pathOnFloor([byId[e.from].x,byId[e.from].y],[byId[e.to].x,byId[e.to].y]).length)errors.push(`not reachable: ${e.id}`);
 for(let i=1;i<e.points.length;i++)if(e.points[i][0]!==e.points[i-1][0]&&e.points[i][1]!==e.points[i-1][1])errors.push('non grid edge');
}
for(let i=0;i<nodes.length;i++)for(let j=i+1;j<nodes.length;j++){
 const a=nodes[i],b=nodes[j];if(Math.abs(a.x-b.x)<(a.w+b.w)/2&&Math.abs(a.y-b.y)<(a.h+b.h)/2)errors.push(`overlap: ${a.id}/${b.id}`);
}
const counts=Object.fromEntries(Object.keys(types).map(t=>[t,nodes.filter(n=>n.kind===t).length]));
const ways={start:1};for(const n of nodes)for(const e of edges.filter(e=>e.from===n.id))ways[e.to]=(ways[e.to]||0)+(ways[n.id]||0);
const report={status:'spatial study; not integrated gameplay',nodes:nodes.length,edges:edges.length,physicalWalkCells:cells.size,crossWaterConnections:edges.filter(e=>e.waterBridge).length,progressionPaths:ways.boss,counts,examples,errors,backtrackingAllowed:true,hiddenBarriers:0,oneWayMechanism:'not selected; intentionally absent',warning:'Directed examples describe planning only. The physical floor is bidirectional and can permit revisits and additional exploration.'};
fs.writeFileSync(path.join(out,'layout.json'),JSON.stringify({version:1,bounds:[0,0,66,108],nodes,edges,walkCells:[...cells].map(s=>s.split(',').map(Number)),wallBoundaries:[...blockedLinks],raisedPlantBeds:[...beds].map(s=>s.split(',').map(Number)),examples},null,2)+'\n');
fs.writeFileSync(path.join(out,'validation.json'),JSON.stringify(report,null,2)+'\n');
if(errors.length)throw new Error(errors.join('\n'));

// Engineering drawing: every pale stone cell below is actually traversable.
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const poly=ps=>ps.map(p=>p.join(',')).join(' ');
let svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -3 70 114" id="garden" role="img" aria-label="55节点水院园林空间草案"><defs><pattern id="water" width="5" height="4" patternUnits="userSpaceOnUse"><path d="M.4 1h1.1m1.4 2h.8" stroke="#477279" stroke-width=".065" opacity=".32"/></pattern><pattern id="tile" width="1" height="1" x=".5" y=".5" patternUnits="userSpaceOnUse"><path d="M0 0h1v1" fill="none" stroke="#283c40" stroke-width=".035"/></pattern><pattern id="roof" width=".65" height=".65" patternUnits="userSpaceOnUse"><path d="M0 0v.65" stroke="#3b5557" stroke-width=".055"/></pattern></defs><rect x="-2" y="-3" width="70" height="114" fill="#101e24"/><rect x=".5" y=".5" width="65" height="107" rx="2" fill="#16363e" stroke="#080f13" stroke-width=".7"/><rect x="1" y="1" width="64" height="106" rx="1.8" fill="url(#water)"/><g font-family="Microsoft YaHei, sans-serif">`;
// Broad enclosing wall and sparse windows communicate the outer garden limit.
for(const side of [0,1])for(let y=6;y<105;y+=8)svg+=`<rect x="${side?64.9:.3}" y="${y}" width=".8" height="2.1" fill="#496061" stroke="#09161c" stroke-width=".12"/><path d="M${side?64.9:.3} ${y}l.8 2.1m-.8 0l.8-2.1" stroke="#10252a" stroke-width=".1"/>`;
svg+=`<text x="33" y="56" fill="#628486" font-size="1.25" text-anchor="middle" writing-mode="vertical-rl" letter-spacing=".8">中 池 水 口</text>`;
for(const [left,top,width,height]of bankRects)svg+=`<rect x="${left-.5}" y="${top-.5}" width="${width}" height="${height}" fill="#465044"/>`;
for(const [i,group]of bedGroups.entries()){
 const pond=group.length<140&&group.length>22&&i%4===0;
 const fill=pond?'#1b3f45':'#293c32';
 for(const k of group){const[x,y]=k.split(',').map(Number);svg+=`<rect x="${x-.5}" y="${y-.5}" width="1" height="1" fill="${fill}"/>`;}
 let boundary='';
 for(const k of group){const[x,y]=k.split(',').map(Number);for(const[dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]])if(!beds.has(key(x+dx,y+dy))){boundary+=dx?`M${x+dx*.5},${y-.5}v1`:`M${x-.5},${y+dy*.5}h1`;}}
 svg+=`<path d="${boundary}" stroke="#7b7e66" stroke-width=".12" fill="none"/>`;
 for(const k of group){const[x,y]=k.split(',').map(Number);if((x*17+y*11)%29!==0)continue;if(pond)svg+=`<path d="M${x-.3},${y}a.55.3 0 1 0 .7-.3l-.4.2z" fill="#4b6951" stroke="#142f31" stroke-width=".07"/>`;else svg+=`<path d="M${x},${y-.5}l-.6.85h1.2zM${x},${y-.15}l-.7.85h1.4z" fill="${y%4===0?'#7a4540':'#3e5947'}" stroke="#1c2f29" stroke-width=".08"/>`;}
}
// A single connected embankment for each floor footprint; no fake walkable lawn.
for(const k of cells) {const [x,y]=k.split(',').map(Number);svg+=`<rect x="${x-.55}" y="${y-.55}" width="1.1" height="1.1" fill="#0c2027"/>`;}
for(const k of cells) {const [x,y]=k.split(',').map(Number);svg+=`<rect x="${x-.5}" y="${y-.5}" width="1" height="1" fill="#5e6054"/>`;}
svg+=`<g class="planning-lines" opacity=".62">`;
for(const e of edges)svg+=`<polyline id="edge-${e.id}" class="route-edge" points="${poly(e.points)}" fill="none" stroke="#b9a16e" stroke-width=".10" stroke-linejoin="round"/>`;
svg+='</g>';
for(const e of edges.filter(e=>e.waterBridge)) {
 const mid=e.points[1][1],a=e.points[1][0],b=e.points[2][0];
 svg+=`<g class="bridge"><path d="M${a},${mid-.64}H${b}M${a},${mid+.64}H${b}" stroke="#688083" stroke-width=".14" fill="none"/>`;
 for(let x=Math.min(a,b)+1;x<Math.max(a,b);x+=2)svg+=`<path d="M${x},${mid-.68}v1.36" stroke="#142e35" stroke-width=".06"/>`;
 svg+='</g>';
}
// Clear slab pattern is separate from the route overlay.
for(const n of nodes) {
 const x=n.x-n.w/2,y=n.y-n.h/2;
 const roofed=['shop','rest','start','boss'].includes(n.kind)||(n.kind==='event'&&n.row%2===0);
 svg+=`<g class="node" data-node="${n.id}" tabindex="0" role="button" aria-label="${esc(n.name)}，${types[n.kind]}"><title>${n.number}. ${esc(n.name)} / ${types[n.kind]} / ${n.w}×${n.h} 格</title><rect x="${x}" y="${y}" width="${n.w}" height="${n.h}" fill="url(#tile)"/>`;
 // Walls have actual openings at north and south, aligned with walk cells.
 svg+=`<path d="M${n.x-.7},${y}H${x}V${y+n.h}H${n.x-.7}M${n.x+.7},${y}H${x+n.w}V${y+n.h}H${n.x+.7}" stroke="#0a191e" stroke-width=".25" fill="none"/>`;
 for(const yy of [y,y+n.h])for(const xx of [n.x-.85,n.x+.85])svg+=`<rect x="${xx-.15}" y="${yy-.15}" width=".3" height=".3" fill="#ae9362"/>`;
 if(roofed)svg+=`<g class="roof"><rect x="${x+.35}" y="${y+.15}" width="${n.w-.7}" height="${n.h-.3}" fill="#1a3338" opacity=".83" stroke="#080f15" stroke-width=".13"/><rect x="${x+.35}" y="${y+.15}" width="${n.w-.7}" height="${n.h-.3}" fill="url(#roof)"/><path d="M${x+.1},${n.y}H${x+n.w-.1}" stroke="#9a8051" stroke-width=".07"/></g>`;
 else {
  // A rock/tree planter inside the court leaves the main passage unobstructed.
  svg+=`<path d="M${x+.4} ${y+.45}h1.05v${n.h-.9}h-1.05z" fill="#303e33" stroke="#172a29" stroke-width=".08"/>`;
  if(n.row%3===0)svg+=`<path d="M${x+.45} ${y+.9}l.6-.65.55.75-.4.65-.7-.2z" fill="#765d4e" stroke="#1b2728" stroke-width=".08"/>`;
 }
 svg+=`<rect class="node-card" x="${n.x-1.2}" y="${n.y-.85}" width="2.4" height="1.7" rx=".2" fill="#11232a" stroke="${colors[n.kind]}" stroke-width=".09"/><text x="${n.x}" y="${n.y+.4}" fill="${colors[n.kind]}" text-anchor="middle" font-size="1.15">${symbols[n.kind]}</text><text x="${x+.35}" y="${y+.95}" fill="#d0bf9e" font-size=".7">${String(n.number).padStart(2,'0')}</text></g>`;
}
// Corridor lamps and lilies remain outside the playable stone cells.
for(let r=0;r<15;r++) {
 const y=93-r*6;
 for(const x of [16,50])if(!cells.has(key(x,y)))svg+=`<g fill="${r%3===0?'#964a40':'#3c5b49'}" stroke="#0e252a" stroke-width=".08"><path d="M${x},${y}a.6.4 0 1 0 .9-.4l-.5.25z"/><path d="M${x+1.3},${y+.7}a.35.26 0 1 0 .5-.2z"/></g>`;
}
svg+=`<g id="walk-route"></g><g id="walker" transform="translate(33 104)"><circle r=".8" fill="#e6c479" opacity=".2"/><circle r=".35" fill="#e8d8b0" stroke="#0b1a20" stroke-width=".1"/><path d="M-.18.12L0-.4l.2.52" stroke="#9e4037" stroke-width=".15" fill="none"/></g><text x="33" y="110" text-anchor="middle" fill="#aebcae" font-size=".9">1 格 = 1 步 · 淡石地可走 · 池水与实墙不可穿越</text></g></svg>`;
fs.writeFileSync(path.join(out,'layout.svg'),svg+'\n');
const html=`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>55节点园林空间试排</title><style>
*{box-sizing:border-box}body{margin:0;background:#0c171d;color:#dacba9;font:15px/1.7 'Microsoft YaHei',sans-serif}main{max-width:1350px;margin:auto;padding:28px;display:grid;grid-template-columns:minmax(0,840px) 320px;gap:28px}h1{font-size:24px;line-height:1.4;margin:8px 0 14px}h2{font-size:16px;margin:24px 0 10px;color:#d1b77f}p{color:#a8b9b3}small,.muted{font-size:12px;color:#8da4a2}.map{min-width:0;border:1px solid #31474a;background:#101e24}.map svg{display:block;width:100%;height:auto;max-height:calc(100vh - 100px)}aside{position:sticky;top:24px;align-self:start}button{font:inherit;color:#dacba9;background:#1b3036;border:1px solid #405759;min-height:46px;border-radius:3px;padding:8px 12px;cursor:pointer;text-align:left;width:100%;margin:4px 0}button:hover,button[aria-pressed=true]{border-color:#d6b476;background:#34443e}button:focus-visible,.node:focus-visible{outline:2px solid #ddc38b}.metrics{display:flex;gap:24px;padding:14px 0;border-block:1px solid #344a4d}.metrics b{display:block;font-size:27px;color:#d6b476}.metrics span{font-size:12px;color:#9fb3af}.legend{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:12px 0}.legend span{text-align:center;font-size:12px}.legend i{display:block;font-style:normal;font-size:19px}.node{cursor:pointer}.node:hover .node-card,.node:focus .node-card{stroke:#f2d9a6;stroke-width:.2}.note{border-left:2px solid #a64d40;padding:0 0 0 12px;color:#b6c3ba;font-size:13px}#detail{min-height:95px;padding:12px;background:#14262c;font-size:13px}#route-info{min-height:70px;font-size:13px}.toggles label{display:block;font-size:13px;line-height:2.1;cursor:pointer}input{accent-color:#b49864}#status{font-size:12px;color:#b9c4b5;min-height:50px}.caption{padding:8px 14px;font-size:12px;color:#9eb2ac;border-top:1px solid #31474a}a{color:#d6b476}@media(max-width:850px){main{grid-template-columns:1fr;padding:12px;gap:14px}.map svg{max-height:none}aside{position:static}.legend{grid-template-columns:repeat(8,1fr)}}
</style><main><section><div class="map">${svg}<div class="caption">平面讨论稿 · 使用真实四向格子试走 · 非实机美术 · 未接入正式地图</div></div></section><aside><small>墨池 · 园林空间试排 / 01</small><h1>55 个停靠点，<br>先让路在空间上成立。</h1><p>临水院落与曲廊串联。门洞、桥和石地决定能走哪里；所有道路双向，选择后不凭空封路。</p><div class="metrics"><div><b>55</b><span>整图节点</span></div><div><b>17</b><span>示例路线节点</span></div><div><b>${report.crossWaterConnections}</b><span>横向跨池连接</span></div></div><div class="legend">${Object.keys(types).map(t=>`<span><i style="color:${colors[t]}">${symbols[t]}</i>${types[t]}</span>`).join('')}</div><h2>先比较三条推进路线</h2><button data-route="quiet">较少战斗 · 多服务停靠</button><button data-route="risk">多精英 · 争取高收益</button><button data-route="events">多事件 · 寻找构筑变化</button><button id="clear">取消路线强调</button><div id="route-info" aria-live="polite">金线为规划连接；实际走格不受推荐路线限制。点击任意节点查看并试走。</div><h2>点击节点，查看与试走</h2><div id="detail" aria-live="polite">当前在入园门厅。所有 55 个节点均已通过实际地面寻路检查。</div><div id="status" aria-live="polite"></div><button id="reset">回到入口</button><div class="toggles"><label><input id="roofs" type="checkbox" checked>显示建筑屋顶示意</label><label><input id="routes" type="checkbox" checked>显示规划连接</label></div><p class="note">本版允许回头，也允许绕行探索更多支路。因此尚不能直接套用尖塔的“选一边就永久放弃另一边”。这是需要讨论的玩法取舍，图中没有用隐形墙掩盖。</p><p class="muted">15 个推进深度带只用于统计，不是游戏里的楼层或禁行线。连廊相接处均可转向。节点种类为示例编排，尚未约束事件次数与实际奖励。</p></aside></main><script>
const data=${JSON.stringify({nodes,edges,cells:[...cells],blockedLinks:[...blockedLinks],examples,types})};
const byId=Object.fromEntries(data.nodes.map(n=>[n.id,n]));const cells=new Set(data.cells),blockedLinks=new Set(data.blockedLinks);let player=[33,104],walk=[],clock=0,visited=new Set(['start']);
function findPath(a,b){const key=p=>p.join(',');const prev=new Map([[key(a),null]]),q=[key(a)],goal=key(b);for(let i=0;i<q.length&&!prev.has(goal);i++){const[x,y]=q[i].split(',').map(Number);for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const k=[x+dx,y+dy].join(',');if(cells.has(k)&&!prev.has(k)&&!blockedLinks.has([q[i],k].sort().join('|'))){prev.set(k,q[i]);q.push(k)}}}if(!prev.has(goal))return[];let route=[];for(let at=goal;at!==null;at=prev.get(at))route.push(at.split(',').map(Number));return route.reverse()}
function select(id){const n=byId[id];document.getElementById('detail').textContent=n.number+'. '+n.name+' · '+data.types[n.kind]+'；落脚范围 '+n.w+'×'+n.h+' 格。入口和出口均为场景上的实际门洞。';const path=findPath(player,[n.x,n.y]);walk=path.slice(1);document.getElementById('walk-route').innerHTML=path.length?'<polyline points="'+path.map(p=>p.join(',')).join(' ')+'" stroke="#f0d291" stroke-width=".18" fill="none"/>':'';document.getElementById('status').textContent=path.length?'实际地面寻路：'+(path.length-1)+' 步。可随时点击另一节点改道。':'这里没有实际相通的道路。'}
function example(which){const sample=data.examples[which];document.querySelectorAll('[data-route]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.route===which));document.querySelectorAll('.route-edge').forEach(el=>{const chosen=sample.edges.includes(el.id.slice(5));el.setAttribute('stroke',chosen?'#f0cb7f':'#6f8275');el.setAttribute('stroke-width',chosen?'.28':'.08');el.setAttribute('opacity',chosen?'1':'.3')});document.getElementById('route-info').textContent='这条示例共 '+sample.ids.length+' 个节点：'+Object.entries(sample.counts).map(([kind,count])=>data.types[kind]+' '+count).join('，')+'。示例只提供计划，不限制自由回走。';}
document.querySelectorAll('.node').forEach(el=>{el.onclick=()=>select(el.dataset.node);el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select(el.dataset.node)}}});document.querySelectorAll('[data-route]').forEach(b=>b.onclick=()=>example(b.dataset.route));document.getElementById('clear').onclick=()=>{document.querySelectorAll('[data-route]').forEach(b=>b.setAttribute('aria-pressed','false'));document.querySelectorAll('.route-edge').forEach(el=>{el.setAttribute('stroke','#b9a16e');el.setAttribute('stroke-width','.10');el.setAttribute('opacity','1')});document.getElementById('route-info').textContent='所有连接均展示；可以回头。';};document.getElementById('reset').onclick=()=>{player=[33,104];walk=[];visited=new Set(['start']);document.getElementById('walker').setAttribute('transform','translate(33 104)');document.getElementById('walk-route').replaceChildren();document.getElementById('status').textContent='已回到入口。';};document.getElementById('roofs').onchange=e=>document.querySelectorAll('.roof').forEach(el=>el.style.display=e.target.checked?'':'none');document.getElementById('routes').onchange=e=>document.querySelectorAll('.planning-lines').forEach(el=>el.style.display=e.target.checked?'':'none');
function tick(time){if(walk.length&&time-clock>90){clock=time;player=walk.shift();document.getElementById('walker').setAttribute('transform','translate('+player.join(' ')+')');for(const n of data.nodes)if(n.x===player[0]&&n.y===player[1])visited.add(n.id);if(!walk.length)document.getElementById('status').textContent='已到达。共踏访 '+visited.size+' 个停靠点，可沿原路返回。此处不结算真实奖励。';}requestAnimationFrame(tick)}requestAnimationFrame(tick);
window.spatialStudy={data,findPath,select,example,get player(){return player},get visited(){return [...visited]}};
</script></html>`;
fs.writeFileSync(path.join(out,'preview.html'),html+'\n');
console.log(JSON.stringify({nodes:report.nodes,edges:report.edges,paths:report.progressionPaths,walkCells:cells.size,waterBridges:report.crossWaterConnections,examples:Object.fromEntries(Object.entries(examples).map(([k,v])=>[k,v.counts])),errors}));
