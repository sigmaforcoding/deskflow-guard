# Deskflow Guard — macOS 启动与断线管理

一个轻量的 macOS 小应用，让 Deskflow **登录时打开但保持断开，掉线后停止重试**。

A native macOS utility for Deskflow keyboard and mouse sharing: start disconnected at login, stop automatic reconnect loops and log spam after connection failure, and manage the background guard from a GUI.

## 为什么做这个

希望开机后 Deskflow 随时可用，但不希望它自动连接；离开 Wi-Fi 或服务器关机后，也不希望连接重试和日志一直刷。Deskflow Guard 用一个原生管理窗口，把这些行为集中到几个开关里。

## 适合哪些需求场景

| 场景 | 你遇到的问题 | Deskflow Guard 的处理 |
| --- | --- | --- |
| MacBook 带出门、换 Wi-Fi | 办公桌上的键鼠共享服务器不可达，客户端持续重连、刷日志 | 检测到掉线或最终连接失败后停止客户端，保留窗口；回到网络后手动连接 |
| Mac 开机比服务器早 | 希望软件自动打开，但另一台电脑还没开机，不想立即连接 | 登录时打开 Deskflow，保持断开，等服务器准备好再点“连接” |
| 服务器关机或网络断开 | 停止使用后客户端还一直尝试连接 | 自动结束重试，回到可手动连接的状态 |
| 只在工作时共享键盘鼠标 | 希望保留开机可用的便利，同时自己决定什么时候连接 | 把“打开软件”和“开始连接”分开；守护和登录自启动都有独立控制 |
| 家里、公司使用不同服务器 | 配置多个地址后，第一个不可达，但第二个仍可能可用 | 允许继续尝试下一个地址，全部失败后才停止；无需删掉备用地址 |
| 不想每次手动管理后台脚本 | 不清楚守护是否在运行，也不想用终端开关启动项 | 用原生窗口查看状态、启动/停止守护、管理登录启动和查看日志 |

它适合**希望手动重连**的人。如果你需要网络恢复后无人值守自动重连，Deskflow 本身的重试行为更符合这个目标，建议停用本守护。

## 你可能正在搜索这些问题

- Deskflow Mac 开机自启动，但不要自动连接 / **Deskflow start at login without auto-connect**
- Deskflow 断线后停止自动重连 / **Deskflow disable auto reconnect on macOS**
- Deskflow 没有 Wi-Fi、服务器关机后一直刷日志 / **Deskflow reconnect loop / log spam**
- Deskflow `failed to connect to server`、`Host is down` 或 `Timed out` 不断重复
- Mac 上如何管理 Deskflow 后台守护和登录启动项 / **Deskflow LaunchAgent GUI manager**

这些关键词对应的是客户端启动与重试管理。它不解决服务器地址错误、网络不通、权限缺失或键鼠共享本身的兼容问题。

## Use cases (English)

- **Laptop leaves the office Wi-Fi:** stop retrying an unreachable keyboard/mouse sharing server; reconnect manually when needed.
- **Mac starts before the server:** open Deskflow at login without immediately starting a connection.
- **Server shuts down:** stop the reconnect loop instead of continuously logging connection failures.
- **Several server addresses:** keep trying the next address; stop only after all addresses fail.
- **Prefer buttons to terminal commands:** manage the local LaunchAgent with a native SwiftUI window.

Designed for manual reconnection. Keep the guard disabled if you need unattended automatic reconnection after temporary outages. Requires Deskflow file logging; see the limitations below.

## 功能

- 查看守护状态，启动或停止守护。
- 开启或关闭登录自启动；登录时打开 Deskflow，保持断开。
- 连接失败或服务器掉线后停止连接进程，保留 Deskflow 窗口；需要时手动点“连接”。
- 支持多个服务器地址：允许尝试下一个地址，全部尝试失败后才停止。
- 快速打开 Deskflow 或守护日志文件夹。

关闭管理窗口不会停止守护。停止守护不会主动断开已有 Deskflow 连接。

## 环境与构建

- macOS 13 或更新版本。
- Deskflow 安装在 `/Applications/Deskflow.app`，已完成自己的权限和连接设置。
- Xcode 或 Command Line Tools，包含支持 Swift 6 的编译器及 `/usr/bin/python3`。
- **保持 Deskflow 文件日志开启**，日志级别建议 Info；守护通过新增日志判断连接失败。

```bash
git clone https://github.com/sigmaforcoding/deskflow-guard.git
cd deskflow-guard
./scripts/build.sh
```

生成的应用位于 `dist/Deskflow Guard.app`。构建只生成本机处理器架构的版本，并使用本地临时签名，不是 Apple 公证发行包。

把应用复制到稳定的位置（例如 `~/Applications`），再打开它。点“启动守护”开始当前会话的守护；勾选“登录后启动 Deskflow 和守护”启用后续登录自启动。首次使用默认不开启自启动。

## 工作方式与限制

管理窗口使用 SwiftUI；后台守护使用 Python 和当前用户的 LaunchAgent，不需要管理员权限。启动时仅把 Deskflow 配置中的 `startCoreWithGui` 改为 `false`，不改变服务器地址和安全设置。

守护每 0.25 秒读取 Deskflow 新增的文件日志。遇到最终连接失败或服务器断开时，使用 **SIGKILL** 结束匹配的 `deskflow-core client` 进程。这样做是因为 Deskflow GUI 可能自动重启正常退出的连接进程；非零信号退出会让 GUI 回到停止状态。可能留下一条退出码 `9` 的警告。它不是 Deskflow 的官方插件，也没有修改 Deskflow 本体。

该版本按进程路径匹配，**同一路径启动的命令行客户端也可能被停止**；不适合同时运行多个客户端实例。检测依赖日志措辞，未来 Deskflow 更新后可能需要调整。它停止重试，不能修复网络连接本身；短暂掉线后也需要手动重新连接。

启用自启动后不要直接移动应用：启动项引用应用的绝对路径。若需移动，先关闭自启动并停止守护，移动后再重新开启。关闭自启动不会立即停止当前守护。

已在 Apple Silicon Mac / Deskflow 1.27.0.0 上验证管理按钮和多服务器连接切换。登录/注销与人为断网尚未做端到端验证；不宣称支持所有 Deskflow 版本。

## 测试

```bash
python3 -m unittest discover -s tests -v
```

覆盖中间服务器失败继续尝试、全部失败停止、服务器掉线、正常鼠标切换，以及客户端进程选择。

## 本地文件与卸载

- Deskflow 设置：`~/Library/Deskflow/Deskflow.conf`
- 守护日志和启动模板：`~/Library/Application Support/DeskflowGuard/`
- 登录启动项：`~/Library/LaunchAgents/local.deskflow.disconnected-login.plist`

卸载前在管理窗口取消登录自启动，再点“停止守护”；随后可删除应用和守护文件夹。Deskflow 自身的设置、日志和数据不属于此应用。守护不上传日志、不发送网络探测请求；Deskflow 自身的网络功能保持不变。

## 许可证

[MIT](LICENSE)。本项目与 [Deskflow](https://github.com/deskflow/deskflow) 无隶属关系，仓库不包含 Deskflow 软件本体。
