import Foundation

func cursorUTF16Offset(graphemes: Int, before: String?, after: String?) -> Int {
    guard graphemes != 0 else { return 0 }
    let context = graphemes < 0 ? before : after
    guard let context else { return graphemes }
    let count = graphemes.magnitude
    let characters = graphemes < 0 ? Array(context.reversed()) : Array(context)
    var units = 0
    for character in characters.prefix(Int(min(count, UInt(characters.count)))) {
        units += String(character).utf16.count
    }
    // Unknown context is conservatively treated as one UTF-16 unit per step.
    let missing = count - min(count, UInt(characters.count))
    let total = min(UInt(Int.max), UInt(units) + missing)
    return graphemes < 0 ? -Int(total) : Int(total)
}
