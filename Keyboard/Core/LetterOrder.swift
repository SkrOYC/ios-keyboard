import Foundation

enum LetterOrder: String, CaseIterable {
    case familiar
    case thumbSplit
    case keepEA

    var letters: String {
        switch self {
        case .familiar: return "wqzeasxtrdcgfnvyuhmiljbopk"
        case .thumbSplit: return "wqztnsxlrdcgfmvyuhaiejbopk"
        case .keepEA: return "wqzueaxyoijgtcvfrhmdnsbkpl"
        }
    }

    var title: String {
        switch self {
        case .familiar: return "Familiar"
        case .thumbSplit: return "Thumb-split"
        case .keepEA: return "Keep e·a"
        }
    }

    func letter(at index: Int) -> String { String(Array(letters)[index]) }
}

enum SymbolLayer {
    static let symbols = "()\"'-:;147*2580369#$%+=@&/"
    static func symbol(at index: Int) -> String { String(Array(symbols)[index]) }
}

enum KeyboardLayer: Equatable { case letters, symbols }

func keyLabel(_ key: HexKey, layer: KeyboardLayer, order: LetterOrder, capsLock: Bool = false) -> String {
    if key.isLayer { return layer == .letters ? "123" : "abc" }
    if key.isPeriod { return "." }
    guard let index = key.letterIndex else { return "" }
    if layer == .symbols { return SymbolLayer.symbol(at: index) }
    let letter = order.letter(at: index)
    return capsLock ? letter.uppercased() : letter
}
