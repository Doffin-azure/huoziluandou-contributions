/* Editable geometry study. All painted faces share one world-to-screen projection. */
(function (root) {
  'use strict';
  const palette = {
    background: '#192c28', ink: '#162e28', ground: '#53675a', groundFront: '#354a3e',
    groundSide: '#2b4037', joint: '#405747', body: '#3e6357', bodySide: '#2e4c43',
    lid: '#64836e', lidFront: '#486b58', lidSide: '#345745', bronze: '#b6a073',
    hole: '#273f32', caption: '#ded4b7', quiet: '#9dac99', guideX: '#e1c58a', guideZ: '#8bb9af'
  };
  const defaults = Object.freeze({ x: 1.55, z: 1.52, zoom: 1, guides: false });
  const spec = Object.freeze({
    yaw: 12, pitch: 43, unit: 212, center: [640, 429],
    body: { bottom: 0, top: .40, bottomWidth: .90, topWidth: .96, depth: .57 },
    lid: { bottom: .40, top: .485, width: 1.045, depth: .66, corner: .036 }
  });
  const format = n => Number(n.toFixed(3));
  const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
  const sub = (a,b) => a.map((v,i)=>v-b[i]);
  const dot = (a,b) => a.reduce((v,n,i)=>v+n*b[i],0);
  function projection(zoom=1) {
    const yaw=spec.yaw*Math.PI/180,pitch=spec.pitch*Math.PI/180,unit=spec.unit*zoom;
    const right=[Math.cos(yaw),0,-Math.sin(yaw)];
    const down=[Math.sin(yaw)*Math.sin(pitch),-Math.cos(pitch),Math.cos(yaw)*Math.sin(pitch)];
    const toward=[Math.sin(yaw)*Math.cos(pitch),Math.sin(pitch),Math.cos(yaw)*Math.cos(pitch)];
    const project=v=>{
      const q=[v[0]-1.5,v[1],v[2]-1.5];
      return [spec.center[0]+dot(q,right)*unit,spec.center[1]+dot(q,down)*unit];
    };
    return {project,toward,right,down,unit};
  }
  function rectangle(x0,z0,x1,z1,y) { return [[x0,y,z0],[x1,y,z0],[x1,y,z1],[x0,y,z1]]; }
  function bevelRectangle(width,depth,corner,y) {
    const x=width/2,z=depth/2,c=corner;
    return [[-x+c,y,-z],[x-c,y,-z],[x,y,-z+c],[x,y,z-c],
      [x-c,y,z],[-x+c,y,z],[-x,y,z-c],[-x,y,-z+c]];
  }
  function chestGeometry(x,z) {
    const b=spec.body,l=spec.lid;
    const bottom=rectangle(-b.bottomWidth/2,-b.depth/2,b.bottomWidth/2,b.depth/2,b.bottom);
    const upper=rectangle(-b.topWidth/2,-b.depth/2,b.topWidth/2,b.depth/2,b.top);
    const lowerLid=bevelRectangle(l.width,l.depth,l.corner,l.bottom);
    const upperLid=bevelRectangle(l.width,l.depth,l.corner,l.top);
    const faces=[];
    const face=(id,vertices,color)=>faces.push({id,vertices:vertices.map(v=>[v[0]+x,v[1],v[2]+z]),color});
    // Vertex winding points outwards, so visible sides can be selected from camera direction.
    for(let i=0;i<4;i++) {
      const next=(i+1)%4;
      face(`body-${i}`,[bottom[i],upper[i],upper[next],bottom[next]],i===2?palette.body:palette.bodySide);
    }
    face('lid-top',upperLid.slice().reverse(),palette.lid);
    for(let i=0;i<8;i++) {
      const next=(i+1)%8;
      face(`lid-${i}`,[lowerLid[i],upperLid[i],upperLid[next],lowerLid[next]],i===4?palette.lidFront:palette.lidSide);
    }
    // One plain lock plate, in the FRONT face's coordinates. No baked perspective image.
    const front=l.depth/2+.004;
    const lock=[[-.065,.445,front],[.065,.445,front],[.065,.305,front],
      [.035,.277,front],[-.065,.277,front]];
    return {faces,foot:bottom.map(v=>[v[0]+x,0,v[2]+z]),
      top:upperLid.map(v=>[v[0]+x,v[1],v[2]+z]),
      lock:lock.map(v=>[v[0]+x,v[1],v[2]+z]),
      hole:[[-.012,.37,front+.002],[.012,.37,front+.002],[.012,.328,front+.002],[-.012,.328,front+.002]].map(v=>[v[0]+x,v[1],v[2]+z])};
  }
  function hull(points) {
    const sorted=points.slice().sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
    const turn=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
    const half=values=>{const out=[];for(const p of values){while(out.length>1&&turn(out.at(-2),out.at(-1),p)<=0)out.pop();out.push(p)}return out};
    return [...half(sorted).slice(0,-1),...half(sorted.slice().reverse()).slice(0,-1)];
  }
  function drawing() {
    const parts=[];
    const points=p=>p.map(v=>v.map(format).join(',')).join(' ');
    const polygon=(p,color,options={})=>parts.push(`<polygon points="${points(p)}" fill="${color}" stroke="${options.stroke??palette.ink}" stroke-width="${options.width??1.8}" stroke-linejoin="round"${options.opacity===undefined?'':` opacity="${options.opacity}"`}${options.id?` data-face="${options.id}"`:''}/>`);
    const line=(p,color=palette.ink,width=1.3,dash='')=>parts.push(`<polyline points="${points(p)}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"${dash?` stroke-dasharray="${dash}"`:''}/>`);
    const text=(x,y,content,size=15,color=palette.caption)=>parts.push(`<text x="${x}" y="${y}" fill="${color}" font-family="Microsoft YaHei, sans-serif" font-size="${size}">${content}</text>`);
    return {parts,polygon,line,text};
  }
  function render(input={}) {
    const state={...defaults,...input},camera=projection(state.zoom),p=camera.project,d=drawing();
    d.parts.push(`<rect width="1280" height="800" fill="${palette.background}"/>`);
    d.text(112,61,'墨池 · 结构与色块小样',23);
    d.text(112,91,'3 × 3   /   共用投影 · 平涂 · 一个锁扣',14,palette.quiet);
    const perimeter=[[0,0,0],[3,0,0],[3,0,3],[1.02,0,3],[.99,0,2.98],[.87,0,3],[0,0,3]];
    const far=p([3,0,0]),corner=p([3,0,3]),thickness=p([0,-.075,0])[1]-p([0,0,0])[1];
    d.polygon([far,corner,[corner[0],corner[1]+thickness],[far[0],far[1]+thickness]],palette.groundSide);
    const near=perimeter.slice(2).map(p);
    d.polygon([...near,...near.slice().reverse().map(v=>[v[0],v[1]+thickness])],palette.groundFront);
    d.polygon(perimeter.map(p),palette.ground,{width:2.4});
    // Quiet stone divisions. These are not the three-by-three logical cell borders.
    d.polygon(rectangle(0,0,3,.91,0).map(p),'#586b5c',{stroke:'none'});
    d.polygon([[0,0,1.96],[1.68,0,1.96],[1.68,0,3],[1.02,0,3],[.99,0,2.98],[.87,0,3],[0,0,3]].map(p),'#506455',{stroke:'none'});
    d.line([[0,0,.91],[3,0,.91]].map(p),palette.joint,1);
    d.line([[0,0,1.96],[3,0,1.96]].map(p),palette.joint,1);
    d.line([[1.68,0,1.96],[1.68,0,3]].map(p),palette.joint,1);
    // Restore only the outside outline; no cell receives a decorative frame.
    d.line([...perimeter,perimeter[0]].map(p),palette.ink,2.4);
    const chest=chestGeometry(state.x,state.z);
    const groundShadow=chest.top.map(v=>p([v[0]+v[1]*.55,0,v[2]+v[1]*.33]));
    d.polygon(hull([...chest.foot.map(p),...groundShadow]),'#203c30',{stroke:'none',opacity:.31});
    d.polygon(chest.foot.map(p),'#1f372b',{stroke:'none',opacity:.5});
    const visible=chest.faces.filter(face=>dot(cross(sub(face.vertices[1],face.vertices[0]),sub(face.vertices[2],face.vertices[0])),camera.toward)>1e-9);
    visible.sort((a,b)=>a.vertices.reduce((sum,v)=>sum+dot(v,camera.toward),0)/a.vertices.length-b.vertices.reduce((sum,v)=>sum+dot(v,camera.toward),0)/b.vertices.length);
    // One shared contour surrounds the whole object; inner seams use a lighter pen weight.
    const contour=hull(visible.flatMap(face=>face.vertices.map(p)));
    d.polygon(contour,palette.ink,{stroke:palette.ink,width:5.2});
    for(const face of visible)d.polygon(face.vertices.map(p),face.color,{width:1.5,id:face.id});
    d.polygon(chest.lock.map(p),palette.bronze,{width:1.6,id:'lock'});
    d.polygon(chest.hole.map(p),palette.hole,{stroke:'none'});
    if(state.guides) {
      for(let n=0;n<=3;n++) {
        d.line([[n,.002,0],[n,.002,3]].map(p),palette.guideZ,.9,'5 7');
        d.line([[0,.002,n],[3,.002,n]].map(p),palette.guideX,.9,'5 7');
      }
      const front=spec.lid.depth/2+state.z;
      d.line([[state.x-.72,spec.lid.top,front],[state.x+.72,spec.lid.top,front]].map(p),palette.guideX,1.5,'5 5');
      d.line([[state.x+.523,spec.lid.top,state.z-.58],[state.x+.523,spec.lid.top,state.z+.58]].map(p),palette.guideZ,1.5,'5 5');
      const origin=p([state.x,0,state.z]);
      d.parts.push(`<circle cx="${format(origin[0])}" cy="${format(origin[1])}" r="4" fill="none" stroke="${palette.caption}" stroke-width="1.2"/>`);
      d.text(112,740,'虚线：地面格线与箱盖边线共用方向',15);
    } else d.text(112,740,'箱体、箱盖、锁扣和地面由同一组空间坐标绘制',15);
    d.text(112,768,'几何与简化画法验证 · 可编辑矢量 · 无生成贴图',13,palette.quiet);
    return `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="800" viewBox="0 0 1280 800" role="img" aria-label="三乘三安静石地与共用投影的极简字匣">${d.parts.join('')}</svg>`;
  }
  function exportChest() {
    const c=projection(),p=c.project,d=drawing(),mesh=chestGeometry(1.5,1.5);
    const visible=mesh.faces.filter(face=>dot(cross(sub(face.vertices[1],face.vertices[0]),sub(face.vertices[2],face.vertices[0])),c.toward)>1e-9);
    visible.sort((a,b)=>a.vertices.reduce((s,v)=>s+dot(v,c.toward),0)/a.vertices.length-b.vertices.reduce((s,v)=>s+dot(v,c.toward),0)/b.vertices.length);
    const all=visible.flatMap(face=>face.vertices.map(p)),xs=all.map(v=>v[0]),ys=all.map(v=>v[1]);
    const x=Math.min(...xs)-6,y=Math.min(...ys)-6,w=Math.max(...xs)-x+6,h=Math.max(...ys)-y+6;
    d.polygon(hull(all),palette.ink,{width:5.2});
    for(const face of visible)d.polygon(face.vertices.map(p),face.color,{width:1.5,id:face.id});
    d.polygon(mesh.lock.map(p),palette.bronze,{width:1.6});d.polygon(mesh.hole.map(p),palette.hole,{stroke:'none'});
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${format(w)}" height="${format(h)}" viewBox="${[x,y,w,h].map(format).join(' ')}">${d.parts.join('')}</svg>`;
  }
  const api={render,projection,chestGeometry,exportChest,defaults,spec,palette};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  else root.ProjectionStudy=api;
})(typeof globalThis==='undefined'?this:globalThis);
