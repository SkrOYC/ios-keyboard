import UIKit

/// iOS 26 Liquid Glass keyboard.
///
/// iOS 26 renders a Liquid Glass platter behind a keyboard extension
/// automatically when the extension is built with the iOS 26 SDK. That
/// material belongs to the system, so this controller keeps every background
/// clear and draws only the keycaps that sit on top of the platter.
///
/// The geometry and fills mirror the system keyboard: portrait keycaps are
/// 45 pt tall with 6 pt gaps, 6.5 pt side margins and 8.5 pt continuous
/// corners; landscape keycaps are 27.5 pt tall with 8 pt row gaps and
/// 7.5 pt corners. The values are based on Apple's iOS 26 metrics.
final class KeyboardViewController: UIInputViewController {

    // MARK: - Metrics

    private struct Metrics: Equatable {
        var side: CGFloat
        var gap: CGFloat
        var rowGap: CGFloat
        var keyHeight: CGFloat
        var bottom: CGFloat
        var cornerRadius: CGFloat
        var stripHeight: CGFloat
        var stripBottom: CGFloat
        var letterFontSize: CGFloat
        var functionSymbolSize: CGFloat
        var returnSymbolSize: CGFloat

        var keysHeight: CGFloat { 4 * keyHeight + 3 * rowGap + bottom }
        var stripArea: CGFloat { stripHeight + stripBottom }
        var height: CGFloat { (DebugLog.enabled ? stripArea : 0) + keysHeight }

        static let portrait = Metrics(
            side: 6.5, gap: 6, rowGap: 11, keyHeight: 45, bottom: 5,
            cornerRadius: 8.5, stripHeight: 33, stripBottom: 2,
            letterFontSize: 22.5, functionSymbolSize: 18, returnSymbolSize: 17.5
        )

        static let landscape = Metrics(
            side: 4, gap: 6, rowGap: 8, keyHeight: 27.5, bottom: 3,
            cornerRadius: 7.5, stripHeight: 33, stripBottom: 6,
            letterFontSize: 19, functionSymbolSize: 16, returnSymbolSize: 15.5
        )

        static func forWidth(_ width: CGFloat, landscape: Bool) -> Metrics {
            guard !landscape else { return .landscape }
            var metrics = Metrics.portrait
            if width >= 390 {
                metrics.side = 6.5
            } else if width >= 370 {
                metrics.side = 4.5
            } else {
                metrics.side = 3
            }
            return metrics
        }
    }

    // MARK: - Colors

    private enum Glass {
        /// iOS 26 keycap fill: opaque white in light mode, white @ 16% over the
        /// glass platter in dark mode.
        static let keyFill = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : .white
        }

