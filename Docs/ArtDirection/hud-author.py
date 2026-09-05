#!/usr/bin/env python3
"""Recreate original, editable #43 HUD proposals using only Python's stdlib.

Run: python3 Docs/ArtDirection/hud-author.py
PNG previews are rendered separately with an available local SVG renderer.
These are design schematics, not app captures or device-validation evidence.
"""
from html import escape
from pathlib import Path
import xml.etree.ElementTree as ET

OUT = Path(__file__).parent
C = dict(cream="#F7F1E5", soil="#31291F", leaf="#315B3A", clay="#C47151", straw="#D8AC55")


class Board:
    def __init__(self, name, width, height):
        self.name, self.width, self.height = name, width, height
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
                      f'<title id="title">{escape(name.replace("-", " "))} — proposed Fazendinha HUD</title>',
                      '<desc id="desc">Original code-drawn schematic. Proposed design, not an app capture or production art. Orientations and safe areas are schematic, not device validated or enforced. Touch controls are at least 44 logical points; ordinary player text is at least 17 points. Small captions are design annotations.</desc>']
        self.targets = []
        self.centers = []
        self.rect(0, 0, width, height, C["cream"], radius=0)

    def rect(self, x, y, w, h, fill, stroke="none", radius=12, extra=""):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" {extra}/>')

    def text(self, x, y, value, size=17, color=None, weight=400, anchor="start"):
        self.parts.append(f'<text x="{x}" y="{y}" fill="{color or C["soil"]}" font-family="Arial, sans-serif" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}">{escape(value)}</text>')

    def circle(self, x, y, r, fill, stroke="none", extra=""):
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" {extra}/>')

    def path(self, d, fill="none", stroke=None, width=2):
        self.parts.append(f'<path d="{d}" fill="{fill}" stroke="{stroke or C["soil"]}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')

    def button(self, x, y, w, h, label, selected=False, filled=False, disabled=False, size=17):
        assert w >= 44 and h >= 44
        self.targets.append((x, y, w, h))
        fill = C["leaf"] if filled else C["cream"]
        self.rect(x, y, w, h, fill, C["soil"] if disabled else C["leaf"], extra=f'stroke-width="{2 if selected else 1}" data-touch-target="true" data-disabled="{str(disabled).lower()}"')
        if selected:
            self.rect(x + 4, y + 4, w - 8, h - 8, "none", C["leaf"], 8)
        self.text(x + w / 2, y + h / 2 + size * .35, label, size, C["cream"] if filled else C["soil"], 700 if selected or filled else 400, "middle")

    def plant(self, x, y, size):
        self.path(f'M{x},{y + size * .45} L{x},{y - size * .5}', stroke=C["leaf"], width=2)
        self.path(f'M{x},{y} Q{x - size * .7},{y - size * .8} {x - size * .75},{y - size * .2} Q{x - size * .25},{y + size * .2} {x},{y}', C["leaf"], C["leaf"], 1)
        self.path(f'M{x},{y - size * .2} Q{x + size * .65},{y - size} {x + size * .75},{y - size * .4} Q{x + size * .2},{y} {x},{y - size * .2}', C["leaf"], C["leaf"], 1)
        self.circle(x - size * .35, y + size * .22, size * .22, C["clay"], C["soil"])
        self.circle(x + size * .32, y + size * .02, size * .24, C["clay"], C["soil"])

    def farm(self, x, y, w, h):
        self.rect(x, y, w, h, "#E6E7D5", radius=24)
        self.text(x + 13, y + h - 6, "FARM SCHEMATIC · 6 selectable fields", 10, C["leaf"], 700)
        # Decorative barn and lane sit behind the six unobscured plot centers.
        bx, by, bw, bh = x + w * .12, y + h * .12, w * .18, h * .19
        self.rect(bx, by, bw, bh, C["cream"], C["soil"], 3)
        self.path(f'M{bx - 7},{by} L{bx + bw / 2},{by - bh * .55} L{bx + bw + 7},{by} Z', C["clay"], C["soil"], 1)
        self.rect(bx + bw * .35, by + bh * .45, bw * .3, bh * .55, C["cream"], C["soil"], 2)
        self.path(f'M{bx + bw * .38},{by + bh * .5} L{bx + bw * .62},{by + bh * .94} M{bx + bw * .62},{by + bh * .5} L{bx + bw * .38},{by + bh * .94}', width=1)
        self.rect(x + w * .08, y + h * .345, w * .84, h * .04, C["cream"], radius=8)
        for tx, ty in [(x + w * .72, y + h * .17), (x + w * .87, y + h * .22)]:
            self.path(f'M{tx},{ty} v{h * .11}', stroke=C["soil"], width=4)
            self.circle(tx, ty, h * .065, C["leaf"])
            self.circle(tx - h * .026, ty - h * .018, h * .035, "#658161")
        for i in range(6):
            cx = x + w * ((i % 3 + .5) / 3)
            cy = y + h * (.54 if i < 3 else .81)
            self.centers.append((cx, cy))
            pw, ph = w * .255, h * .205
            assert pw >= 44 and ph >= 44
            self.rect(cx - pw / 2, cy - ph / 2, pw, ph, "#BA9B76", C["soil"], 10)
            for offset in [-.25, .05]:
                self.path(f'M{cx - pw * .36},{cy + ph * offset} h{pw * .72}', stroke="#D9BE99", width=2)
            if i == 4:
                self.rect(cx - pw / 2 - 4, cy - ph / 2 - 4, pw + 8, ph + 8, "none", C["leaf"], 14, 'stroke-width="3"')
                self.circle(cx, cy, 13, C["cream"], C["leaf"])
                self.text(cx, cy + 6, "5", 17, C["soil"], 700, "middle")
                self.path(f'M{cx + pw * .32},{cy - ph * .35} l4,4 l7,-8', stroke=C["cream"], width=2)
            else:
                for px in [-.24, .24]:
                    self.plant(cx + pw * px, cy, min(pw * .22, ph * .43))

    def save(self):
        self.parts.append('</svg>')
        path = OUT / f'{self.name}.svg'
        path.write_text('\n'.join(self.parts) + '\n')
        ET.parse(path)
        for x, y, w, h in self.targets:
            assert 0 <= x <= self.width - w and 0 <= y <= self.height - h
        for i, (x, y, w, h) in enumerate(self.targets):
            for x2, y2, w2, h2 in self.targets[i + 1:]:
                assert x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y
        print(f'{path.name}: {self.width}×{self.height}; {len(self.targets)} controls ≥44pt; valid SVG XML')


