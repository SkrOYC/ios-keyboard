"""Generate independent reference geometry and assert the prototype invariants."""

import argparse
import json
import math
from pathlib import Path

FIXTURE = Path("KeyboardLogicTests/Fixtures/geometry.json")


def generate():
    width, height, gap = 1320, 883, 8
    cosine = math.cos(math.pi / 6)
    a = (855 - 3.5 * gap) / 9
    d = 2 * a + gap
    cp = 0.8660254 * d
    sx = 1292 / (6 * cp + 2 * a / cosine)
    radius = a / cosine * sx
    x0 = (width - (6 * cp * sx + 2 * radius)) / 2 + radius
    y0 = 14 + a
    keys = []
    for column in range(7):
        for row in range(4):
            cx = x0 + column * cp * sx
            cy = y0 + row * d + (d / 2 if column % 2 else 0)
            inner = a - 6
            r = inner / cosine * sx
            polygon = [{"x": cx + x, "y": cy + y} for x, y in
                       [(r, 0), (r / 2, inner), (-r / 2, inner),
                        (-r, 0), (-r / 2, -inner), (r / 2, -inner)]]
            assert 0 <= cx <= width and 0 <= cy <= height
            for point in polygon:
                assert 6 <= point["x"] <= width - 6
                assert 6 <= point["y"] <= height - 6
            # Undo the intentional horizontal stretch before measuring hex distances.
            for index, p in enumerate(polygon):
                q = polygon[(index + 1) % 6]
                px, py = (p["x"] - cx) / sx, p["y"] - cy
                qx, qy = (q["x"] - cx) / sx, q["y"] - cy
                apothem = abs(px * qy - py * qx) / math.hypot(qx - px, qy - py)
                assert math.isclose(apothem, inner, abs_tol=1e-8)
            keys.append({"slot": column * 4 + row, "center": {"x": cx, "y": cy}, "polygon": polygon})
    for key in keys:
        column, row = divmod(key["slot"], 4)
        center = key["center"]
        mirror = keys[(6 - column) * 4 + row]["center"]
        assert math.isclose(center["x"] + mirror["x"], width, abs_tol=1e-8)
        assert math.isclose(center["y"], mirror["y"], abs_tol=1e-8)
        for other in keys:
            oc, _ = divmod(other["slot"], 4)
            dx = (other["center"]["x"] - center["x"]) / sx
            dy = other["center"]["y"] - center["y"]
            if (oc == column and math.isclose(abs(dy), d, abs_tol=1e-8)) or (abs(oc - column) == 1 and math.isclose(abs(dy), d / 2, abs_tol=1e-8)):
                assert math.isclose(math.hypot(dx, dy), d, abs_tol=1e-5)
    return {"width": width, "height": height, "keys": keys}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps(generate(), indent=2) + "\n"
    if args.check:
        assert FIXTURE.read_text() == content, "Geometry fixture is stale; regenerate it"
    else:
        FIXTURE.write_text(content)
    print("Geometry fixture: bounds, apothems, neighbours, and symmetry OK")
