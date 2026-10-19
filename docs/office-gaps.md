# Office apps: Omarchy's own tools vs AbiWord + Gnumeric vs LibreOffice (2026-10-19)

Status: research + measurements only. **The default app set is unchanged** (AbiWord + Gnumeric default,
LibreOffice optional, per PROPOSAL.md §0). Swapping is a product decision for the user.

## What Omarchy's own tools are
All are native **Qt 6 / Qt Quick (QML) + C++** apps from github.com/omacom, packaged in the Omarchy
package repository (OPR). None of them are Electron or web apps. Package data comes from `pacman -Si` in the 4.0.5 VM.

| Tool | What it is | Default in Omarchy 4? | Deps (pacman) | Installed size |
|---|---|---|---|---|
| **Omawrite** 0.7.0 | Markdown writer: autosave, find/replace, print dialog, copy as HTML | yes (replaced Typora, `Super+Shift+W`) | qt6-base, qt6-declarative, xdg-desktop-portal | 0.9 MiB |
| **Omacalc** 0.3.1 | Pocket **calculator** (keypad, `+−×÷^%`). It isn't a spreadsheet | yes (replaced GNOME Calculator, `Super+Ctrl+Q`) | qt6-base, qt6-declarative, xdg-desktop-portal | 0.3 MiB |
| **Hype** 0.6.0 | Markdown slide decks with a visual editor; exports PDF and PowerPoint | no (`omarchy pkg add hype`) | qt6-base/declarative/multimedia ≥6.9, qt6-svg, qt6-imageformats, ffmpeg, source-highlight, libwebp | 0.7 MiB + Qt Multimedia/ffmpeg |
| **Signed** 0.3.1 | Sign and fill in PDFs (poppler + qpdf), with a CLI | no | poppler-qt6, qpdf, qt6-wayland, noto-fonts | 0.5 MiB |

There is no "omaslides" or "omanotes". Hype is the slides tool, and Omarchy has no Oma word processor or
spreadsheet. Sources: the omacom/omawrite, omacalc, hype and signed READMEs, and the Omarchy 4.0.0 release notes.
Omacut (a video trimmer) and Monologue (a webcam recorder) aren't office tools.

## RAM (box measurement: 1 GB TCG VM, Omarchy 4.0.5 + potato-mode, sway on llvmpipe)
PSS of the app's processes 25 s after launch, with a small test file open (`appmem.sh`, single sample):

| App | PSS |
|---|---|
| Omawrite (Qt Quick, default GL backend → llvmpipe) | 175 MiB |
| Omawrite with `QT_QUICK_BACKEND=software` | **55 MiB** |
| Omacalc (default) / software backend | 150 / **42 MiB** |
| AbiWord 3.0.8 (test.docx) | 58 MiB |
| Gnumeric 1.12.61 (test.xlsx) | 36 MiB |
| LibreOffice Writer, empty | 213 MiB RSS-sum, 2 procs (earlier **box** measurement on LO 25.2, see shortlist.md; not re-measured in the VM, where potato-mode had removed it) |
| Hype, Signed | not measured (not installed) |

Finding: with no GPU, Qt Quick apps load llvmpipe into the process. Forcing Qt Quick's software renderer cut
both Oma apps by about 110–120 MiB, which makes it a candidate setting for the sway path (see tuning.md).
Disk: LibreOffice is 423 MiB installed (`libreoffice-fresh` 26.8.1), against 22 MiB for AbiWord and 48 MiB for Gnumeric.

## Format tests (VM, generated test files: a docx with heading/bold/table/image/bullets/page break, an xlsx with formulas/SUM/VLOOKUP/bar chart, a pptx)
- `abiword --to=docx|odt|pdf|rtf test.docx`: all succeeded. Text, table and image were kept (the image is present in the docx/odt/pdf), and the PDF has 2 pages (the page break was kept).
- `ssconvert test.xlsx → ods|pdf|csv`, and ods → xlsx: all succeeded. Formulas were evaluated (SUM 550, VLOOKUP 30) and stay
  formulas in the re-exported xlsx. **The bar chart was not imported** from the openpyxl-made xlsx (0 graph objects
  in the .gnumeric output). Gnumeric has native charts, but chart import from xlsx is a fidelity risk.
- The Oma tools open only Markdown (Omawrite, Hype) or PDF (Signed); none import docx/xlsx/pptx/odt.

## Gap matrix
✅ yes · ⚠️ partial/caveat · ❌ no. "Verified" means tested in the VM above; the rest is from upstream docs.

| Need | Oma tools | AbiWord + Gnumeric | LibreOffice |
|---|---|---|---|
| Write prose | ✅ Omawrite (Markdown) | ✅ AbiWord | ✅ Writer |
| Open/edit .docx | ❌ | ✅ simple docs (verified); ⚠️ complex layout | ✅ best on Linux |
| Export .docx / .odt | ❌ | ✅ (verified) | ✅ |
| PDF export | ⚠️ Omawrite only via print dialog; Hype ✅ | ✅ (verified both) | ✅ |
| Track changes / comments | ❌ | ⚠️ AbiWord revision marks; weak docx round-trip | ✅ |
| Spreadsheet with formulas | ❌ (Omacalc is a calculator) | ✅ Gnumeric (verified SUM/VLOOKUP) | ✅ Calc |
| .xlsx import/export | ❌ | ✅ data+formulas (verified); ⚠️ charts not imported | ✅ |
| Charts | ❌ | ✅ native; ⚠️ from xlsx | ✅ |
| Presentations | ✅ Hype (Markdown → PDF/PPTX; PPTX slides are images, not editable) | ❌ | ✅ Impress |
| Open/edit someone's .pptx | ❌ | ❌ | ✅ Impress only |
| Printing | ✅ Omawrite print dialog | ✅ | ✅ |
| Sign/fill PDF | ✅ Signed | ❌ (zathura only views) | ⚠️ Draw |
| Databases (Base), macros, mail merge | ❌ | ❌ | ✅ |
| Agent/CLI friendly | ✅ hype/signed CLIs, Markdown files | ✅ `abiword --to`, `ssconvert` (verified) | ✅ `soffice --headless --convert-to` |

**Needs only LibreOffice covers:** editing received .pptx (Impress), high-fidelity complex .docx/.xlsx (styles,
tracked changes, comments, charts), Base, macros, mail merge.

## Recommendation (for the user to decide)
1. **Don't swap AbiWord/Gnumeric for the Oma tools.** These tools fill different needs. Omawrite is a
   Markdown editor and Omacalc is a calculator, so neither reads or writes Office formats. Omawrite and Omacalc already come with
   Omarchy, and potato-mode keeps them. Use them alongside AbiWord/Gnumeric, not instead of them.
2. **Keep LibreOffice optional.** It is the only option for .pptx editing and Office-fidelity work, and it costs about 213 MiB RSS for an empty
   Writer (box measurement) plus 423 MiB of disk. Too much as a default on a 1 GB machine.
3. **Optional add-ons worth offering in the potato menu:** Hype (presentations without LibreOffice) and
   Signed (PDF signing). Both are small apps, but Hype pulls in Qt Multimedia and ffmpeg.
4. On the sway/no-GPU path, consider `QT_QUICK_BACKEND=software` for Qt Quick apps. It measured about 120 MiB less for
   Omawrite (see tuning.md).