def compose(name, w, h, landscape):
    b = Board(name, w, h)
    phone = w < 700
    pad = 16 if phone else 24
    b.rect(8, 8, w - 16, h - 16, "none", "#B6AD9F", 14, 'stroke-dasharray="3 5"')
    b.text(pad, h - 12, "PROPOSED · safe area schematic · not device validated", 9 if phone else 11)
    b.text(pad + 2, 44 if phone else 58, "Fazendinha", 24 if phone else 32, C["soil"], 700)
    if landscape:
        panel_w = 210 if phone else 274
        panel_x = w - pad - panel_w
        field_w = panel_x - pad - 16
        field_y = 119 if phone else 169
        field_h = h - field_y - 31 if phone else h - field_y - 53
        toolbar_y = 65 if phone else 94
        b.button(pad, toolbar_y, 97 if phone else 136, 44 if phone else 52, "Market")
        b.button(pad + (105 if phone else 148), toolbar_y, 83 if phone else 122, 44 if phone else 52, "Fields")
        b.button(pad + (196 if phone else 282), toolbar_y, 132 if phone else 167, 44 if phone else 52, "Reset camera")
        b.farm(pad, field_y, field_w, field_h)
        panel_y, panel_h = (18, h - 48) if phone else (24, h - 64)
        b.rect(panel_x, panel_y, panel_w, panel_h, C["cream"], C["leaf"], 20)
        ix, inner = panel_x + 14, panel_w - 28
        b.text(ix, panel_y + 32, "120 coins", 19, C["soil"], 700)
        b.path(f'M{ix},{panel_y + 47} h{inner}', stroke="#C6BDAD", width=1)
        b.text(ix, panel_y + 76, "✓ Field 5 selected", 17, C["leaf"], 700)
        b.text(ix, panel_y + 104, "Ready to plant" if phone else "Fresh soil,", 19)
        if not phone:
            b.text(ix, panel_y + 129, "ready to plant", 19)
        # Stacked controls preserve 17pt names in narrow phone panels.
        seed_y = panel_y + (122 if phone else 185)
        for i, seed in enumerate(["Grain", "Rice", "Tomato"]):
            selected = i == 2
            b.button(ix, seed_y + i * (47 if phone else 49), inner, 44, ("✓ " if selected else "") + seed, selected=selected)
        action_y = panel_y + panel_h - 58
        if not phone:
            b.text(ix, seed_y + 184, "Tomato · 8 coins", 17)
            b.text(ix, seed_y + 211, "Grows in 90 seconds", 17)
        b.button(ix, action_y, inner, 44, "Plant · 8 coins", filled=True)
    else:
        coin_w = 100 if phone else 140
        b.rect(w - pad - coin_w, 20 if phone else 27, coin_w, 40 if phone else 48, C["cream"], C["leaf"], 14)
        b.text(w - pad - coin_w / 2, 46 if phone else 58, "120 coins", 17 if phone else 22, anchor="middle")
        toolbar_y = 73 if phone else 99
        sizes = [107, 99, 121] if phone else [202, 202, 292]
        cur = pad
        for label, size in zip(["Market", "Fields", "Reset camera"], sizes):
            b.button(cur, toolbar_y, size, 44 if phone else 52, label)
            cur += size + (8 if phone else 12)
        farm_y, farm_h = (127, 245) if phone else (169, 455)
        b.farm(pad, farm_y, w - pad * 2, farm_h)
        panel_y, panel_h = (386, 246) if phone else (650, 333)
        b.rect(pad, panel_y, w - pad * 2, panel_h, C["cream"], C["leaf"], 20)
        ix, inner = pad + 14, w - pad * 2 - 28
        b.text(ix, panel_y + 30, "✓ Field 5 selected", 17 if phone else 22, C["leaf"], 700)
        b.text(ix, panel_y + 61, "Fresh soil, ready to plant", 19 if phone else 27)
        seed_y, gap = panel_y + (81 if phone else 99), 8 if phone else 12
        seed_w = (inner - gap * 2) / 3
        for i, seed in enumerate(["Grain", "Rice", "Tomato"]):
            b.button(ix + i * (seed_w + gap), seed_y, seed_w, 52 if phone else 64, ("✓ " if i == 2 else "") + seed, selected=i == 2)
        b.text(ix, seed_y + (79 if phone else 100), "Tomato · 8 coins · 90 seconds", 17 if phone else 22)
        b.button(ix, panel_y + panel_h - 64, inner, 48, "Plant", filled=True, size=17 if phone else 22)
    # Every field center is outside every overlaid touch target and in the visible farm.
    assert len(b.centers) == 6
    for cx, cy in b.centers:
        assert not any(x <= cx <= x + tw and y <= cy <= y + th for x, y, tw, th in b.targets)
    b.save()


