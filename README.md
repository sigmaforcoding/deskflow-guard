# Deskflow Guard

一个轻量的 macOS 小应用，让 Deskflow **登录时打开但保持断开，掉线后停止重试**。

A lightweight macOS companion for Deskflow: launch disconnected at login and stop retrying after connection failure.

## 为什么做这个

希望开机后 Deskflow 随时可用，但不希望它自动连接；离开 Wi-Fi 或服务器关机后，也不希望连接重试和日志一直刷。Deskflow Guard 用一个原生管理窗口，把这些行为集中到几个开关里。

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
