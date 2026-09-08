import SwiftUI

@main
struct JSONLensApp: App {
    @NSApplicationDelegateAdaptor(SnapshotAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("JSON Lens") {
            RootView(model: model)
        }
        .defaultSize(width: 1240, height: 780)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建") {
                    model.clearSource()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("打开…") {
                    model.openDocument()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("保存") {
                    model.saveDocument()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("另存为…") {
                    model.saveDocument(saveAs: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("JSON") {
                Button("格式化") {
                    model.formatSource()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!model.isSourceValid)

                Button("压缩") {
                    model.minifySource()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(!model.isSourceValid)

                Divider()

                Button("复制 JSON") {
                    model.copySource()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("从剪贴板粘贴") {
                    model.pasteFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
            }

            CommandMenu("工作区") {
                Button("检查") {
                    model.mode = .inspect
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("查询") {
                    model.mode = .query
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("对比") {
                    model.mode = .diff
                }
                .keyboardShortcut("3", modifiers: [.command])
            }
        }
    }
}
