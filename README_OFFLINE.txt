每日高会 · 离线包使用说明

包含：
- bundle_offline.html：离线总览页
- person.html：个人页（离线引用 Chart.js）
- har_excel_h5.html：HAR→Excel H5（离线引用 xlsx、html2canvas）
- assets/：站点静态资源（LOGO等）
- vendor/：第三方库（Chart.js、xlsx、html2canvas）
- archives/：最新存档 JSON（含 latest_localhost.json）

使用方式：
- 直接双击 bundle_offline.html 用浏览器打开即可离线查看；
- 如需服务端访问，可用 /person.html、/har_excel_h5.html、/api/archives/latest 路由；
- person.html 与 har_excel_h5.html 会优先读取 archives/latest_localhost.json。
