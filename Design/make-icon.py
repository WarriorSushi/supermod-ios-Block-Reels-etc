"""Compose the editable mark over each appearance's full-bleed background."""
from pathlib import Path

root = Path(__file__).resolve().parent
mark = (root / "passage-mark.svg").read_text()
colors = {
    "standard": ("#353b31", "#10130f"),
    "dark": ("#22281f", "#090b08"),
    "tinted": ("#343434", "#080808"),
}
for appearance, (top, bottom) in colors.items():
    artwork = f"""
    <defs><radialGradient id="ground" cx=".34" cy=".17" r=".92">
      <stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>
    </radialGradient></defs>
    <rect id="ground-layer" width="1024" height="1024" fill="url(#ground)"/>
    """
    (root / f"AppIcon-{appearance}.svg").write_text(mark.replace("<defs>", artwork + "<defs>", 1))
