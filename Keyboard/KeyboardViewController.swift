import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = HexKeyboardView()
    private var heightConstraint: NSLayoutConstraint!
    private var tuning = KeyboardTuning()
    private var reportedLayout = false
    #if DEVTOOLS
    private var tuningStrip: TuningStripView?
    private let stripHeight: CGFloat = 60
    #else
    private let stripHeight: CGFloat = 0
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 283)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        view.addSubview(keyboard)
        let store = TuningStore(tablet: traitCollection.userInterfaceIdiom == .pad)
        tuning = store.tuning
        #if DEVTOOLS
        let strip = TuningStripView(store: store)
        strip.onChange = { [weak self] tuning in
            guard let self else { return }
            self.keyboard.cancelTouches()
            self.tuning = tuning
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        tuningStrip = strip
        view.addSubview(strip)
        keyboard.onDiagnostic = { DebugLog.log($0) }
        #endif
        keyboard.onAction = { [weak self] action in self?.perform(action) }
        diagnose("ready · hex 7×4")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reportedLayout = false
        diagnose("appearing")
        keyboard.needsGlobe = needsInputModeSwitchKey
        view.setNeedsLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        keyboard.isPresentationActive = true
        diagnose("visible")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        keyboard.needsGlobe = needsInputModeSwitchKey
        guard view.bounds.width > 0 else { return }
        let layout = HexLayout(
            containerWidth: Double(view.bounds.width),
            leadingInset: Double(view.safeAreaInsets.left),
            trailingInset: Double(view.safeAreaInsets.right),
            shorterSide: Double(min((view.window?.screen.bounds ?? view.bounds).width,
                                    (view.window?.screen.bounds ?? view.bounds).height)),
            tablet: traitCollection.userInterfaceIdiom == .pad,
            tuning: tuning
        )
        let height = CGFloat(layout.height) + stripHeight
        if heightConstraint.constant != height {
            heightConstraint.constant = height
            preferredContentSize.height = height
        }
        keyboard.frame = CGRect(x: layout.originX, y: Double(stripHeight), width: layout.width, height: layout.height)
        keyboard.configure(layout: layout, tuning: tuning)
        #if DEVTOOLS
        tuningStrip?.frame = CGRect(x: view.safeAreaInsets.left + 8, y: 0,
                                   width: view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 16,
                                   height: stripHeight)
        #endif
        if !reportedLayout {
            reportedLayout = true
            diagnose("layout · \(view.bounds.width)×\(view.bounds.height) · \(layout.isSplit ? "split" : "unified") · window=\(view.window != nil)")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboard.isPresentationActive = false
        keyboard.cancelTouches()
        keyboard.resetCapsLock()
        diagnose("hidden")
    }

    private func perform(_ action: KeyboardAction) {
        switch action {
        case .insert(let value):
            textDocumentProxy.insertText(value)
            switch value {
            case " ": diagnose("space")
            case "\n": diagnose("return")
            default: diagnose("insert")
            }
        case .delete:
            textDocumentProxy.deleteBackward()
            diagnose("delete")
        case .nextKeyboard:
            diagnose("next keyboard")
            keyboard.cancelTouches()
            advanceToNextInputMode()
        case .showPicker:
            diagnose("letter order")
            keyboard.showPicker()
        case .moveCursor(let graphemes):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: cursorUTF16Offset(
                graphemes: graphemes, before: textDocumentProxy.documentContextBeforeInput,
                after: textDocumentProxy.documentContextAfterInput))
            diagnose("cursor")
        }
    }

    private func diagnose(_ message: String) {
        #if DEVTOOLS
        DebugLog.log(message)
        #endif
    }
}
