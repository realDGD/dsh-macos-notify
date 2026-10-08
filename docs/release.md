# 发布包与验证

## 当前发布状态

`0.5.0`（助手 Build 26）正在准备发布，**没有稳定 `v0.5.0` tag**。代码可通过 `main` 或固定提交安装。功能变化见 [CHANGELOG](../CHANGELOG.md)，证据范围和未完成的真实菜单验收见 [compatibility](compatibility.md)。

稳定发布前还需要在生产 Desktop 中检查菜单展开/收起、最近会话真实点击及匹配的导航确认，以及菜单进入问答后的请求/草稿状态。源码测试、独立构建、签名和包校验通过都不能代替这些步骤。旧系统与 Intel 的真实设备验收也不在当前本机证据范围内。

## 两种归档

插件包 `dsh-macos-notify-VERSION.tgz` 使用 npm 的运行时文件清单，含 JS、Cordis patch、Swift 源码、离线 Markdown/KaTeX 资源、安装脚本、许可证和安装文档。完整源码包 `dsh-macos-notify-VERSION-source.tar.gz` 使用确切 Git 提交的全部文件，另含测试、CI、开发文档和 `package-lock.json`。

两个包均不包含 `.git`、依赖目录、本机状态、日志、会话标识、官方 `.app` 或图标。第三方离线渲染资源/字体及其许可证包含在内，来源和散列见 [THIRD_PARTY](../THIRD_PARTY.md)。助手从本机源码构建，运行时不下载依赖。

发布脚本用 UTC Unix 源提交时间统一 tar mtime，UID/GID 为 0、所有者为 `root`，文件权限仅为 `0644/0755`；gzip 不含本机文件名或构建时间。不复制原始 npm/Git tar 的用户及 PAX 元数据。每个插件文件的实际字节与源提交比较，避免工作区文件意外混入。

`release-manifest.json` 记录准确源提交、版本/Build、两种归档的文件数及 SHA-256。`SHA256SUMS` 同时覆盖两个包和 manifest。它们用于完整性核验，不是发布者数字签名或公证。

## 维护者操作

需要 Git、Node.js 22+、npm 以及 Python 3.9+（仅标准库）。Python 只用于发布工具，用户运行插件/助手无须 Python。

```sh
git fetch --all --tags
npm ci --ignore-scripts
npm test
npm run test:release
npm run check:release
npm run audit:privacy
# 提交所有待发布修改，使当前工作树干净
npm run package:release -- --output dist/release
cd dist/release
shasum -a 256 -c SHA256SUMS
```

输出目录必须全新，脚本拒绝覆盖先前的包。同一工具环境中重复打包同一提交时，两个归档的字节相同。Git 历史审计检查所有本地可达分支/tag 的对象及提交邮件；浅克隆仅能检查已获取的历史，发布应使用完整历史。脚本检查本机路径、真实会话 ID、常见 GitHub/OpenAI/AWS 密钥格式、私钥头及私有/生成文件。提交邮箱须使用 GitHub noreply。模式扫描不能证明所有类型的敏感信息都不存在，还须人工检查新增文件、截图、链接与第三方许可。

## 完整验收清单

- 核对插件/助手版本、来源提交、运行时文件与第三方许可证；检查完整历史，不改写已发布历史。
- 运行 Node、发布边界测试、原生测试及精确提交 CI。CI 从源码包再次安装和测试，避免只测工作区。
- 把最终完整源码包解压到独立目录，运行 `npm ci --ignore-scripts`、完整测试、本机优化构建和 `codesign --verify --deep --strict`。
- 使用隔离 home/state 对新建、升级、保留设置、旧应用备份及卸载进行核验。`--no-start` 测试避免注册或启动 App；它不能证明真实通知权限/显示。
- 从 DSH 官方包管理器验证插件包可安装；不发送模型消息、执行真实审批命令或改动日常 profile。
- 核对当前所有真实用户验收项，未完成项写入发布说明，不将组件预览描述为生产验收。
- 确认 GitHub `dsh-plugin` topic 存在。以正常 merge/push 保存历史；发布资产使用统一版本、两个包、manifest 和校验表。

稳定版本准备好后，从已验证提交打 tag，发布 GitHub Release，并从远程重新下载资产校验。尚有上述真实菜单验收时可保存私有包或草稿发布，不能宣称稳定发布完成。
