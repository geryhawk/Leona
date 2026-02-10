import Foundation

// MARK: - Runtime Language Override
// Allows changing the app language at runtime without restarting.
// Works by swizzling Bundle.localizedString to use the selected language bundle.

private var bundleKey: UInt8 = 0

final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Sets the app language at runtime. Pass `nil` to reset to system default.
    static func setLanguage(_ language: String?) {
        // Swizzle Bundle.main class if not already done
        let didSwizzle = objc_getAssociatedObject(Bundle.main, "didSwizzle") as? Bool ?? false
        if !didSwizzle {
            object_setClass(Bundle.main, LanguageBundle.self)
            objc_setAssociatedObject(Bundle.main, "didSwizzle", true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        if let language = language,
           let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            // Reset to default bundle
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        // Also set AppleLanguages for the next launch
        if let language = language {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}
