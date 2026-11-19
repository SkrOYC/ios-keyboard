"""Compare Swift constants with the authoritative prototype script."""

import json
import re
from pathlib import Path

script = Path("docs/spec/hex7x4.html").read_text().split("<script>")[1].split("</script>")[0]
orders = Path("Keyboard/Core/LetterOrder.swift").read_text()
gestures = Path("Keyboard/Core/TouchMachine.swift").read_text()
tuning = Path("Keyboard/Core/KeyboardTuning.swift").read_text()
for prototype, swift in [("tw", "familiar"), ("split", "thumbSplit"), ("keepea", "keepEA")]:
    expected = re.search(rf"{prototype}: '([a-z]+)'", script)[1]
    actual = re.search(rf'case \.{swift}: return "([a-z]+)"', orders)[1]
    assert actual == expected, f"Letter order drift: {swift}"
    assert len(actual) == 26 and set(actual) == set("abcdefghijklmnopqrstuvwxyz")
expected_symbols = re.search(r"const SYMS = '((?:\\.|[^'\\])*)';", script)[1]
expected_symbols = re.sub(r"\\(.)", r"\1", expected_symbols)
actual_symbols = json.loads(re.search(r'static let symbols = ("(?:\\.|[^"\\])*")', orders)[1])
assert len(actual_symbols) == 26 and actual_symbols == expected_symbols, "Symbol layer drift"
for prototype, swift in [("thr", "swipeThreshold"), ("hold", "holdMilliseconds")]:
    expected = float(re.search(rf"{prototype}: (\d+)", script)[1])
    defaults = tuning.split("func defaultValue(tablet: Bool)")[1]
    actual = float(re.search(rf"case \.{swift}: return ([\d.]+)", defaults)[1])
    assert actual == expected, f"Gesture constant drift: {swift}"
assert 'max(40.0, 0.9 * tuning.swipeThreshold)' in gestures
assert '[",", "?", "!", "\'"]' in Path("Keyboard/Core/PopupModel.swift").read_text()
print("Spec parity: presets, symbol slots, popup characters, swipe, hold, and repeat constants OK")
