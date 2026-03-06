# Minimal Static Site (static.dailygh4.com)

本仓库包含一个可直接部署到 Cloudflare Pages 的最小静态站点，入口为 `index.html`，静态资源位于 `vendor/` 和 `assets/`。无构建步骤，推送到 Git 后即可部署。

## 目录结构
- `index.html`：首页（由 `person.html` 重命名）
- `bundle_offline.html`、`har_excel_h5.html`：离线/工具页面（可选）
- `vendor/`：第三方 JS 库（`chart.umd.min.js`、`html2canvas.min.js`、`xlsx.full.min.js`）
- `assets/`：图片与静态资源（如 `tf-family-logo-dark.png`）
- `archives/`：数据快照 JSON（页面可能引用，默认保留）
- `.nojekyll`：禁止 Jekyll 处理，保留 `vendor/` 等目录原样发布
- `.gitignore`：忽略日志、压缩包与系统文件

## 本地预览
- 启动本地预览：`python3 -m http.server 8030 --directory .`
- 访问：`http://localhost:8030/`

## 部署到 Cloudflare Pages（Git 驱动）
1. 在 Git 平台（如 GitHub）创建空仓库，记下远程地址。
2. 在本目录运行一键推送脚本写入远程并推送：
   - `./bin/push_to_remote.sh <REMOTE_URL>`
   - 例如 SSH：`./bin/push_to_remote.sh git@github.com:<YOUR_USERNAME>/static_site.git`
   - 或 HTTPS：`./bin/push_to_remote.sh https://github.com/<YOUR_USERNAME>/static_site.git`
3. 在 Cloudflare Pages 创建项目：选择“连接到 Git”，选中该仓库。
4. 构建设置：
   - Framework preset: `None`
   - Build command: 留空
   - Output directory: `.`（仓库根目录）
   - Production branch: `main`
5. 部署完成后，在 Pages 项目绑定自定义域名 `static.dailygh4.com`。

## 域名与证书检查
部署并绑定域名后，我已在本机启动自动监控，定期检查：
- `static.dailygh4.com` 的 `CNAME`/`A` 记录解析
- `https://static.dailygh4.com/` 的 TLS 验证与 HTTP 状态码
日志输出文件：`/Users/macbookpro/Desktop/每日高会/.https_static_monitor.log`

## 注意事项
- 如需减小仓库体积，可考虑忽略 `archives/*.json`，但请先确认页面不依赖这些数据文件。
- 为保证路径兼容性，建议页面引用使用相对路径（如 `./vendor/x.js`）。
- 后续更新：在本目录提交并推送，Pages 会自动触发新版本上线。
