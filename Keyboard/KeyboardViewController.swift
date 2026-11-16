import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = HexKeyboardView()
    private var heightConstraint: NSLayoutConstraint!
    private var debugLabel: UILabel?
    private var stripHeight: CGFloat { DebugLog.enabled ? 22 : 0 }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 283)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        view.addSubview(keyboard)
        debugLabel = DebugLog.makeLabel()
        debugLabel?.isAccessibilityElement = false
        if let debugLabel { view.addSubview(debugLabel) }
        #if DEBUG
        keyboard.onTouchTrace = { DebugLog.trace($0) }
        #endif
        keyboard.onAction = { [weak self] action in self?.perform(action) }
        DebugLog.log("ready · hex 7×4")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboard.needsGlobe = needsInputModeSwitchKey
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        keyboard.needsGlobe = needsInputModeSwitchKey
        let width = min(view.bounds.width, 700)
        guard width > 0 else { return }
        let landscape = traitCollection.verticalSizeClass == .compact
        let keyHeight = landscape ? CGFloat(180) : min(320, width * 883 / 1320)
        let height = keyHeight + stripHeight
        if heightConstraint.constant != height {
            heightConstraint.constant = height
            preferredContentSize.height = height
        }
        keyboard.frame = CGRect(x: (view.bounds.width - width) / 2, y: stripHeight, width: width, height: keyHeight)
        debugLabel?.frame = CGRect(x: 12, y: 4, width: view.bounds.width - 24, height: 14)
        #if DEBUG
        let center = CGPoint(x: keyboard.bounds.midX, y: keyboard.bounds.midY)
        let windowPoint = keyboard.convert(center, to: view.window)
        let hit = view.window?.hitTest(windowPoint, with: nil)
        let hitName = hit.map { String(describing: type(of: $0)) } ?? "none"
        DebugLog.trace("layout root \(Int(view.bounds.width)) × \(Int(view.bounds.height)); keys \(Int(keyboard.bounds.width)) × \(Int(keyboard.bounds.height)); enabled \(view.isUserInteractionEnabled), \(keyboard.isUserInteractionEnabled); center hit \(hitName)")
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboard.cancelTouches()
    }

    private func perform(_ action: KeyboardAction) {
        switch action {
        case .insert(let value):
            textDocumentProxy.insertText(value)
            switch value {
            case " ": DebugLog.log("space")
            case "\n": DebugLog.log("return")
            default: DebugLog.log("insert")
            }
        case .delete:
            textDocumentProxy.deleteBackward()
            DebugLog.log("delete")
        case .nextKeyboard:
            DebugLog.log("next keyboard")
            keyboard.cancelTouches()
            advanceToNextInputMode()
        case .showPicker:
            DebugLog.log("letter order")
            keyboard.showPicker()
        }
    }
}
