import UIKit

#if DEVTOOLS
enum DebugLog {
    private static let labels = NSHashTable<UILabel>.weakObjects()
    private static let maxLogBytes: UInt64 = 64 * 1024

    private static let logURL: URL? = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("keyboard.log")

    static func makeLabel() -> UILabel {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        l.textColor = .secondaryLabel
        l.text = "debug"
        l.isAccessibilityElement = false
        labels.add(l)
        return l
    }

    static func log(_ message: String) {
        let mem = memoryFootprintMB().map { String(format: "%.1f MB", $0) } ?? "? MB"
        let line = "\(mem) · \(message)"
        for label in labels.allObjects { label.text = line }
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

final class TuningStripView: UIStackView {
    var onChange: ((KeyboardTuning) -> Void)?
    private let store: TuningStore
    private var tuning: KeyboardTuning
    private var parameterIndex = 0
    private let parameterButton = UIButton(type: .system)
    private var parameter: TuningParameter { TuningParameter.allCases[parameterIndex] }

    init(store: TuningStore) {
        self.store = store
        tuning = store.tuning
        super.init(frame: .zero)
        axis = .vertical
        spacing = 0
        let controls = UIStackView()
        controls.spacing = 4
        parameterButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        parameterButton.titleLabel?.adjustsFontSizeToFitWidth = true
        parameterButton.accessibilityIdentifier = "tuning-param"
        parameterButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.parameterIndex = (self.parameterIndex + 1) % TuningParameter.allCases.count
            self.updateTitle()
        }, for: .touchUpInside)
        controls.addArrangedSubview(parameterButton)
        let minus = button("−", identifier: "tuning-minus", label: "Decrease parameter") { [weak self] in self?.adjust(-1) }
        let plus = button("+", identifier: "tuning-plus", label: "Increase parameter") { [weak self] in self?.adjust(1) }
        let reset = button("Reset", identifier: "tuning-reset", label: "Reset tuning") { [weak self] in
            guard let self else { return }
            self.store.reset()
            self.tuning = self.store.tuning
            self.updateTitle()
            self.onChange?(self.tuning)
        }
        for control in [minus, plus, reset] { controls.addArrangedSubview(control) }
        addArrangedSubview(controls)
        controls.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let readout = DebugLog.makeLabel()
        addArrangedSubview(readout)
        readout.heightAnchor.constraint(equalToConstant: 16).isActive = true
        accessibilityElements = [parameterButton, minus, plus, reset]
        updateTitle()
    }

    required init(coder: NSCoder) { fatalError("Use init(store:)") }

    private func button(_ title: String, identifier: String, label: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = label
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func adjust(_ direction: Double) {
        if parameter == .layoutMode {
            tuning[parameter] = (tuning[parameter] + direction + 3).truncatingRemainder(dividingBy: 3)
        } else {
            tuning[parameter] = min(parameter.range.upperBound,
                                    max(parameter.range.lowerBound, tuning[parameter] + direction * parameter.step))
        }
        store.tuning = tuning
        updateTitle()
        onChange?(tuning)
    }

    private func updateTitle() {
        let value = parameter == .layoutMode ? tuning.layoutMode.rawValue : String(format: "%.2f", tuning[parameter])
        parameterButton.setTitle("\(parameter.displayName): \(value)", for: .normal)
        parameterButton.accessibilityLabel = parameter.displayName
        parameterButton.accessibilityValue = value
        parameterButton.accessibilityHint = "Tap for the next parameter"
    }
}
#endif
