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
        if let debugLabel { view.addSubview(debugLabel) }
        keyboard.onAction = { [weak self] action in self?.perform(action) }
        DebugLog.log("ready · hex 7×4")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboard.cancelTouches()
    }

    private func perform(_ action: KeyboardAction) {
        switch action {
        case .insert(let value):
            textDocumentProxy.insertText(value)
            DebugLog.log("insert")
        case .delete:
            textDocumentProxy.deleteBackward()
            DebugLog.log("delete")
        case .nextKeyboard: advanceToNextInputMode()
        case .showPicker: break
        }
    }
}
