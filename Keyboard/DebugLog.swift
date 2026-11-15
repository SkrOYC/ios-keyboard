import UIKit

/// Tiny on-device debugging aid, since there is no Xcode console without a Mac.
///
/// - Shows a one-line label above the keys with the last event and the
///   extension's current memory footprint.
/// - Appends lines to `Library/Caches/keyboard.log` inside the extension's own
///   sandbox (capped at ~64 KB).
///
/// To remove: set `enabled = false`, or delete this file and the
/// `DebugLog.` calls in KeyboardViewController.swift.
enum DebugLog {
    static let enabled = true

    private static weak var label: UILabel?
    private static let maxLogBytes: UInt64 = 64 * 1024

    private static let logURL: URL? = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("keyboard.log")

    static func makeLabel() -> UILabel? {
        guard enabled else { return nil }
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        l.textColor = .secondaryLabel
        l.text = "debug"
        l.heightAnchor.constraint(equalToConstant: 14).isActive = true
        label = l
        return l
    }

    static func log(_ message: String) {
        guard enabled else { return }
        let mem = memoryFootprintMB().map { String(format: "%.1f MB", $0) } ?? "? MB"
        let line = "\(mem) · \(message)"
        label?.text = line
        append("\(Date()) \(line)\n")
    }

    /// Physical memory footprint — the number iOS compares against the extension limit.
    static func memoryFootprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Double(info.phys_footprint) / 1_048_576
    }

    private static func append(_ text: String) {
        guard let url = logURL, let data = text.data(using: .utf8) else { return }
        let fm = FileManager.default
        if let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? UInt64), size > maxLogBytes {
            try? fm.removeItem(at: url)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
