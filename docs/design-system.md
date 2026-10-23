# Loopline visual system

The visual reference is the [Color & Typography slide in the supplied deck](https://docs.google.com/presentation/d/1bTHqCd-ZdfXplMtFIISS_kdRjTVPBkOh85B0rB5ohEM/edit?slide=id.g2eebc927e9d_0_0).
The native source of truth is `LooplineApp/UI/LooplineTheme.swift`.
The browser prototype uses the same palette and bundled fonts.
See the [native app screenshots](screenshots/app-preview.png) captured from the simulator UI tests.

## Typography

| Role | Font |
| --- | --- |
| Headings and primary actions | Google Sans Bold |
| Body | Google Sans Regular |
| Emphasis | Google Sans Medium |
| Subheads, labels, timing, and technical readouts | Roboto Mono Light |

Fonts are bundled in `LooplineApp/Resources/Fonts` and registered with `UIAppFonts`.
The native font helper scales with Dynamic Type.
The browser loads the same local files with `@font-face`.
There are no font network requests at runtime.

Font files come from the official [Google Fonts collection](https://github.com/google/fonts/tree/main/ofl/googlesans) and [Roboto Mono collection](https://github.com/google/fonts/tree/main/ofl/robotomono).
Their SIL Open Font Licenses are included beside the fonts.
The static Google Sans instances preserve the original family and PostScript names.

## Palette

| Family | Base | Halftone | Pastel |
| --- | --- | --- | --- |
| Blue | `#4285F4` | `#57CAFF` | `#C3ECF6` |
| Green | `#34A853` | `#5CDB6D` | `#CCF6C5` |
| Red | `#EA4335` | `#FF7DAF` | `#F8D8D8` |
| Yellow | `#FBBC04` | `#FFD427` | `#FFE7A5` |

Off-white `#F0F0F0` is the application canvas.
Black `#1E1E1E` is the main text color and camera backdrop.
White surfaces and a derived neutral secondary text color support readable controls.
Pastels group related controls and destination actions.
Dark text on pastel and halftone fills keeps primary actions readable.
Color is accompanied by text, icons, and selected states.

## Presentation

Keep the interface portrait-first, with generous space, bold headings, and clear transport controls.
Camera and recorded media remain visually distinct from application surfaces.
Waveforms and level meters must represent actual audio.
An unavailable camera or missing source is shown explicitly.
A completed render, Files save, Photos save, and share action are separate states.
