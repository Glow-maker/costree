# 成本后端和前端部署

1. `cost-server.jar` 是服务器新构建的成本服务，经环境配置外置处理后交付；业务 class 和依赖与原始构建逐项比对。只停止和替换旧 cost，不部署 system、Data、SQLBot 或新建第二套中台。
2. JAR 不包含开发用 `application-jt.yml`、`application-local.yml`、`application-dev-1.yml` 等 profile。继续使用现场外置配置/Nacos。若配置原来只在旧 JAR 内，先由现场运维提取到受控配置目录。
3. 保留数据库、Redis、Nacos、端口、租户以及原 `mybatis-plus.encryptor.password`、`xxl.job.accessToken` 等值。不要生成替代密钥或把现场配置发到外网。配置键和环境变量说明见 `EXTERNALIZED-CONFIG.txt`。
4. 沿用原启动方式；需要时显式指定现场原 profile 和 `--spring.config.additional-location=file:/实际配置目录/`。本包默认 profile 为 intranet；不能误用服务器测试配置。
5. `dist-prod.zip` 经用户确认，在 Windows 本机从已提交版本重新构建，未启动本地服务；根目录直接是 `index.html`。解压新目录并整体切换，避免覆盖后残留旧文件；同源 `/admin-api` 由现有 Nginx 转发，不需要现场 Node.js。
6. 新前后端配套更新，强刷并重新登录。只改前端或执行 SQL不能修复旧后端的主键/选项逻辑。

本轮仅构建和交付，没有替现场部署。已单独下载的后端压缩包与本目录 JAR 内容相同，整包避免重复存储同一 JAR。

Linux Java 环境须能读取字体配置和至少一套可用字体，供 Excel 模板/导出使用。本轮新构建机缺少字体导致模板测试失败，补充构建目录内的隔离字体后重测；这些构建用库不嵌入 JAR。现场若已有正常导出能力，继续保留原环境；若出现 `sun.awt.FontConfiguration` 错误，按现场发行版配置 `fontconfig` 和字体，不能只靠 headless 参数解决，也不要把其他发行版的构建库覆盖到系统目录。
