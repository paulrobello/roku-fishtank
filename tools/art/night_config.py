# /// script
# requires-python = ">=3.12"
# ///
"""Copy the P3.7 glow overlay placements from docs/art/placement-proposal.json into
config/night.json "glow.items" (the device zip has no docs/). Re-run after reef_decor.py
moves the art: ``uv run tools/art/night_config.py``. Every other key is left as is.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = ROOT / "docs" / "art" / "placement-proposal.json"
NIGHT = ROOT / "config" / "night.json"


def glow_items(proposal: dict[str, Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for key, v in proposal.items():
        if not key.startswith("glow_") or not isinstance(v, dict):
            continue
        items.append(
            {
                "id": key,
                "uri": "pkg:/" + v["file"],
                "layer": v["layer"],
                "over": v["over"],
                "x": v["x"],
                "y": v["y"],
                "width": v["width"],
                "height": v["height"],
                "scale": v.get("scale", 1.0),
            }
        )
    return items


def main() -> None:
    proposal: dict[str, Any] = json.loads(PROPOSAL.read_text())
    night: dict[str, Any] = json.loads(NIGHT.read_text())
    night["glow"]["items"] = glow_items(proposal)
    lines = [json.dumps(i, separators=(", ", ": ")) for i in night["glow"]["items"]]
    night["glow"]["items"] = "__ITEMS__"
    text = json.dumps(night, indent=2)
    text = text.replace('"__ITEMS__"', "[\n      " + ",\n      ".join(lines) + "\n    ]")
    NIGHT.write_text(text + "\n")
    print(f"night.json: {len(lines)} glow items")


if __name__ == "__main__":
    main()
