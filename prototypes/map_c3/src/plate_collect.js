// 排版 C3 · 拾字组词：地图上的字可收集，收来的字在排版台上组词形成 buff（依赖 plate.js）
// 地图记号：. 空  # 墨渍  R 目标字  E 敌  起/终/休/市 节点  其余汉字 = 散落的版字（可拾取）
const MAP = ["..R.#破.R..", ".热..护E..流.", "...#...收..", "起...休.火E精终", "..电...#破.币", ".市.能R..利..", "..资...R..."].map(r => [...r]);
const H = MAP.length, W = MAP[0].length, BW = 6, SPECIAL = ".#RE起终休市";
const isGlyph = ch => !SPECIAL.includes(ch);
const REWARD = {
  "0,2": { g: "金", text: "+15 金币", apply: () => s.gold += 15 },
  "0,7": { g: "盾", text: "藏品「镇纸」：每场战斗损血 −4", apply: () => s.relic = true },
  "5,4": { g: "强", text: "稀有字【强】（加强 / 超强 / 强化）", apply: () => {} },
  "6,6": { g: "回", text: "墨 +3", apply: () => s.ap += 3 },
};
const FOE = { "1,5": { g: "甲", name: "铁甲卫 · 险战", base: 14, elite: true }, "3,7": { g: "爆", name: "爆墨妖", base: 9 },
  "3,9": { g: "铸", name: "首领 · 铸印魔", base: 24, boss: true } };
const AMBUSH = [["冷", "寒墨灵"], ["爆", "爆墨妖"], ["甲", "铜甲卫"], ["息", "吞息鬼"], ["击", "破锋客"], ["急", "急行鼠"]];
const FOE_FX = ["灼烧：每回合灼伤 2", "蓄力：第 3 回合放出重击", "偷金：每回合 −2 金币", "护甲：开局护甲 +8", "回复：每回合回 3 血"];
// 排版台 buff：每个词按所属系统计点（三字以上 2 点，含交汇字再 +1）
const BUFF = [p => `开战先灼敌：损血 −${3 * p}`, p => `战胜回墨 +${p}`, p => `战后金币 +${4 * p}`,
  p => `抵消 ${p} 条敌方词条`, p => `伏击探知：周围 ${Math.min(3, p)} 格`];
const STAMP_BG = { "起": "#221f1a", "休": "var(--jade)", "市": "var(--gold-dk)" };
const K = (r, c) => r + "," + c, P = k => k.split(",").map(Number);
const inZone = (r, c) => r >= 2 && c >= 2 && c <= 8 && MAP[r][c] === ".";
let s;

function reset() {
  s = { pos: [3, 0], ap: 14, hp: 60, gold: 18, coll: ["火", "合", "力", "收"], sel: -1, board: Array.from({ length: BW }, () => Array(BW).fill(null)),
    codex: new Set(), trail: new Set(["3,0"]), taken: new Set(), hidden: {}, rested: false, relic: false, battle: null, shop: null, scout: null, over: false };
  const spots = [];
  for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) if (inZone(r, c)) spots.push(K(r, c));
  for (const k of pickN(spots, 5)) s.hidden[k] = AMBUSH[Math.floor(Math.random() * AMBUSH.length)];
  document.getElementById("log").innerHTML = "";
  render();
}
function textAt(r, c) {
  const k = K(r, c), ch = MAP[r][c];
  if (s.battle && s.battle.k === k) return s.battle.g;
  if (s.taken.has(k)) return null;
  if (ch === "R") return REWARD[k].g;
  if (ch === "E" || ch === "终") return FOE[k].g;
  return isGlyph(ch) ? ch : null;
}
const grid = (extra = {}) => MAP.map((row, r) => row.map((_, c) => extra[K(r, c)] || textAt(r, c)));
const touches = (w, r, c) => w.cells.some(([a, b]) => a === r && b === c);
// 敌字与地图上周围的字横竖成词；词的第一个字是敌字 → 归敌，否则归你
function combos(k, g) {
  const [r, c] = P(k);
  return findWords(grid({ [k]: g })).filter(w => touches(w, r, c)).map(w => ({ ...w, foe: w.cells[0][0] === r && w.cells[0][1] === c }));
}
// 拾走某格的字，会拆掉哪些敌人身边的词
function links(k) {
  const [r, c] = P(k), out = [];
  for (const fk in FOE) if (!s.taken.has(fk)) for (const w of combos(fk, FOE[fk].g)) if (touches(w, r, c)) out.push({ name: FOE[fk].name, ...w });
  return out;
}
function buffs() {
  const words = findWords(s.board), use = cellUse(words), pts = SYS.map(() => 0);
  for (const w of words) pts[wordSys(w.w)] += (w.w.length >= 3 ? 2 : 1) + (w.cells.some(([r, c]) => use[K(r, c)] > 1) ? 1 : 0);
  return { words, use, pts };
}
function lossOf(b) {
  const p = buffs().pts, foe = Math.max(0, b.combos.filter(x => x.foe).length - p[3]);
  return Math.max(0, b.base + 4 * foe - 3 * b.combos.filter(x => !x.foe).length - 3 * p[0] - (s.relic ? 4 : 0));
}
const adj = (r, c) => Math.abs(r - s.pos[0]) + Math.abs(c - s.pos[1]) === 1;
const busy = () => s.battle || s.shop || s.over;
const mk = (k, g, name, base, boss) => ({ k, g, name, base, boss, combos: combos(k, g) });
function log(html) { const li = document.createElement("li"); li.innerHTML = html; li.className = "flash"; document.getElementById("log").prepend(li); }

