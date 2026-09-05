# Art direction asset provenance

These are design references for issue [#43](https://github.com/csambrosio01/fazendinha/issues/43), not production assets or screenshots. See [the direction](../ART_UX_DIRECTION.md) for the normative design guidance.

| File | Origin | Intended use |
| --- | --- | --- |
| `materials-forms.png` | Original image generated for this repository on 2026-09-05 using the built-in Codex imagegen tool; no input images | Material, shape and four specimen study |
| `farm-composition.png` | Original image generated for this repository on 2026-09-05 using the built-in Codex imagegen tool; no input images | Six-plot composition and implied caretaker study |
| `hud-*.svg` | Original locally authored vector diagrams | Editable layout, interaction, localization and accessibility studies |
| `hud-*.png` | Local raster previews of the corresponding SVGs | Portable review previews |

The two concept PNGs are the unedited 1536×1024 selected outputs. Their lighting and texture illustrate the mood; the document's hex palette and UI contrast requirements are authoritative. Their buildings differ in door/vent placement: use the four-specimen board for the building silhouette; use the farm board for spacing and visual hierarchy. Neither board specifies production mesh density or texture resolution.

No third-party artwork was downloaded, traced, embedded, or supplied to image generation. Linked V&A and RHS pages are annotated research references, not licensed source assets. Their text and photographs remain with their respective rights holders. Original repository-authored documentation and diagrams follow the repository MIT license; AI generation is disclosed as provenance rather than a claim that third-party source imagery was licensed.

The built-in tool used the existing Codex allowance. No API key, purchased credits, paid asset pack, subscription, or runtime service was added. Do not move concept boards into the application bundle as part of this issue.

## Exact generation prompts

### materials-forms.png

```text
Use case: stylized-concept.
Asset type: original Fazendinha art-direction mood board, materials and forms, landscape 1536x1024.
Create an inviting, original warm crafted countryside miniature farm design board on a warm cream studio background. Use a carefully arranged gallery of separated, large tactile specimens, with ample empty margin and space between them: upper left, a thick rounded rectangular garden bed with dark softly furrowed soil and a terracotta rim; upper right, a simple squat cream farm storehouse with a shallow terracotta tiled gable roof, plain broad timber door and one round ventilation opening; lower left, a low rounded terrain tile with layered earth visible on its side and a soft moss-green grass top; lower right, a recognizable chunky tomato plant with a ground-level stem, broad clustered leaves and three red tomato fruits. Across the bottom add five small unlabeled ceramic color swatches, cream, dark soil, deep leafy green, terracotta, straw gold. The four specimens must read independently and not overlap.
Visual language: matte clay-like surfaces, rounded bevels and deliberately simplified silhouettes; restrained handmade irregularity and subtle surface texture only. Soft diffuse daylight from upper left, warm highlights, gentle contact shadows, no harsh black outlines, no shiny plastic. Palette anchors: cream #F7F1E5, soil #31291F, leaf #315B3A, terracotta #C47151, straw #D8AC55, with tomato red only as crop color.
This is original concept art rather than an app screenshot. No text, letters, numbers, logos, watermark, characters, faces, currency, fences, copied game assets, familiar game compositions or third-party motifs. No extra specimen types. Keep the entire objects visible with generous margins. It must feel like a hand-built small countryside garden rather than a toy store or candy world.
```

### farm-composition.png

```text
Use case: stylized-concept.
Asset type: original Fazendinha art-direction mood board, farm composition, landscape 1536x1024.
Create one coherent, inviting original 3D miniature farm on a rounded raised terrain island, seen from a comfortable elevated three-quarter camera with no horizon distraction. Exactly six rounded rectangular plots in a readable three-column by two-row arrangement occupy the central and foreground area. Each plot boundary and center is visible. Two beds are empty with broad soil furrows, two contain small green tomato plants, and two contain mature chunky tomato plants with broad leaves and easily recognized red fruit clusters. The same crop is shown at different visual sizes, not new crop content.
At the rear left, place a modest squat cream farm storehouse with a shallow terracotta tiled gable roof, broad plain timber door and one round vent, smaller in importance than the crop plots. Add one simple broadleaf tree at the rear right and a couple of small plain terracotta pots beside the storehouse; these imply an absent caretaker. Keep walking gaps between beds, avoid clutter and do not put props over beds. The island has a soft muted green grass top and a visible warm earth side. Leave generous cream negative space around the whole island.
Visual language: matte handcrafted clay-like forms, broad rounded bevels, slight handmade irregularity, simplified plant silhouettes, discreet surface texture, no glossy plastic or photoreal fine details. Soft diffuse daylight from upper left, gentle contact shadows and warm highlights. Palette anchors: cream #F7F1E5, dark soil #31291F, leaf #315B3A, terracotta #C47151, straw #D8AC55, with red tomato fruit.
No HUD, text, letters, numbers, logos, watermark, character, avatar, faces, animals, extra buildings, machinery, paths leading off the island, unlock spaces or expansion land. No imitation of another game's assets, UI, signature buildings or composition. The farm must read as a small original cared-for garden; all six complete plot silhouettes must remain visible. This is a visual direction study, not an app screenshot or production asset.
```

## Review and reproduction

The selected PNGs were inspected at native resolution for the four complete specimens, exactly six farm beds, unobscured plot centers, crop recognition, absence of text/characters, and consistency with the palette and material direction. The boards intentionally show tomato sizes only; these are visual studies of existing time-based growth, not new content or persisted stages.

Edit SVGs directly or use the included local authoring script described in the direction document. Raster previews are intentional documentation deliverables; temporary render files and discarded variants are not tracked. Regenerating concept images is optional and consumes Codex allowance; retain these selected outputs for ordinary reviews.

### Local HUD reproduction

`python3 Docs/ArtDirection/hud-author.py` regenerates the five SVGs using Python's standard library. It checks valid XML, minimum control/plot dimensions, non-overlapping controls, board bounds and unobscured field centers. The selected PNG previews were rendered locally with an already available sharp installation at 2× scale and visually inspected; no package was installed for this issue.

Where Node.js and sharp are already available, run this from the repository root to regenerate previews:

```sh
node -e 'const fs=require("fs"),sharp=require("sharp"); (async()=>{for(const n of fs.readdirSync("Docs/ArtDirection").filter(n=>/^hud-.*\.svg$/.test(n))){await sharp("Docs/ArtDirection/"+n,{density:144}).png().toFile("Docs/ArtDirection/"+n.replace(".svg",".png"));}})();'
```

Alternatively, use an existing local SVG renderer to export each diagram at twice its declared width and height. This rendering tool is not an app or repository dependency.