def states():
    b = Board("hud-states", 1600, 1220)
    b.text(54, 61, "Quiet, readable feedback", 36, weight=700)
    b.text(54, 99, "PROPOSED HUD STATES · English / Português · original schematic, not app captures", 18)
    titles = ["01 / EMPTY", "02 / GROWING", "03 / READY", "04 / SELECTED", "05 / UNAVAILABLE", "06 / SAVE FAILURE"]
    lines = [
        ["Fresh soil, ready to plant", "Terra pronta para plantar"],
        ["Tomato is growing", "Tomate está crescendo", "45 seconds remaining", "Faltam 45 segundos"],
        ["◆ Tomato is ready!", "◆ Tomate pronto para colher!"],
        ["✓ Tomato selected", "✓ Tomate selecionado", "Double border + checkmark", "Borda dupla + marca de seleção"],
        ["8 coins needed · Balance 4", "Precisa de 8 moedas · Saldo 4", "Reason stays readable", "O motivo continua legível"],
        ["Farm update / Atualização da fazenda", "Couldn’t save / Não foi possível salvar", "Crop and 120 coins stay unchanged.", "Plantação e 120 moedas preservadas."]]
    for i, title in enumerate(titles):
        x, y = 54 + (i % 3) * 506, 135 + (i // 3) * 325
        b.rect(x, y, 478, 294, C["cream"], C["leaf"], 20, 'stroke-width="2"' if i == 3 else '')
        b.text(x + 22, y + 39, title, 20, C["leaf"], 700)
        for j, line in enumerate(lines[i]):
            b.text(x + 22, y + 79 + j * 29, line, 18 if i == 5 else 20, weight=700 if j == 0 else 400)
        if i in [0, 2, 4, 5]:
            b.button(x + 22, y + 219, 434, 50, ["Plant / Plantar", "", "Harvest / Colher", "", "Plant / Plantar — unavailable", "OK"][i], filled=i in [0, 2], disabled=i == 4)
        if i == 1:
            b.rect(x + 22, y + 211, 434, 14, "#E1D9CB", C["leaf"], 7)
            b.rect(x + 22, y + 211, 217, 14, C["leaf"], radius=7)
            b.text(x + 22, y + 261, "50% · status remains visible without motion", 17)
        if i == 3:
            b.button(x + 22, y + 219, 434, 50, "✓ Tomato / Tomate", selected=True)
        if i == 5:
            b.text(x + 22, y + 199, "Crop/balance retained; no success pulse", 17)
    b.text(54, 824, "ENLARGED TEXT / TEXTO AMPLIADO", 24, C["leaf"], 700)
    for i, lang in enumerate(["EN", "PT"]):
        x, y, cw = 54 + i * 759, 846, 731
        b.rect(x, y, cw, 300, C["cream"], C["leaf"], 20)
        b.text(x + 24, y + 45, "Field 5" if i == 0 else "Canteiro 5", 30, weight=700)
        b.text(x + 24, y + 86, "Fresh soil, ready to plant" if i == 0 else "Terra pronta para plantar", 27)
        b.button(x + 24, y + 109, cw - 76, 54, "Plant" if i == 0 else "Plantar", filled=True, size=27)
        b.button(x + 24, y + 178, cw - 76, 54, "Grain · 3 coins" if i == 0 else "Trigo · 3 moedas", size=27)
        b.text(x + 24, y + 275, "↓ Scroll: Rice, Tomato" if i == 0 else "↓ Role: Arroz, Tomate", 25)
        b.rect(x + cw - 27, y + 26, 5, 245, "#D8D0C3", radius=2)
        b.rect(x + cw - 27, y + 26, 5, 91, C["leaf"], radius=2)
    b.text(54, 1185, "Opaque panels · ≥44pt targets · scroll rather than shrink · selected/ready/error states use text or shape · no avatar or new navigation", 17)
    b.save()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for spec in [("hud-phone-landscape", 667, 375, True), ("hud-phone-portrait", 375, 667, False),
                 ("hud-tablet-landscape", 1024, 768, True), ("hud-tablet-portrait", 768, 1024, False)]:
        compose(*spec)
    states()