function move(r, c) {
  const k = K(r, c), ch = MAP[r][c];
  if (busy() || !adj(r, c) || ch === "#") return;
  if (s.ap > 0) s.ap--; else { s.hp = Math.max(1, s.hp - 4); log("墨尽：以血代墨，气血 −4"); }
  s.pos = [r, c]; s.trail.add(k); s.scout = null;
  if (s.hidden[k]) {
    const [g, name] = s.hidden[k]; delete s.hidden[k];
    log(`<span class="seal elite">伏</span> 野径伏击！敌字【${g}】现身`);
    s.battle = mk(k, g, name, 8, false); return render();
  }
  if (ch === "R" && !s.taken.has(k)) claim(k);
  if ((ch === "E" || ch === "终") && !s.taken.has(k)) s.battle = mk(k, FOE[k].g, FOE[k].name, FOE[k].base, !!FOE[k].boss);
  if (ch === "休" && !s.rested) { s.rested = true; s.ap += 4; s.hp = Math.min(60, s.hp + 10); log(`<span class="seal rest">休</span> 歇脚：墨 +4，气血 +10`); }
  if (ch === "市") s.shop = pickN("合重破护利精充投加息", 4);
  render();
}
function fight() {
  const b = s.battle, loss = lossOf(b), p = buffs().pts;
  s.hp = Math.max(1, s.hp - loss); s.taken.add(b.k); s.battle = null;
  if (b.boss) { s.over = true; log(`<span class="seal boss">首</span> 击败首领，气血 −${loss}，第一幕完成`); return render(); }
  const gold = 6 + 4 * p[2];
  s.coll.push(b.g); s.gold += gold; s.ap += p[1];
  log(`战胜${b.name}：气血 −${loss}，收得敌字【${b.g}】，❖ +${gold}${p[1] ? `，墨 +${p[1]}` : ""}`);
  render();
}
function claim(k) {
  const rw = REWARD[k];
  s.taken.add(k); rw.apply(); s.coll.push(rw.g);
  log(`<span class="seal shop">赏</span> 目标字【${rw.g}】入匣：${rw.text}`);
}
// 看守：上下左右有未击败的敌人（含正在交战的），这一格的字就被看住，不能拾取
function guardOf(k) {
  const [r, c] = P(k);
  for (const [a, b] of [[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]]) {
    const fk = K(a, b);
    if (s.battle && s.battle.k === fk) return s.battle.name;
    if (FOE[fk] && !s.taken.has(fk)) return FOE[fk].name;
  }
  return null;
}
function pickup() {
  const k = K(...s.pos), g = MAP[s.pos[0]][s.pos[1]], L = links(k);
  if (guardOf(k)) return;
  s.taken.add(k); s.coll.push(g);
  log(`拾得【${g}】${L.length ? `；拆掉了 ${L.map(w => `「${w.w}」`).join("")}` : ""}`);
  render();
}
function boardClick(r, c) {
  const g = s.board[r][c];
  if (s.sel >= 0) { const t = s.coll.splice(s.sel, 1)[0]; if (g) s.coll.push(g); s.board[r][c] = t; s.sel = -1; }
  else if (g) { s.coll.push(g); s.board[r][c] = null; }
  for (const w of findWords(s.board)) if (!s.codex.has(w.w)) { s.codex.add(w.w); s.ap += 1; log(`新词入谱 <span class="word">「${w.w}」</span>：墨 +1`); }
  if (s.battle) s.battle.combos = combos(s.battle.k, s.battle.g);
  render();
}
function buy(i) { if (s.gold < 5) return; s.gold -= 5; s.coll.push(s.shop.splice(i, 1)[0]); render(); }
function buyInk() { if (s.gold < 6) return; s.gold -= 6; s.ap += 3; render(); }
function cellClick(r, c) {
  const k = K(r, c), ch = MAP[r][c];
  if (!busy() && adj(r, c)) return move(r, c);
  if ((ch === "E" || ch === "终") && !s.taken.has(k) && !s.battle) { s.scout = k; render(); }
}

