import SwiftUI
import AppKit

struct CommandResult: Sendable { let code: Int32; let output: String }
func execute(_ executable: String, _ args: [String]) -> CommandResult {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(code: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    } catch { return CommandResult(code: -1, output: error.localizedDescription) }
}

@MainActor final class GuardManager: ObservableObject {
    @Published var running = false
    @Published var login = true
    @Published var busy = false
    @Published var message = "正在检查守护状态…"
    private let label = "local.deskflow.disconnected-login"
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var domain: String { "gui/\(getuid())" }
    private var root: URL { home.appendingPathComponent("Library/Application Support/DeskflowGuard") }
    private var loginFile: URL { home.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    private var templateFile: URL { root.appendingPathComponent("manager-agent.plist") }

    init() { login = FileManager.default.fileExists(atPath: loginFile.path) }

    private func command(_ args: [String]) async -> CommandResult {
        await Task.detached { execute("/bin/launchctl", args) }.value
    }

    private func writeAgent() throws {
        guard let script = Bundle.main.url(forResource: "guard", withExtension: "py") else {
            throw NSError(domain: "DeskflowGuard", code: 1, userInfo: [NSLocalizedDescriptionKey: "应用内缺少守护文件。"])
        }
        let agent: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/python3", script.path],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 30,
            "LimitLoadToSessionType": "Aqua",
            "StandardOutPath": root.appendingPathComponent("guard.log").path,
            "StandardErrorPath": root.appendingPathComponent("guard-errors.log").path
        ]
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
        try data.write(to: templateFile, options: .atomic)
        if login {
            try FileManager.default.createDirectory(at: loginFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: loginFile, options: .atomic)
        }
    }

    func refresh() async {
        guard !busy else { return }
        let result = await command(["print", "\(domain)/\(label)"])
        running = result.code == 0 && result.output.contains("state = running")
        if result.code == 0 && !running {
            message = "守护已加载，正在等待启动。可查看日志了解原因。"
        } else {
            message = running ? "掉线后停止重试；需要时在 Deskflow 中手动连接。" : "守护已停止，Deskflow 将按自己的设置运行。"
        }
    }

    func start() async {
        busy = true
        defer { busy = false }
        do {
            try writeAgent()
            let status = await command(["print", "\(domain)/\(label)"])
            let result = await command(status.code == 0 ? ["kickstart", "\(domain)/\(label)"] : ["bootstrap", domain, templateFile.path])
            if result.code != 0 { message = "启动失败：\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))"; return }
            running = true
            message = "守护已启动。现有 Deskflow 连接会保留。"
        } catch { message = error.localizedDescription }
    }

    func stop() async {
        busy = true
        defer { busy = false }
        let status = await command(["print", "\(domain)/\(label)"])
        if status.code != 0 { running = false; message = "守护已停止。"; return }
        let result = await command(["bootout", "\(domain)/\(label)"])
        if result.code == 0 { running = false; message = "守护已停止，当前 Deskflow 连接不受影响。" }
        else { message = "停止失败：\(result.output)" }
    }

    func setLogin(_ enabled: Bool) {
        let previous = login
        login = enabled
        do {
            if enabled { try writeAgent() }
            else if FileManager.default.fileExists(atPath: loginFile.path) { try FileManager.default.removeItem(at: loginFile) }
            message = enabled ? "下次登录会打开 Deskflow，并保持断开。" : "已关闭登录自启动；当前守护状态保持不变。"
        } catch { login = previous; message = error.localizedDescription }
    }

    func openDeskflow() { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Deskflow.app")) }
    func openLogs() { NSWorkspace.shared.open(root) }
}

struct ContentView: View {
    @StateObject private var manager = GuardManager()
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 38)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Deskflow Guard").font(.title2.bold())
                    Text("启动与断线管理").foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(manager.running ? Color.green : Color.gray).frame(width: 9, height: 9)
                    Text(manager.running ? "守护正在运行" : "守护未运行").font(.headline)
                    Spacer()
                    if manager.busy { ProgressView().controlSize(.small) }
                }
                Text(manager.message).font(.callout).foregroundStyle(.secondary).frame(minHeight: 38, alignment: .topLeading)
                HStack {
                    Button("启动守护") { Task { await manager.start() } }.disabled(manager.running || manager.busy)
                    Button("停止守护") { Task { await manager.stop() } }.disabled(!manager.running || manager.busy)
                }
            }.padding(18).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            Toggle("登录后启动 Deskflow 和守护", isOn: Binding(get: { manager.login }, set: { manager.setLogin($0) })).disabled(manager.busy)
            Text("登录启动保持断开。连接失败或掉线时停止连接进程，保留 Deskflow 窗口。").font(.callout).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("打开 Deskflow") { manager.openDeskflow() }
                Button("查看守护日志") { manager.openLogs() }
                Spacer()
            }
            Text("关闭此窗口不会停止守护。停止守护不会断开已有连接。\n检测依赖 Deskflow 的文件日志，请保持文件日志开启。").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(28).frame(width: 470)
        .task { await manager.refresh() }
        .onReceive(timer) { _ in Task { await manager.refresh() } }
    }
}

@main struct DeskflowGuardApp: App {
    var body: some Scene {
        WindowGroup("Deskflow Guard") { ContentView() }
            .windowResizability(.contentSize)
    }
}
