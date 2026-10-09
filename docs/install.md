# 安装、升级与卸载

这是一个独立的社区插件：DSH Host/client 插件负责读取官方事件及处理请求，**DSH Notify.app** 负责 macOS 原生通知、问答/审批窗口及可选菜单栏。它需要官方 DSH Desktop，运行时不依赖旧 `dsh-notify-web`、浏览器通知插件、DSH Bridge、额外模型或本仓库所在的开发者工作目录。

## 环境与版本

- 官方 DeepSeek Harness Desktop，当前验证版本 `0.2.0-rc.2`。
- 最低运行和编译目标为 macOS 13；SDK 13 使用计时器动画，SDK 14+ 构建保留新系统屏幕刷新接口。真实本机验证是 Apple Silicon，旧系统与 Intel 仍需设备验收。
- Desktop 插件管理器及 Desktop 自带 CLI 使用其内置 Node.js/pnpm；手动源码安装或开发需要独立 Node.js 22+。构建助手需要 Apple Command Line Tools，无须完整 Xcode 或付费证书。
- 本仓库提供源码，不提供已公证的通用 `.app`。本机构建使用当前机器架构。
- `0.5.0` 当前为预发布版本，未发布稳定 tag。自动安装从 `v0.5.0-preview.2` 开始支持；安装 `main` 时应记录提交 SHA，并使插件和助手来自同一提交。版本见 [Releases](https://github.com/realDGD/dsh-macos-notify/releases)。

## 插件安装时自动构建助手

此流程适用于 `v0.5.0-preview.2` 及之后的 Git/插件包。获得构建脚本授权后会同步安装助手；旧版 `v0.5.0-preview.1` 使用后面的手动安装方式。

先准备 Apple Command Line Tools：`xcrun --find swiftc`。缺少时执行 `xcode-select --install`，完成系统安装后重试，不需要完整 Xcode。使用官方 Desktop 提供的 CLI：

```sh
dsh plugin --profile desktop add github:realDGD/dsh-macos-notify
```

Desktop 插件管理器可直接添加同一个 GitHub 地址。若提示脚本被阻止，选择 **允许这些脚本并重试**；CLI 会列出该 profile 的 `pnpm-workspace.yaml` 和此插件的精确版本键，将**该键**设为 `true` 后重试原命令。不同 Git 提交可能有不同授权键，更新时按提示复核，不要开启全局依赖脚本权限。DSH 会先拦截尚未授权的构建，助手不会因此被安装。

授权后，从当前插件包的 Swift/资源源码构建本机架构助手，验证签名，再安装到 `~/Applications/DSH Notify.app`。设置与旧版备份保留，匹配且完整的已安装助手复用。需要替换且原生面板仍打开时，安装器拒绝升级；先处理草稿、关闭面板，再重试。安装器也核对运行中助手的实际状态目录；目录无法确认时须先正常退出 Desktop 和助手再升级，不会猜测目录后终止进程。没有安装同一插件的其他 profile 不会因此获得插件。`--profile web` 同样可以触发助手编译，但不会把插件装到 Desktop 的 `desktop` profile；当前原生运行范围仍是官方 Desktop。

安装期间不弹出助手或通知权限窗口。正常重启 Desktop，插件启动助手后再授予 macOS 通知权限。助手跟随 Desktop 启停，不创建开机 LaunchAgent。本地编译使用 ad-hoc 签名，不等于 Apple 公证，也不绕过 DSH/macOS 安全策略；分发构建好的 App 仍需另外处理签名、公证与下载隔离属性。

构建与签名失败时保留旧助手。多个 profile 同时安装时，公共应用目录的安装锁阻止并发替换。若安装进程被强制杀死留下 `~/Applications/.DSH Notify.install.lock`，先读取记录的 PID 并确认该进程已退出，再移除这一锁文件重试，不要删除仍在使用的锁。

需要只装插件时，为安装命令设置 `DSH_NOTIFY_SKIP_NATIVE_INSTALL=1`，之后从匹配源码运行 `bash macos/install.sh`。`--ignore-scripts` 也会跳过自动安装。`DSH_NOTIFY_INSTALL_HOME` 是隔离验证专用目录覆盖，日常安装无需设置；`DSH_HOME` 自定义仍按该状态目录保存生产设置与备份。

## 手动从 Git 仓库安装

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

在 Desktop 的 **Plugins → Add plugin** 中填写仓库的绝对路径，安装并启用。也可以使用 `github:realDGD/dsh-macos-notify#main`，或将 `main` 换成已核验的完整 SHA；包含自动安装脚本的版本可直接构建助手，旧版本仍需从相同提交手动安装。Desktop 用户无须全局安装 npm 版 `dsh`。首次安装后正常退出并重新打开 Desktop，确保 Host 和客户端加载新模块。

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

插件 `.tgz` 可由 DSH 包管理器安装；包含新安装脚本的包在授权构建脚本后自动编译助手。它不包含完整测试套件；需要手动构建时，将 `.tgz` 解压到专用目录，进入 `package/` 后执行相同安装命令。不要将这个安装包误认为完整源码包，也不要对不同版本的助手与插件混搭。

## 升级与恢复

1. 记录当前版本。关闭原生问答/审批窗口，避免丢失草稿；有未提交内容时先处理或保存。
2. 当前插件管理器通过移除插件后重新添加安装新版。添加包含自动安装脚本的版本后同步检查助手；CLI 若要求重新授权，按当前精确版本键复核并重试。手动安装时更新到选定提交或发布版本，运行 `npm ci --ignore-scripts` 和 `bash macos/install.sh`，再添加匹配源码目录，使插件与助手版本一致。
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