// ---------- 渲染 ----------
function cellHTML(r, c, sense) {
  const k = K(r, c), ch = MAP[r][c], t = textAt(r, c), cls = ["pcell"], gone = s.taken.has(k);
  let inner = "", badge = null;
  if (ch === "#") cls.push("ink");
  else if (STAMP_BG[ch]) inner = `<div class="stampc" style="background:${STAMP_BG[ch]};${ch === "休" && s.rested ? "opacity:.45" : ""}">${ch}</div>`;
  else if (s.battle && s.battle.k === k) { cls.push("foe"); badge = ["战", "var(--plum)"]; }
  else if (ch === "终" && !gone) { cls.push("boss", "look"); badge = ["首", "var(--ver)"]; }
  else if (ch === "E" && !gone) { cls.push("foe", "look"); badge = [FOE[k].elite ? "险" : "敌", "var(--plum)"]; }
  else if (ch === "R" && !gone) { cls.push("reward"); badge = ["赏", "var(--gold-dk)"]; }
  else if (t) { cls.push("fixed"); if (links(k).length) cls.push("linked"); if (guardOf(k)) { cls.push("guarded"); badge = ["守", "#3a3530"]; } }
  if (t && !STAMP_BG[ch]) inner = `<div class="tile">${t}</div>`;
  if (inZone(r, c) && !s.trail.has(k)) cls.push("wild");
  if (s.hidden[k] && Math.abs(r - s.pos[0]) + Math.abs(c - s.pos[1]) <= sense) { cls.push("sensed"); badge = ["伏", "var(--ver)"]; }
  if (s.trail.has(k) && !t && !STAMP_BG[ch]) cls.push("trail");
  if (!busy() && adj(r, c) && ch !== "#") cls.push("can");
  if (s.pos[0] === r && s.pos[1] === c) cls.push("here");
  const b = badge ? `<span class="badge2" style="background:${badge[1]}">${badge[0]}</span>` : "";
  return `<div class="${cls.join(" ")}" onclick="cellClick(${r},${c})">${b}${inner}</div>`;
}
function battleHTML(b, live) {
  const p = buffs().pts, mine = b.combos.filter(x => !x.foe), foe = b.combos.filter(x => x.foe);
  let cancel = p[3];
  return `<h3>${live ? "遭遇" : "侦察"}：${b.name}</h3>
    <p>敌字 <span class="tile sm" style="background:var(--plum);color:var(--paper)">${b.g}</span> 与地图上周围的字：</p>
    ${b.combos.map(w => w.foe ? `<div class="combo foe ${cancel-- > 0 ? "off" : ""}">敌方先手 <b>「${w.w}」</b> → ${FOE_FX[wordSys(w.w)]}${cancel >= 0 ? "（被防反抵消）" : ""}</div>`
      : `<div class="combo mine">我方先手 <b>「${w.w}」</b> → 开局预置在字盘上</div>`).join("") || '<p class="muted">周围没有成词：普通开局。</p>'}
    <p>预计损血 <b style="color:var(--ver)">${lossOf(b)}</b> <span class="muted">（基础 ${b.base} ＋敌词 4×${Math.max(0, foe.length - p[3])} −我词 3×${mine.length}${p[0] ? ` −热度 ${3 * p[0]}` : ""}${s.relic ? " −镇纸 4" : ""}）</span></p>
    ${live ? `<p class="muted">开战前还能调整排版台。</p><button class="btn primary" onclick="fight()">开战（模拟结算）</button>`
      : `<p class="muted">敌人身边的字被它看守着，拾不走。敌方的词要靠排版台的「防反」抵消。</p>`}`;
}
function evHTML() {
  if (s.over) return `<h3>幕终</h3><p>首领已破，第一幕完成。剩余墨 ${s.ap} → ❖ +${s.ap * 2}</p><p>字匣和排版台带入下一幕。</p>`;
  if (s.battle) return battleHTML(s.battle, true);
  if (s.shop) return `<h3><span class="seal shop">市</span> 行商</h3><p>活字每枚 ❖ 5：</p><div class="tray">${s.shop.map((g, i) => `<div class="tile" onclick="buy(${i})">${g}</div>`).join("")}</div>
    <p><button class="btn" onclick="buyInk()">买墨 +3（❖ 6）</button> <button class="btn" onclick="s.shop=null;render()">离开</button></p>`;
  const k = K(...s.pos), ch = MAP[s.pos[0]][s.pos[1]];
  if (isGlyph(ch) && !s.taken.has(k)) {
    const L = links(k), gd = guardOf(k);
    if (gd) return `<h3>脚下的字 · 被看守</h3><p><span class="tile sm">${ch}</span> 正被<b>${gd}</b>看守着，现在不能拾取。</p>
      ${L.map(w => `<div class="combo ${w.foe ? "foe" : "mine"}">它和${w.name}组成「${w.w}」（${w.foe ? "归敌" : "归你"}）</div>`).join("")}
      <p class="muted">先打败看守它的敌人，才能拾取。${gd.includes("首领") ? "首领身边的字到幕终都拿不到，敌方的词只能靠排版台的「防反」抵消。" : ""}</p>`;
    return `<h3>脚下的字</h3><p>拾取 <span class="tile sm">${ch}</span>，放进字匣。</p>
      ${L.map(w => `<div class="combo ${w.foe ? "mine" : "foe"}">它和${w.name}组成「${w.w}」（${w.foe ? "归敌：拾走就拆掉，对你有利" : "归你：拾走就没了"}）</div>`).join("")}
      <button class="btn primary" onclick="pickup()">拾取</button> <span class="muted">不拾就直接走开</span>`;
  }
  if (s.scout) { const f = FOE[s.scout]; return battleHTML(mk(s.scout, f.g, f.name, f.base, f.boss), false); }
  return `<h3>下一步</h3><p>点脚边的金框格前进，每步耗 1 墨。</p><p class="muted">走到散落的字上可以拾取。点远处的敌字或首领可以侦察。</p>`;
}
function render() {
  const bf = buffs();
  let h = "";
  for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) h += cellHTML(r, c, Math.min(3, bf.pts[4]));
  const pl = document.getElementById("plate"); pl.style.gridTemplateColumns = `repeat(${W},50px)`; pl.innerHTML = h;
  let bh = "";
  for (let r = 0; r < BW; r++) for (let c = 0; c < BW; c++) {
    const g = s.board[r][c], u = bf.use[K(r, c)] || 0;
    bh += `<div class="pcell bcell ${u ? "inword" : ""} ${u > 1 ? "cross" : ""}" onclick="boardClick(${r},${c})">${g ? `<div class="tile">${g}</div>` : ""}</div>`;
  }
  const bd = document.getElementById("board"); bd.style.gridTemplateColumns = `repeat(${BW},44px)`; bd.innerHTML = bh;
  document.getElementById("buff").innerHTML = SYS.map((sy, i) => `<div class="brow ${bf.pts[i] ? "" : "dim"}">${sysChip(i)} <b>${bf.pts[i]}</b> 点 · ${BUFF[i](bf.pts[i])}</div>`).join("") +
    `<p class="muted" style="margin:6px 0 0">已成词：${bf.words.map(w => `「${w.w}」`).join("") || "无"} · 词谱 ${s.codex.size} 个</p>`;
  document.getElementById("tray").innerHTML = s.coll.map((g, i) => `<div class="tile ${s.sel === i ? "sel" : ""} ${canForm(s.board, g) ? "can" : ""}" onclick="s.sel=s.sel===${i}?-1:${i};render()">${g}</div>`).join("") || '<span class="muted">（字匣空了）</span>';
  document.getElementById("ev").innerHTML = evHTML();
  document.getElementById("hpn").textContent = s.hp + "/60";
  document.getElementById("hpbar").style.width = (s.hp / 60 * 100) + "%";
  document.getElementById("ap").textContent = s.ap;
  document.getElementById("gold").textContent = s.gold;
}
reset();