        static let keyPressedFill = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.28)
                : UIColor(red: 0.847, green: 0.863, blue: 0.894, alpha: 1)
        }

        static let keyLabel = UIColor.label

        /// Apple's system keyboard action blue (#007AFF).
        static let actionFill = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        static let actionPressedFill = UIColor(red: 0, green: 0.384, blue: 0.8, alpha: 1)
    }

    // MARK: - State

    private let row0 = Array("qwertyuiop").map(String.init)
    private let row1 = Array("asdfghjkl").map(String.init)
    private let row2 = Array("zxcvbnm").map(String.init)

    private var metrics = Metrics.portrait
    private var heightConstraint: NSLayoutConstraint!

    private var keys: [KeyboardKeyButton] = []
    private var characterKeys: [CharacterKey] = []
    private var row0Keys: [CharacterKey] = []
    private var row1Keys: [CharacterKey] = []
    private var row2Keys: [CharacterKey] = []

    private var shiftKey: KeyboardKeyButton!
    private var deleteKey: RepeatKeyButton!
    private var globeKey: KeyboardKeyButton!
    private var spaceKey: KeyboardKeyButton!
    private var returnKey: KeyboardKeyButton!
    private var debugLabel: UILabel?

    private var isShifted = false
    private var isBuilt = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // The system's Liquid Glass platter lives behind the extension view.
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear

        heightConstraint = view.heightAnchor.constraint(equalToConstant: metrics.height)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        preferredContentSize.height = metrics.height

        buildKeyboard()
        isBuilt = true
        updateFunctionSymbols()
        applyShiftState()
        updateReturnKey()
        DebugLog.log("ready · iOS 26 glass")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        globeKey?.isHidden = !needsInputModeSwitchKey
        updateReturnKey()
        view.setNeedsLayout()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMetrics()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutKeys()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateReturnKey()
    }

    // MARK: - Construction

    private func buildKeyboard() {
        row0Keys = makeCharacterRow(row0)
        row1Keys = makeCharacterRow(row1)
        row2Keys = makeCharacterRow(row2)

        shiftKey = makeKey()
        shiftKey.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        shiftKey.accessibilityLabel = "Shift"

        deleteKey = RepeatKeyButton(frame: .zero)
        style(deleteKey)
        keys.append(deleteKey)
        view.addSubview(deleteKey)
        deleteKey.accessibilityLabel = "Delete"
        deleteKey.onTap = { [weak self] in self?.deleteOnce() }
        deleteKey.onRepeat = { [weak self] in self?.textDocumentProxy.deleteBackward() }

        globeKey = makeKey()
        globeKey.addTarget(self, action: #selector(globeTapped), for: .touchUpInside)
        globeKey.accessibilityLabel = "Next keyboard"
        globeKey.isHidden = !needsInputModeSwitchKey

        spaceKey = makeKey()
        spaceKey.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        spaceKey.accessibilityLabel = "Space"

        returnKey = makeKey()
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        returnKey.accessibilityLabel = "Return"

        if let label = DebugLog.makeLabel() {
            label.autoresizingMask = []
            view.addSubview(label)
            debugLabel = label
        }
    }

    private func makeCharacterRow(_ letters: [String]) -> [CharacterKey] {
        letters.map { letter in
            let key = CharacterKey(character: letter)
            key.accessibilityIdentifier = "key-\(letter)"
            style(key)
            key.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
            characterKeys.append(key)
            keys.append(key)
            view.addSubview(key)
            return key
        }
    }

    private func makeKey() -> KeyboardKeyButton {
        let key = KeyboardKeyButton(frame: .zero)
        style(key)
        keys.append(key)
        view.addSubview(key)
        return key
    }

    private func style(_ key: KeyboardKeyButton) {
        key.autoresizingMask = []
        key.normalFill = Glass.keyFill
        key.pressedFill = Glass.keyPressedFill
        key.cornerRadius = metrics.cornerRadius
        key.tintColor = Glass.keyLabel
        key.setTitleColor(Glass.keyLabel, for: .normal)
        key.titleLabel?.font = .systemFont(ofSize: metrics.letterFontSize, weight: .regular)
    }

    // MARK: - Layout

    private func updateMetrics() {
        guard isBuilt else { return }
        let landscape = traitCollection.verticalSizeClass == .compact
        let new = Metrics.forWidth(view.bounds.width, landscape: landscape)
        guard new != metrics else { return }

        metrics = new
        heightConstraint.constant = new.height
        preferredContentSize.height = new.height

        for key in keys {
            key.cornerRadius = new.cornerRadius
        }
        for key in characterKeys {
            key.titleLabel?.font = .systemFont(ofSize: new.letterFontSize, weight: .regular)
        }
        updateFunctionSymbols()
    }

    private func layoutKeys() {
        guard isBuilt else { return }
        let width = view.bounds.width
        guard width > 0 else { return }

        let m = metrics
        let strip = DebugLog.enabled ? m.stripArea : 0
        let letterWidth = (width - 2 * m.side - 9 * m.gap) / 10
        let modifierWidth = letterWidth * 1.34
        let rowY = { (row: Int) in strip + CGFloat(row) * (m.keyHeight + m.rowGap) }

        for (index, key) in row0Keys.enumerated() {
            key.frame = CGRect(
                x: m.side + CGFloat(index) * (letterWidth + m.gap),
                y: rowY(0),
                width: letterWidth,
                height: m.keyHeight
            )
        }

        let row1X = m.side + (letterWidth + m.gap) / 2
        for (index, key) in row1Keys.enumerated() {
            key.frame = CGRect(
                x: row1X + CGFloat(index) * (letterWidth + m.gap),
                y: rowY(1),
                width: letterWidth,
                height: m.keyHeight
            )
        }

        shiftKey.frame = CGRect(x: m.side, y: rowY(2), width: modifierWidth, height: m.keyHeight)
        deleteKey.frame = CGRect(
            x: width - m.side - modifierWidth,
            y: rowY(2),
            width: modifierWidth,
            height: m.keyHeight
        )

        let lettersWidth = 7 * letterWidth + 6 * m.gap
        let lettersX = (width - lettersWidth) / 2
        for (index, key) in row2Keys.enumerated() {
            key.frame = CGRect(
                x: lettersX + CGFloat(index) * (letterWidth + m.gap),
                y: rowY(2),
                width: letterWidth,
                height: m.keyHeight
            )
        }

        let showsGlobe = needsInputModeSwitchKey
        globeKey.isHidden = !showsGlobe
        var left = m.side
        if showsGlobe {
            globeKey.frame = CGRect(x: left, y: rowY(3), width: modifierWidth, height: m.keyHeight)
            left += modifierWidth + m.gap
        }

        let returnWidth = letterWidth * (showsGlobe ? 2.18 : 2.40)
        let returnX = width - m.side - returnWidth
        returnKey.frame = CGRect(x: returnX, y: rowY(3), width: returnWidth, height: m.keyHeight)
        spaceKey.frame = CGRect(
            x: left,
            y: rowY(3),
            width: max(letterWidth, returnX - m.gap - left),
            height: m.keyHeight
        )

        if let label = debugLabel {
            label.isHidden = strip == 0
            label.frame = CGRect(
                x: m.side,
                y: m.stripHeight > 14 ? (m.stripHeight - 14) / 2 : 0,
                width: width - 2 * m.side,
                height: 14
            )
        }
    }

    // MARK: - Key state

    private func updateFunctionSymbols() {
        shiftKey.setImage(symbol(isShifted ? "shift.fill" : "shift", size: metrics.functionSymbolSize), for: .normal)
        deleteKey.setImage(symbol("delete.left", size: metrics.functionSymbolSize), for: .normal)
        globeKey.setImage(symbol("globe", size: metrics.functionSymbolSize), for: .normal)
        updateReturnKey()
    }

    private func applyShiftState() {
        shiftKey.setImage(symbol(isShifted ? "shift.fill" : "shift", size: metrics.functionSymbolSize), for: .normal)
        shiftKey.accessibilityValue = isShifted ? "On" : "Off"
        for key in characterKeys {
            key.setTitle(isShifted ? key.character.uppercased() : key.character, for: .normal)
            key.accessibilityLabel = isShifted ? key.character.uppercased() : key.character
        }
    }

    private var returnIsAction: Bool {
        (textDocumentProxy.returnKeyType ?? .default) != .default
    }

    private func updateReturnKey() {
        let action = returnIsAction
        returnKey.normalFill = action ? Glass.actionFill : Glass.keyFill
        returnKey.pressedFill = action ? Glass.actionPressedFill : Glass.keyPressedFill
        returnKey.tintColor = action ? .white : Glass.keyLabel
        returnKey.setTitleColor(action ? .white : Glass.keyLabel, for: .normal)

        if let image = symbol(
            "return",
            size: metrics.returnSymbolSize,
            weight: action ? .medium : .regular
        ) {
            returnKey.setImage(image, for: .normal)
            returnKey.setTitle(nil, for: .normal)
        } else {
            returnKey.setImage(nil, for: .normal)
            returnKey.setTitle("return", for: .normal)
            returnKey.titleLabel?.font = .systemFont(ofSize: metrics.returnSymbolSize, weight: action ? .medium : .regular)
        }
    }

    private func symbol(
        _ name: String,
        size: CGFloat,
        weight: UIImage.SymbolWeight = .regular
    ) -> UIImage? {
        UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        )
    }

    // MARK: - Actions

    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        if isShifted {
            isShifted = false
            applyShiftState()
        }
        DebugLog.log(text == "\n" ? "return" : "type \(text)")
    }

    private func deleteOnce() {
        textDocumentProxy.deleteBackward()
        DebugLog.log("delete")
    }

    @objc private func letterTapped(_ sender: UIButton) {
        guard let key = sender as? CharacterKey else { return }
        insert(isShifted ? key.character.uppercased() : key.character)
    }

    @objc private func shiftTapped() {
        isShifted.toggle()
        applyShiftState()
        DebugLog.log(isShifted ? "shift on" : "shift off")
    }

    @objc private func globeTapped() {
        advanceToNextInputMode()
        DebugLog.log("globe")
    }

    @objc private func spaceTapped() {
        insert(" ")
    }

    @objc private func returnTapped() {
        insert("\n")
    }
}

