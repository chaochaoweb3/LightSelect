import AppKit
import XCTest
@testable import LightSelectCore

final class ApplicationMenuFactoryTests: XCTestCase {
    func testMainMenuProvidesStandardEditingCommands() throws {
        let menu = ApplicationMenuFactory.make(language: .zhCN)
        let editMenu = try XCTUnwrap(menu.items.first(where: { $0.title == "编辑" })?.submenu)

        XCTAssertEqual(editMenu.item(withTitle: "撤销")?.keyEquivalent, "z")
        XCTAssertEqual(editMenu.item(withTitle: "重做")?.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertEqual(editMenu.item(withTitle: "剪切")?.action, #selector(NSText.cut(_:)))
        XCTAssertEqual(editMenu.item(withTitle: "复制")?.action, #selector(NSText.copy(_:)))
        XCTAssertEqual(editMenu.item(withTitle: "粘贴")?.action, #selector(NSText.paste(_:)))
        XCTAssertEqual(editMenu.item(withTitle: "全选")?.action, #selector(NSText.selectAll(_:)))
    }

    func testControlPasteRoutingIsStrictlyWindowScoped() {
        XCTAssertTrue(SettingsWindowController.shouldForwardControlPaste(
            characters: "v", modifierFlags: [.control], isKeyWindow: true, responderIsInsideWebView: true
        ))
        XCTAssertTrue(SettingsWindowController.shouldForwardControlPaste(
            characters: "V", modifierFlags: [.control, .capsLock], isKeyWindow: true, responderIsInsideWebView: true
        ))
        XCTAssertFalse(SettingsWindowController.shouldForwardControlPaste(
            characters: "v", modifierFlags: [.command], isKeyWindow: true, responderIsInsideWebView: true
        ))
        XCTAssertFalse(SettingsWindowController.shouldForwardControlPaste(
            characters: "v", modifierFlags: [.control, .shift], isKeyWindow: true, responderIsInsideWebView: true
        ))
        XCTAssertFalse(SettingsWindowController.shouldForwardControlPaste(
            characters: "c", modifierFlags: [.control], isKeyWindow: true, responderIsInsideWebView: true
        ))
        XCTAssertFalse(SettingsWindowController.shouldForwardControlPaste(
            characters: "v", modifierFlags: [.control], isKeyWindow: false, responderIsInsideWebView: true
        ))
        XCTAssertFalse(SettingsWindowController.shouldForwardControlPaste(
            characters: "v", modifierFlags: [.control], isKeyWindow: true, responderIsInsideWebView: false
        ))
    }
}
