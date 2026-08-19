import AppKit

public enum ApplicationMenuFactory {
    public static func make(language: InterfaceLanguage) -> NSMenu {
        let titles = Titles(language: language)
        let root = NSMenu()

        let applicationItem = NSMenuItem(title: "LightSelect", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "LightSelect")
        let quit = NSMenuItem(
            title: AppLocalization.strings(for: language).quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = .command
        applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu
        root.addItem(applicationItem)

        let editItem = NSMenuItem(title: titles.edit, action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: titles.edit)
        editMenu.addItem(command(titles.undo, #selector(UndoManager.undo), key: "z"))
        editMenu.addItem(command(titles.redo, #selector(UndoManager.redo), key: "Z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(command(titles.cut, #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(command(titles.copy, #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(command(titles.paste, #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(command(titles.selectAll, #selector(NSText.selectAll(_:)), key: "a"))
        editItem.submenu = editMenu
        root.addItem(editItem)

        return root
    }

    private static func command(
        _ title: String,
        _ action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = nil
        return item
    }
}

private struct Titles {
    let edit: String
    let undo: String
    let redo: String
    let cut: String
    let copy: String
    let paste: String
    let selectAll: String

    init(language: InterfaceLanguage) {
        switch language {
        case .zhCN:
            (edit, undo, redo, cut, copy, paste, selectAll) = ("编辑", "撤销", "重做", "剪切", "复制", "粘贴", "全选")
        case .enUS:
            (edit, undo, redo, cut, copy, paste, selectAll) = ("Edit", "Undo", "Redo", "Cut", "Copy", "Paste", "Select All")
        }
    }
}
