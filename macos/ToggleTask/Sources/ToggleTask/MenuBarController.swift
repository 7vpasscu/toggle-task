import AppKit
import SwiftUI

final class MenuBarController {
    private var item: NSStatusItem?
    private var popover: NSPopover?

    @MainActor func install(store: TimerStore) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Toggle Task")
        item.button?.action = #selector(togglePopover(_:)); item.button?.target = self
        let popover = NSPopover(); popover.behavior = .transient; popover.contentSize = NSSize(width: 340, height: 280)
        popover.contentViewController = NSHostingController(rootView: MenuBarView().environmentObject(store))
        self.item = item; self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) { guard let button = item?.button, let popover else { return }; popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
}
