# Fonts

Modified game-text subsets, baked to fixed weights and renamed. Distributed under SIL Open Font License 1.1, with the upstream copyright and license notices:

- Noto Sans SC: https://github.com/google/fonts/tree/main/ofl/notosanssc
- Noto Serif SC: https://github.com/google/fonts/tree/main/ofl/notoserifsc

Upstream sources downloaded 2026-10-02 from Google's official fonts repository and preserved in `.artwork/font-sources/`. Source SHA-256:

- Noto Sans SC: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- Noto Serif SC: `050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9`

Keep both OFL text files with exported distributions. No font installation or network access is needed at game runtime.

`scripts/art_fonts.gd` caches Midnight Fair Sans (400), Midnight Fair Display (650) and Midnight Fair Numbers (600). Fonts are shared by HUD and in-world labels; shots do not create font instances.

Rebuild `.artwork/build_fonts.py` after adding Chinese game text, using fontTools 4.66.1. The presentation tests check Chinese coverage so new text cannot silently lose glyphs.
