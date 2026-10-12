// 构建：src/ → dist/墨途远征_C3.html（单文件，双击即可在浏览器里玩）+ dist/墨途远征_C3.exe（启动器）
// 用法：node build.js
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = __dirname, src = p => path.join(root, "src", p), dist = path.join(root, "dist");
fs.mkdirSync(dist, { recursive: true });

const read = p => fs.readFileSync(src(p), "utf8");
// 用函数做替换，避免内容里的 $ 被当成替换模式
let html = read("plate_collect.html")
  .replace('<link rel="stylesheet" href="style.css">', () => `<style>\n${read("style.css")}\n</style>`)
  .replace('<script src="plate.js"></script>', () => `<script>\n${read("plate.js")}\n</script>`)
  .replace('<script src="plate_collect.js"></script>', () => `<script>\n${read("plate_collect.js")}\n</script>`)
  .replace(/<title>.*?<\/title>/, "<title>墨途远征 · 第一幕「墨林」（C3 原型）</title>");
if (/<(link|script)[^>]+(href|src)=/.test(html)) throw new Error("仍有外部引用未内联");

const htmlOut = path.join(dist, "墨途远征_C3.html");
fs.writeFileSync(htmlOut, html, "utf8");
console.log("HTML ->", htmlOut);

const resTmp = path.join(dist, "game.html");
fs.writeFileSync(resTmp, html, "utf8");
const csc = path.join(process.env.WINDIR || "C:\\Windows", "Microsoft.NET", "Framework64", "v4.0.30319", "csc.exe");
const exeOut = path.join(dist, "墨途远征_C3.exe");
try {
  execFileSync(csc, ["/nologo", "/codepage:65001", "/target:winexe", "/optimize+", "/r:System.Windows.Forms.dll",
    `/resource:${resTmp},game.html`, `/out:${exeOut}`, path.join(root, "launcher.cs")], { stdio: "inherit" });
  console.log("EXE  ->", exeOut);
} finally {
  fs.rmSync(resTmp, { force: true });
}
