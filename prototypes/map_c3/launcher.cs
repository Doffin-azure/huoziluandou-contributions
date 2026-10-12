// 墨途远征 C3 原型启动器：把内嵌的单文件 HTML 释放到本地，用 Edge 应用窗口打开（无地址栏），找不到 Edge 就用默认浏览器。
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

static class Launcher
{
    [STAThread]
    static void Main()
    {
        try
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MotuPrototypeC3");
            Directory.CreateDirectory(dir);
            string html = Path.Combine(dir, "game.html");
            using (Stream src = Assembly.GetExecutingAssembly().GetManifestResourceStream("game.html"))
            using (FileStream dst = File.Create(html))
            {
                src.CopyTo(dst);
            }

            string url = new Uri(html).AbsoluteUri;
            string edge = FindEdge();
            if (edge != null)
            {
                // 独立的用户数据目录，窗口不会混进用户平时的浏览器会话
                string profile = Path.Combine(dir, "profile");
                var psi = new ProcessStartInfo(edge);
                psi.Arguments = "--app=\"" + url + "\" --user-data-dir=\"" + profile + "\" --window-size=1440,960 --no-first-run";
                psi.UseShellExecute = false;
                Process.Start(psi);
            }
            else
            {
                Process.Start(new ProcessStartInfo(html) { UseShellExecute = true });
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("启动失败：" + ex.Message, "墨途远征 · 原型", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    static string FindEdge()
    {
        string[] roots = {
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        };
        foreach (string root in roots)
        {
            if (string.IsNullOrEmpty(root)) continue;
            string p = Path.Combine(root, @"Microsoft\Edge\Application\msedge.exe");
            if (File.Exists(p)) return p;
        }
        return null;
    }
}