// MARK: - Key views

private class KeyboardKeyButton: UIButton {
    var normalFill: UIColor = .clear {
        didSet { if !isHighlighted { backgroundColor = normalFill } }
    }

    var pressedFill: UIColor = .clear {
        didSet { if isHighlighted { backgroundColor = pressedFill } }
    }

    var cornerRadius: CGFloat = 8.5 {
        didSet { layer.cornerRadius = cornerRadius }
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? pressedFill : normalFill }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class CharacterKey: KeyboardKeyButton {
    let character: String

    init(character: String) {
        self.character = character
        super.init(frame: .zero)
        setTitle(character, for: .normal)
        accessibilityLabel = character
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Delete key: one delete on tap, auto-repeat after 0.4 s at 0.08 s intervals.
private final class RepeatKeyButton: KeyboardKeyButton {
    var onTap: (() -> Void)?
    var onRepeat: (() -> Void)?

    private var initialTimer: Timer?
    private var repeatTimer: Timer?
    private var didRepeat = false

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard super.beginTracking(touch, with: event) else { return false }
        startTimers()
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        stopTimers()
        if !didRepeat, let touch, bounds.contains(touch.location(in: self)) {
            onTap?()
        }
        super.endTracking(touch, with: event)
    }

    override func cancelTracking(with event: UIEvent?) {
        stopTimers()
        super.cancelTracking(with: event)
    }

    private func startTimers() {
        stopTimers()
        didRepeat = false

        let initial = Timer(timeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self, self.isTracking else { return }
            self.didRepeat = true
            self.onRepeat?()

            let repeating = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.onRepeat?()
            }
            self.repeatTimer = repeating
            RunLoop.main.add(repeating, forMode: .common)
        }
        initialTimer = initial
        RunLoop.main.add(initial, forMode: .common)
    }

    private func stopTimers() {
        initialTimer?.invalidate()
        initialTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
