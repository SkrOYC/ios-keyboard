import UIKit

/// Minimal QWERTY keyboard. Plain UIKit (no SwiftUI) to keep the extension's
/// memory footprint small — keyboard extensions are killed silently above ~50–70 MB.
final class KeyboardViewController: UIInputViewController {

    private let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    private var letterButtons: [UIButton] = []
    private var shiftButton: UIButton!
    private var nextKeyboardButton: UIButton!
    private var isShifted = false {
        didSet { updateLetterTitles() }
    }
    private var deleteTimer: Timer?

    private let rowHeight: CGFloat = 44
    private let spacing: CGFloat = 6

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        DebugLog.log("viewDidLoad")
    }

    override func viewWillLayoutSubviews() {
        // Only show 🌐 when iOS doesn't already provide one (e.g. on Face ID iPhones it does).
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        DebugLog.log("memory warning")
    }

    // MARK: - Layout

    private func buildLayout() {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = spacing
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false

        // Row 1 and 2: letters
        rows.addArrangedSubview(makeRow(letterRows[0].map(makeLetterKey)))
        rows.addArrangedSubview(makeRow(letterRows[1].map(makeLetterKey)))

        // Row 3: shift + letters + delete
        shiftButton = makeKey(title: "⇧", action: #selector(shiftTapped))
        let deleteButton = makeKey(title: "⌫", action: nil)
        deleteButton.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        deleteButton.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        let row3 = makeRow([shiftButton] + letterRows[2].map(makeLetterKey) + [deleteButton])
        rows.addArrangedSubview(row3)

        // Row 4: globe + space + return
        nextKeyboardButton = makeKey(title: "🌐", action: nil)
        // Apple's recommended wiring: tap = next keyboard, long-press = picker.
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        let space = makeKey(title: "space", action: #selector(spaceTapped))
        let ret = makeKey(title: "return", action: #selector(returnTapped))
        let row4 = UIStackView(arrangedSubviews: [nextKeyboardButton, space, ret])
        row4.spacing = spacing
        row4.distribution = .fill
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        ret.widthAnchor.constraint(equalToConstant: 80).isActive = true
        rows.addArrangedSubview(row4)

        let container = UIStackView(arrangedSubviews: [rows])
        container.axis = .vertical
        container.spacing = 4
        container.translatesAutoresizingMaskIntoConstraints = false
        if let debugLabel = DebugLog.makeLabel() {
            container.insertArrangedSubview(debugLabel, at: 0)
        }
        view.addSubview(container)

        let rowCount = CGFloat(4)
        let keysHeight = rowCount * rowHeight + (rowCount - 1) * spacing
        let heightConstraint = rows.heightAnchor.constraint(equalToConstant: keysHeight)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            heightConstraint
        ])
    }

    private func makeRow(_ keys: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: keys)
        row.axis = .horizontal
        row.spacing = spacing
        row.distribution = .fillEqually
        return row
    }

    private func makeLetterKey(_ letter: String) -> UIButton {
        let button = makeKey(title: letter, action: #selector(letterTapped(_:)))
        letterButtons.append(button)
        return button
    }

    private func makeKey(title: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: title.count == 1 ? 22 : 16)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 5
        if let action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        return button
    }

    private func updateLetterTitles() {
        for button in letterButtons {
            guard let title = button.title(for: .normal) else { continue }
            button.setTitle(isShifted ? title.uppercased() : title.lowercased(), for: .normal)
        }
        shiftButton.backgroundColor = isShifted ? .systemGray3 : .secondarySystemBackground
    }

    // MARK: - Actions

    @objc private func letterTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal) else { return }
        textDocumentProxy.insertText(text)
        DebugLog.log("key \(text)")
        if isShifted { isShifted = false } // one-shot shift
    }

    @objc private func shiftTapped() {
        isShifted.toggle()
    }

    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func deleteDown() {
        textDocumentProxy.deleteBackward()
        deleteTimer?.invalidate()
        // Auto-repeat after a short hold.
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}
