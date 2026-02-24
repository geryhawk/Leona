import SwiftUI

/// When app is launched with `-screenshot-mode`, this helper provides
/// a way to navigate tabs via notification.
/// Usage: after launch, post a URL like leona://tab/1 to switch tabs.
///
/// For screenshot capture, we expose a simple view modifier that
/// listens for tab-switch commands and waits before signaling ready.

enum ScreenshotTab: Int, CaseIterable {
    case home = 0
    case stats = 1
    case growth = 2
    case health = 3
    case settings = 4
}

extension Notification.Name {
    static let switchTab = Notification.Name("com.leona.switchTab")
}
