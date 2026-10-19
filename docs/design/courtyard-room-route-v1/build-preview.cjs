// Design diagram only. Does not load or modify game state.
const fs = require('fs');
const path = require('path');
const out = __dirname;
const types = {start:'起点',battle:'普通战',elite:'精英',event:'事件',rest:'火堆',treasure:'宝藏',shop:'商店',boss:'首领'};
const specs = [
 ['s','start',5,49,4,4,'门前小室'],['a','battle',14,47,6,5,'巡守石庭'],
 ['b','event',24,39,5,4,'问字小院'],['c','battle',34,39,6,5,'临池石庭'],
 ['d','battle',24,53,6,5,'廊下巡守'],['e','shop',35,53,6,5,'青铜字摊'],
 ['f','treasure',45,47,4,4,'水榭藏匣'],['g','elite',40,31,7,6,'镇碑庭'],
 ['h','event',40,21,5,4,'残碑问事'],['i','battle',54,33,6,5,'东岸巡守'],
 ['j','rest',54,21,5,5,'息灯小院'],['k','battle',47,11,6,5,'合院巡守'],
 ['l','elite',31,5,7,6,'精英镇守'],['m','treasure',17,5,4,4,'偏庭藏匣'],
 ['n','event',31,17,5,4,'照壁问字'],['o','battle',17,17,6,5,'回廊巡守'],
 ['p','rest',6,11,5,5,'终前息庭'],['q','boss',6,29,9,7,'首领终庭']
];
const rooms = specs.map(([id,kind,x,z,w,h,name],index)=>({id,kind,x,z,w,h,name,index:index+1}));
const byId = Object.fromEntries(rooms.map(r=>[r.id,r]));
const edge = (from,to,points,group=null,option=null)=>({from,to,points,group,option});
const links = [
 edge('s','a',[[7,49],[9,49],[9,47],[11,47]]),
 edge('a','b',[[14,44.5],[14,42],[19.5,42],[19.5,39],[21.5,39]],0,0),
 edge('b','c',[[26.5,39],[31,39]],0,0),
 edge('c','f',[[37,39],[41,39],[41,47],[43,47]],0,0),
 edge('a','d',[[14,49.5],[14,53],[21,53]],0,1),
 edge('d','e',[[27,53],[32,53]],0,1),
 edge('e','f',[[38,53],[45,53],[45,49]],0,1),
 edge('f','g',[[45,45],[45,31],[43.5,31]],1,0),
 edge('g','h',[[40,28],[40,23]],1,0),
 edge('h','k',[[40,19],[40,18.2],[47,18.2],[47,13.5]],1,0),
 edge('f','i',[[47,47],[54,47],[54,35.5]],1,1),
 edge('i','j',[[54,30.5],[54,23.5]],1,1),
 edge('j','k',[[54,18.5],[54,11],[50,11]],1,1),
 edge('k','l',[[47,8.5],[47,5],[34.5,5]],2,0),
 edge('l','m',[[27.5,5],[19,5]],2,0),
 edge('m','p',[[15,5],[6,5],[6,8.5]],2,0),
 edge('k','n',[[44,11],[36,11],[36,17],[33.5,17]],2,1),
 edge('n','o',[[28.5,17],[20,17]],2,1),
 edge('o','p',[[14,17],[11,17],[11,11],[8.5,11]],2,1),
 edge('p','q',[[6,13.5],[6,25.5]])
];
const choices = [
 [['b','c'],['d','e']], [['g','h'],['i','j']], [['l','m'],['n','o']]
];
const length = e => e.points.slice(1).reduce((s,p,i)=>s+Math.abs(p[0]-e.points[i][0])+Math.abs(p[1]-e.points[i][1]),0);
function validate() {
 const errors=[];
 const rect = (r,pad=0)=>[r.x-r.w/2-pad,r.z-r.h/2-pad,r.x+r.w/2+pad,r.z+r.h/2+pad];
 for(let i=0;i<rooms.length;i++) for(let j=i+1;j<rooms.length;j++) {
  const a=rect(rooms[i],.6), b=rect(rooms[j],.6);
  if(a[0]<b[2]&&a[2]>b[0]&&a[1]<b[3]&&a[3]>b[1]) errors.push(`房间占地碰撞: ${rooms[i].id}/${rooms[j].id}`);
 }
 for(const e of links) {
  if(length(e)>20) errors.push(`连接过长: ${e.from}/${e.to}`);
  for(let n=1;n<e.points.length;n++) {
   const a=e.points[n-1],b=e.points[n];
   if(a[0]!==b[0]&&a[1]!==b[1]) errors.push('非正交通路');
   for(const room of rooms) {
    if([e.from,e.to].includes(room.id))continue;
    const box=rect(room,.45);
    const touches = a[0]===b[0]
     ? a[0]>box[0]&&a[0]<box[2]&&Math.max(a[1],b[1])>box[1]&&Math.min(a[1],b[1])<box[3]
     : a[1]>box[1]&&a[1]<box[3]&&Math.max(a[0],b[0])>box[0]&&Math.min(a[0],b[0])<box[2];
    if(touches) errors.push(`通路穿过无关房间: ${e.from}/${e.to} -> ${room.id}`);
   }
  }
 }
 // A crossing outside a room would imply an unregistered route connection.
 for(let i=0;i<links.length;i++) for(let j=i+1;j<links.length;j++) {
  const e=links[i],f=links[j];
  for(let x=1;x<e.points.length;x++) for(let y=1;y<f.points.length;y++) {
   const a=e.points[x-1],b=e.points[x],c=f.points[y-1],d=f.points[y];
   const v=a[0]===b[0], w=c[0]===d[0];
   if(v===w)continue;
   const vert=v?[a,b]:[c,d], hori=v?[c,d]:[a,b];
   if(vert[0][0]>Math.min(hori[0][0],hori[1][0])+.0001&&vert[0][0]<Math.max(hori[0][0],hori[1][0])-.0001&&hori[0][1]>Math.min(vert[0][1],vert[1][1])+.0001&&hori[0][1]<Math.max(vert[0][1],vert[1][1])-.0001)errors.push(`无关通路交叉: ${e.from}/${e.to} & ${f.from}/${f.to}`);
  }
 }
 const routes=[];
 for(let mask=0;mask<8;mask++) {
  const picks=[0,1,2].map(i=>(mask>>i)&1);
  const ids=['s','a',...choices[0][picks[0]],'f',...choices[1][picks[1]],'k',...choices[2][picks[2]],'p','q'];
  const selected=links.filter(e=>e.group===null||picks[e.group]===e.option);
  const counts={}; for(const id of ids)counts[byId[id].kind]=(counts[byId[id].kind]||0)+1;
  const walk=selected.reduce((s,e)=>s+length(e),0);
  if(ids.length!==12||(counts.battle||0)+(counts.elite||0)+counts.boss!==6||walk>130)errors.push(`路线节奏错误: ${mask}`);
  for(let g=0;g<3;g++)if(selected.filter(e=>e.group===g).reduce((s,e)=>s+length(e),0)>40)errors.push(`分支走廊累计过长: ${mask}/${g}`);
  routes.push({picks,rooms:ids,counts,corridor_length:walk});
 }
 if(errors.length)throw new Error(errors.join('\n'));
 return {kind:'design_diagram_not_runtime_test',room_count:rooms.length,link_count:links.length,routes,geometry_checks:'room reservations, unrelated-room corridor clearance, orthogonal crossings',runtime_validation:'not implemented'};
}
const report=validate();
fs.writeFileSync(path.join(out,'validation.json'),JSON.stringify(report,null,2)+'\n');
fs.writeFileSync(path.join(out,'layout.json'),JSON.stringify({schema:'design_sample_v1',bounds:[0,0,60,60],rooms,links},null,2)+'\n');
const s=16,ox=30,oy=90;
const xy=p=>`${ox+p[0]*s},${oy+p[1]*s}`;
const line=(points,attrs='')=>`<polyline points="${points.map(xy).join(' ')}" fill="none" ${attrs}/>`;
const colors={start:'#b4a378',battle:'#657577',elite:'#b54d48',event:'#8b9fa1',rest:'#8ea99e',treasure:'#be9a55',shop:'#baa47c',boss:'#d46050'};
const mainWater='M205 450C160 385 262 330 372 366S610 350 744 392S990 435 952 630S976 864 836 957S552 1032 398 990S156 1020 180 851S254 627 205 450Z';
const sideWater='M204 235C206 140 374 172 475 183S689 149 728 236S642 440 464 421S160 345 204 235Z';
let svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1020 1090" role="img" aria-label="十八房园林路线平面设计，按房间尺寸绘制，不是游戏实机">
<defs><pattern id="water" width="60" height="48" patternUnits="userSpaceOnUse"><path d="M2 20h15m26 18h10" stroke="#456365" stroke-width="1" opacity=".26"/></pattern><pattern id="slabs" width="32" height="32" patternUnits="userSpaceOnUse"><path d="M0 0h32v32" fill="none" stroke="#11242b" stroke-width="1" opacity=".5"/></pattern><mask id="water-union"><path d="${mainWater}" fill="white"/><path d="${sideWater}" fill="white"/></mask></defs>
<rect width="1020" height="1090" fill="#0a151d"/><g font-family="Microsoft YaHei,SimHei,sans-serif"><text x="30" y="34" fill="#d3c6a5" font-size="23">园林房间远征 · 固定调试样板</text><text x="30" y="59" fill="#8faaa8" font-size="13">仅用于拼接与流程验证 · 正式生成按种子变化路线、长度和房型 · 非实机</text>
<rect x="30" y="90" width="960" height="960" rx="30" fill="#263332" stroke="#596563" stroke-width="3"/>
<path d="${mainWater}" fill="none" stroke="#0d252c" stroke-width="10"/><path d="${sideWater}" fill="none" stroke="#0d252c" stroke-width="10"/>
<path d="${mainWater}" fill="#173b40"/><path d="${sideWater}" fill="#173b40"/>
<rect x="30" y="90" width="960" height="960" fill="url(#water)" mask="url(#water-union)"/>
<text x="420" y="549" text-anchor="middle" fill="#628486" font-size="25" letter-spacing="12">主池</text><text x="379" y="325" text-anchor="middle" fill="#628486" font-size="16" letter-spacing="8">支池</text>`;
// The two rooms on a branch share a courtyard terrace. The diagram separates
// their node doors, but does not turn every room into an isolated water island.
for(const [x,z,w,h] of [[20.7,35.8,17.1,6.4],[20,49.5,19,7.5],[35.8,18,8.4,16.8],[50.1,17.8,8.7,18.6],[13.7,1,21.6,8],[13.1,13.3,21.2,7.4]]){
 svg+=`<rect x="${ox+x*s}" y="${oy+z*s}" width="${w*s}" height="${h*s}" rx="13" fill="#293c3d" stroke="#12282d" stroke-width="4"/>`;
}
// Shared corridor geometry is separate from route emphasis and seal state.
for(const e of links) {
 const attrs=`data-group="${e.group??''}" data-option="${e.option??''}"`;
 let half=length(e)/2,arrowPoint,angle=0;
 for(let i=1;i<e.points.length;i++) {
  const a=e.points[i-1],b=e.points[i],distance=Math.abs(b[0]-a[0])+Math.abs(b[1]-a[1]);
  if(half<=distance){const t=half/distance;arrowPoint=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];angle=Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI;break;}
  half-=distance;
 }
 const arrow=`<path d="M-5-4L1 0l-6 4" transform="translate(${ox+arrowPoint[0]*s} ${oy+arrowPoint[1]*s}) rotate(${angle})" fill="none" stroke="#c8a568" stroke-width="2"/>`;
 svg+=`<g class="edge" ${attrs}>`+line(e.points,'stroke="#101f26" stroke-width="27" stroke-linejoin="round"')+line(e.points,'stroke="#4b5758" stroke-width="20" stroke-linejoin="round"')+line(e.points,'class="route-line" stroke="#a68f58" stroke-width="2" stroke-dasharray="4 6" opacity=".55"')+arrow+'</g>';
 if(e.group!==null) {
  for(const [index,p] of [e.points[0],e.points.at(-1)].entries()) {
   if(index===0&&!['a','f','k'].includes(e.from))continue;
   if(index===1&&!['f','k','p'].includes(e.to))continue;
   const n=index===0?e.points[1]:e.points.at(-2),dx=n[0]-p[0],dz=n[1]-p[1],len=Math.hypot(dx,dz),at=[p[0]+dx/len*.8,p[1]+dz/len*.8];
   svg+=`<g class="seal" ${attrs} style="display:none"><circle cx="${ox+at[0]*s}" cy="${oy+at[1]*s}" r="8" fill="#8b3034" stroke="#d78566"/><path d="M${ox+at[0]*s-3} ${oy+at[1]*s-3}l6 6m0-6l-6 6" stroke="#edc6a1" stroke-width="1.5"/></g>`;
  }
 }
}
for(const r of rooms) {
 const x=ox+(r.x-r.w/2)*s,y=oy+(r.z-r.h/2)*s,w=r.w*s,h=r.h*s,c=colors[r.kind];
 svg+=`<g class="room" data-room="${r.id}" tabindex="0"><title>${r.name} / ${types[r.kind]} / ${r.w}×${r.h}</title><rect x="${x-5}" y="${y-5}" width="${w+10}" height="${h+10}" rx="4" fill="#15252a" stroke="#050e15" stroke-width="2"/><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#46514f" stroke="${c}" stroke-width="2"/><rect x="${x+3}" y="${y+3}" width="${w-6}" height="${h-6}" fill="url(#slabs)"/><text x="${x+7}" y="${y+14}" font-size="10" fill="${c}">${r.id.toUpperCase()}</text><text x="${ox+r.x*s}" y="${oy+r.z*s-1}" text-anchor="middle" fill="#d3c6a5" font-size="15">${types[r.kind]}</text><text x="${ox+r.x*s}" y="${oy+r.z*s+19}" text-anchor="middle" fill="#9eafaa" font-size="11">${r.w} × ${r.h}</text></g>`;
}
// Draw real openings through the reservation outlines, rather than a line that
// visually runs into an intact wall. These marks do not change room footprints.
for(const e of links) for(const [at,n] of [[e.points[0],e.points[1]],[e.points.at(-1),e.points.at(-2)]]) {
 const vertical=at[0]===n[0],x=ox+at[0]*s,y=oy+at[1]*s;
 svg+=`<line x1="${x-(vertical?9:0)}" y1="${y-(vertical?0:9)}" x2="${x+(vertical?9:0)}" y2="${y+(vertical?0:9)}" stroke="#4b5758" stroke-width="12" pointer-events="none"/>`;
}
svg+=`<g fill="#a48e56" font-size="12"><text x="30" y="1075">院内地面包围盒；墙体/屋檐另留净空。金色虚线仅为规划路线标记，不代表游戏常驻UI。</text></g></g></svg>`;
fs.writeFileSync(path.join(out,'layout.svg'),svg+'\n');
const branchLabels=[['事件 → 普通战','普通战 → 商店'],['精英 → 事件','普通战 → 火堆'],['精英 → 宝藏','事件 → 普通战']];
const html=`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>园林房间远征 · 设计样板</title><style>
*{box-sizing:border-box}body{margin:0;background:#0a151d;color:#c8b894;font:15px/1.65 'Microsoft YaHei',sans-serif}.page{max-width:1460px;margin:auto;padding:20px;display:grid;grid-template-columns:minmax(600px,1020px) 340px;gap:24px}.map svg{width:100%;height:auto;display:block}.aside{padding-top:12px}h1{font-size:24px;margin:0 0 10px;font-weight:600}p{color:#a1b0aa}h2{font-size:16px;color:#c0a56b;font-weight:500;margin:26px 0 10px}button{display:block;text-align:left;width:100%;font:inherit;background:#1a2e33;border:1px solid #486062;color:#c8b894;padding:9px 12px;cursor:pointer;margin:7px 0;border-radius:3px}button:hover,button:focus-visible{border-color:#c8a568;outline:1px solid #c8a568}button[aria-pressed=true]{border-color:#c8a568;background:#374139}.small{font-size:12px;color:#8ca29f}.metrics{display:grid;grid-template-columns:1fr 1fr;gap:12px;border-top:1px solid #385257;border-bottom:1px solid #385257;padding:18px 0}.metrics b{font-size:25px;display:block;color:#c8a568}.room:hover rect,.room:focus rect{stroke:#ead1a4}.room:focus{outline:none}#room-info{min-height:75px}.note{border-left:2px solid #9c443d;padding-left:12px}a{color:#c0a56b}@media(max-width:950px){.page{grid-template-columns:1fr}.aside{padding:0 14px 24px}.map{min-width:0}}
</style><div class="page"><main class="map">${svg}</main><aside class="aside"><div class="small">结构与空间设计 · 非游戏实机</div><h1>固定样板，验证拼接</h1><p>保留实际行走与远近视差，用庭门、曲廊和桥连接房间。点击下方选项，比较路线。</p><div class="metrics"><div><b>18</b>整图房间</div><div><b>12</b>每路线房间</div><div><b>6</b>每路线战斗</div><div><b>3</b>分叉选择</div></div>${branchLabels.map((ls,g)=>`<h2>第${g+1}次选择</h2>${ls.map((label,o)=>`<button data-choice="${g},${o}" aria-pressed="false">${label}</button>`).join('')}`).join('')}<button id="reset">查看全部路线</button><p id="route-info" class="note" aria-live="polite">尚未选路。实际游戏中，跨过门槛后提交该段选择。</p><h2>房间规格</h2><div id="room-info" aria-live="polite">点击图中房间，查看院内尺寸和用途。</div><p class="small">红色封印表示未选连接的两端均关闭。已走路线可回看，奖励与火堆不重置。矩形为占地设计，不是最终建筑造型。</p><p class="small">正式地图拟采用16–22房、2–4次选路的受控随机；本页保留十八房固定样板。详见设计稿3A节。</p></aside></div><script>
const rooms=${JSON.stringify(rooms)},types=${JSON.stringify(types)},choices=${JSON.stringify(choices)},routes=${JSON.stringify(report.routes)};
let picks=[null,null,null];
function update(){document.querySelectorAll('[data-choice]').forEach(b=>{let[g,o]=b.dataset.choice.split(',').map(Number);b.setAttribute('aria-pressed',picks[g]===o)});document.querySelectorAll('.edge').forEach(e=>{let g=e.dataset.group;let selected=g===''||picks[+g]===null||picks[+g]===+e.dataset.option;e.style.opacity=selected?'1':'.24';let l=e.querySelector('.route-line');l.setAttribute('stroke',g!==''&&picks[+g]!==null&&selected?'#e1bb73':'#a68f58');l.setAttribute('stroke-width',g!==''&&picks[+g]!==null&&selected?'4':'2')});document.querySelectorAll('.seal').forEach(e=>{e.style.display=picks[+e.dataset.group]!==null&&picks[+e.dataset.group]!==+e.dataset.option?'':'none'});const info=document.getElementById('route-info');if(picks.every(x=>x!==null)){let r=routes.find(r=>r.picks.every((v,i)=>v===picks[i]));info.textContent='本路线：'+r.counts.battle+'场普通战、'+(r.counts.elite||0)+'场精英、1场首领；'+r.counts.rest+'处火堆，'+r.counts.treasure+'处宝藏。所有选择都保留首领前的休整。'}else info.textContent='已选择 '+picks.filter(x=>x!==null).length+' / 3 段。未选支路两端封门，不能从汇合房绕回。'}
document.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>{let[g,o]=b.dataset.choice.split(',').map(Number);picks[g]=o;update()});document.getElementById('reset').onclick=()=>{picks=[null,null,null];update()};document.querySelectorAll('.room').forEach(el=>{const show=()=>{let r=rooms.find(r=>r.id===el.dataset.room);document.getElementById('room-info').textContent=r.name+' · '+types[r.kind]+'，院内地面 '+r.w+' × '+r.h+' 格。墙体、屋檐和交互站位另外登记。'};el.onclick=show;el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();show()}}});update();
</script></html>`;
fs.writeFileSync(path.join(out,'preview.html'),html+'\n');
console.log(JSON.stringify({rooms:rooms.length,links:links.length,paths:report.routes.length,maxSingleCorridor:Math.max(...links.map(length)),maxRouteCorridors:Math.max(...report.routes.map(r=>r.corridor_length)),files:['layout.svg','layout.json','preview.html','validation.json']}));
