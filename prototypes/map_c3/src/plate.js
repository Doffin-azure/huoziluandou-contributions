// 自由排版原型共用：词库、成词检测、字的系统归类
const WORDS = new Set("超能 电力 电能 电热 复电 过冷 化合 火电 火化 火急 火热 火速 加急 加收 急流 精分 精铸 精金 急转 开灯 冷热 流火 流速 能力 收放 收复 收回 收息 蓄冷 蓄热 右击 右转 转速 左击 左右 左转 防御 防护 护甲 护盾 重甲 反击 盾击 回防 破防 破甲 击破 防火 防爆 连击 重击 合击 回击 电击 火力 合力 强力 加强 超强 重合 重复 连载 反复 回流 分流 合流 回收 回购 回转 流转 清洗 清流 复合 蓄能 蓄力 蓄电 充电 充能 放电 放热 热能 热力 过热 过载 超载 加速 急速 超速 冷却 急停 停火 停息 清热 热流 火爆 爆破 爆冷 重载 金币 合金 铸币 资金 投币 收购 投资 利息 复利 炼金 投放 分利 再投资 转化 分化 反转 精炼 强化 重铸 炼化 再铸 电流 加热 急冷 停电 放火 过火 反超 合资 流利 重金 精力 充放电 电流过载 重力 超能力 防御力 复利投资".split(" "));

// 五个系统：名称 / 颜色 / 归属的字
const SYS = [
  ["热度", "#b83a2e", "火热爆过急速加冷却停"],
  ["储能", "#3c4a6b", "电能充放蓄力超"],
  ["经济", "#9a7838", "金币利投资息购铸炼"],
  ["防反", "#5f7d6a", "防御护盾甲反击破重"],
  ["流转", "#7a4a63", "回流转复收分合化清精强"],
];
const sysOf = ch => SYS.findIndex(s => s[2].includes(ch));
function wordSys(w) {
  const n = SYS.map(() => 0);
  for (const ch of w) { const i = sysOf(ch); if (i >= 0) n[i]++; }
  return n.indexOf(Math.max(...n));
}
const sysChip = i => `<span class="sysdot" style="background:${SYS[i][1]}"></span>${SYS[i][0]}`;

// 横排（左→右）与竖排（上→下）读出所有 2~4 字词。grid: 二维数组，空格为 null
function findWords(grid) {
  const R = grid.length, C = grid[0].length, out = [];
  const scan = cells => {
    for (let i = 0; i < cells.length; i++) {
      for (let n = 2; n <= 4 && i + n <= cells.length; n++) {
        const seg = cells.slice(i, i + n);
        if (seg.some(([r, c]) => !grid[r][c])) break;
        const w = seg.map(([r, c]) => grid[r][c]).join("");
        if (WORDS.has(w)) out.push({ w, cells: seg, dir: cells[0][0] === cells[1][0] ? "横" : "竖" });
      }
    }
  };
  for (let r = 0; r < R; r++) scan([...Array(C).keys()].map(c => [r, c]));
  for (let c = 0; c < C; c++) scan([...Array(R).keys()].map(r => [r, c]));
  return out;
}

// 每格被几个词用到（≥2 即交汇字）
function cellUse(words) {
  const m = {};
  for (const w of words) for (const [r, c] of w.cells) m[r + "," + c] = (m[r + "," + c] || 0) + 1;
  return m;
}

// 把 ch 放进任一空格能否新增成词
function canForm(grid, ch) {
  const base = findWords(grid).length;
  for (let r = 0; r < grid.length; r++) for (let c = 0; c < grid[0].length; c++) {
    if (grid[r][c]) continue;
    grid[r][c] = ch; const n = findWords(grid).length; grid[r][c] = null;
    if (n > base) return true;
  }
  return false;
}

const pickN = (pool, n) => { const a = [...pool], out = []; while (out.length < n && a.length) out.push(a.splice(Math.floor(Math.random() * a.length), 1)[0]); return out; };
