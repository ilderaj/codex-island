import AppKit
import Combine

/// Mirrors macOS's system-wide Reduce Motion accessibility setting.
/// Movement-heavy animation tokens fall back to short crossfade-style
/// curves and the ambient sweep/breath surfaces go event-gated or
/// static while it's on. Opacity feedback is deliberately kept —
/// reduced motion means fewer and gentler animations, not zero.
@MainActor
final class ReduceMotionStore: ObservableObject {
    static let shared = ReduceMotionStore()

    @Published private(set) var enabled: Bool

    private var observer: NSObjectProtocol?

    private init() {
        self.enabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let now = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                if now != self.enabled {
                    self.enabled = now
                }
            }
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
