# 安装、升级与卸载

这是一个独立的社区插件：DSH Host/client 插件负责读取官方事件及处理请求，**DSH Notify.app** 负责 macOS 原生通知、问答/审批窗口及可选菜单栏。它需要官方 DSH Desktop，运行时不依赖旧 `dsh-notify-web`、浏览器通知插件、DSH Bridge、额外模型或本仓库所在的开发者工作目录。

## 环境与版本

- 官方 DeepSeek Harness Desktop，当前验证版本 `0.2.0-rc.2`。
- macOS 13+ 编译目标；真实本机验证是 Apple Silicon，旧系统与 Intel 仍需设备验收。
- Node.js 22+；构建助手需要 Apple Command Line Tools，无须完整 Xcode 或付费证书。
- 本仓库提供源码，不提供已公证的通用 `.app`。本机构建使用当前机器架构。
- `0.5.0` 当前是开发版本，未发布稳定 tag。安装 `main` 时应记录提交 SHA，并使插件和助手来自同一提交。已发布版本见 [Releases](https://github.com/realDGD/dsh-macos-notify/releases)。

## 从 Git 仓库安装

```sh
git clone https://github.com/realDGD/dsh-macos-notify.git
cd dsh-macos-notify
npm ci --ignore-scripts
xcrun --find swiftc
bash macos/install.sh
```

若 `xcrun` 找不到编译器，先运行一次 `xcode-select --install`，完成系统安装后继续。官方 Desktop 默认位于 `/Applications/DeepSeek Harness.app`；其他位置请设置后再构建：

```sh
DSH_DESKTOP_APP="/Applications/DeepSeek Harness.app" bash macos/install.sh
```

助手安装到 `~/Applications/DSH Notify.app`，构建时复制本机官方 Desktop 的图标。仓库和压缩包不分发官方图标。系统弹出通知权限提示时，允许 **DSH Notify** 的通知。

在 Desktop 的 **Plugins → Add plugin** 中填写仓库的绝对路径，安装并启用。也可以使用 `github:realDGD/dsh-macos-notify#main`，或将 `main` 换成已核验的完整 SHA；助手仍需从相同提交安装。Desktop 用户无须全局安装 npm 版 `dsh`。首次安装后正常退出并重新打开 Desktop，确保 Host 和客户端加载新模块。

助手跟随 Desktop 启停，不创建开机 LaunchAgent。关闭或最小化 Desktop 窗口时，只要应用进程仍在，助手会继续运行。菜单栏开关只影响菜单面板，通知与问答仍可使用。

## 从压缩包安装

维护者的打包工具生成：

| 文件 | 用途 |
|---|---|
| `dsh-macos-notify-VERSION.tgz` | DSH 插件安装包，包含插件及助手源码/构建安装脚本 |
| `dsh-macos-notify-VERSION-source.tar.gz` | 完整源码，包含测试、CI、锁文件和文档，适合独立构建/开发 |
| `release-manifest.json` | 源提交、版本、助手 Build、文件数和包校验值 |
| `SHA256SUMS` | 上述三个文件的 SHA-256 校验值 |

将文件放在同一目录并先执行 `shasum -a 256 -c SHA256SUMS`。完整源码包解压后进入唯一的 `dsh-macos-notify-VERSION/` 目录，执行 `npm ci --ignore-scripts` 与 `bash macos/install.sh`，再通过 Desktop 插件管理器添加该目录。

插件 `.tgz` 可由 DSH 包管理器安装；它不包含完整测试套件。需要从同包构建助手时，可将 `.tgz` 解压到专用目录，进入 `package/` 后执行相同安装命令。不要将这个安装包误认为完整源码包，也不要对不同版本的助手与插件混搭。

## 升级与恢复

1. 记录当前版本。关闭原生问答/审批窗口，避免丢失草稿；有未提交内容时先处理或保存。
2. 更新到选定提交或发布版本，运行 `npm ci --ignore-scripts`，再运行 `bash macos/install.sh`。插件管理器安装的 GitHub/压缩包也更新到相同版本。
3. 正常重启 Desktop，检查 **Settings → DSH Notify** 中实际加载的插件、助手版本、连接与权限。安全测试通知应实际点击并取得会话选择确认；系统接受不等于已经显示横幅。

安装器先构建和验证新助手，再停止自己的旧进程并检查退出。旧应用和旧受管理的开机启动项保存在 `~/.dsh/dsh-jump/backups/`，设置保留；未知应用或启动项会导致安装拒绝覆盖。`DSH_HOME` 自定义时，状态与备份位于该目录下的 `dsh-jump/`。历史 bundle ID/状态名沿用旧名字，以保留权限和兼容性，不需要手动改名。

回退时恢复原来选定的源码版本，重新安装匹配的插件和助手；不要在助手仍运行时直接替换 `.app` 内容。备份保留用于恢复和核对，不会自动清空。老 `dsh-notify-web` / `DSH Jump.app` 用户应移除旧通知插件及旧完成/报错 relay，避免重复通知。

## 卸载

先在 Desktop 插件管理器中移除本插件，再从源码目录运行：

```sh
bash macos/uninstall.sh
```

安装器只删除自己管理的助手和启动项，保留设置与备份。正常重启 Desktop 卸载 Host 模块。`--no-start` 是隔离安装测试选项，仍会写入选定的安装目录，并非只读预演。

## 排查与隐私

- 无横幅：检查系统通知设置、勿扰/专注、锁屏预览与屏幕共享期间的通知设置。优先查看插件的投递状态；点击后成功确认才证明跳转。界面自动化与系统横幅显示的关系尚未确证。
- 图标异常：确认助手来自当前源码、本地官方 Desktop 图标存在，再通过本安装器更新。不要清空系统通知数据库、全局图标缓存或共享服务；这类操作影响其他应用。
- 连接/版本异常：正常重启 Desktop，检查安装目录和实际加载版本，勿同时启用两个旧/新通知插件。
- 发问题报告时只提供版本、系统/架构、粗粒度诊断状态和复现步骤。不要上传 `~/.dsh/dsh-jump/`、会话正文、工具参数、访问令牌或未脱敏截图。问题/审批内容必须在本地暂存以支持原生表单；本项目不提供额外云端上传通道。

通知设置由 macOS 控制，参见 [Apple 通知说明](https://support.apple.com/guide/mac-help/mchl205da693/mac)。
