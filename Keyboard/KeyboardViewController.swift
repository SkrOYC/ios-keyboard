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
        keyboard.onAction = { [weak self] action in self?.perform(action) }
        keyboard.onDiagnostic = { DebugLog.log($0) }
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
        guard view.bounds.width > 0 else { return }
        let layout = HexLayout(
            containerWidth: Double(view.bounds.width),
            leadingInset: Double(view.safeAreaInsets.left),
            trailingInset: Double(view.safeAreaInsets.right),
            compactHeight: traitCollection.verticalSizeClass == .compact,
            tablet: traitCollection.userInterfaceIdiom == .pad
        )
        let height = CGFloat(layout.height) + stripHeight
        if heightConstraint.constant != height {
            heightConstraint.constant = height
            preferredContentSize.height = height
        }
        keyboard.frame = CGRect(x: layout.originX, y: Double(stripHeight), width: layout.width, height: layout.height)
        debugLabel?.frame = CGRect(x: 12, y: 4, width: view.bounds.width - 24, height: 14)
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
