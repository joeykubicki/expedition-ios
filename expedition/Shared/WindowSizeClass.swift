import SwiftUI

extension EnvironmentValues {
    /// The window's horizontal size class, set by `RootView`. Unlike
    /// `horizontalSizeClass`, it stays the same inside sheets, whose content
    /// reports compact even when the iPad window is wide.
    @Entry var windowHorizontalSizeClass: UserInterfaceSizeClass?
}
