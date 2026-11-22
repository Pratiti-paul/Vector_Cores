#!/usr/bin/env python3
"""
build_report.py - Build docs/report/technical_report.pdf from technical_report.md.

The Markdown file is the single source of the report. This script supports the
subset of Markdown used there: headings (#, ##, ###), paragraphs, **bold**,
*italic*, `code`, bullet and numbered lists, tables, images with an italic
caption line, fenced code blocks and horizontal rules.

Requires: reportlab   (pip install reportlab)
Optional: Pillow      (rotates very wide figures onto their own page)

Usage (from the repository root):
    python3 docs/report/build_report.py
"""

import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (Image, KeepTogether, ListFlowable, ListItem,
                                PageBreak, Paragraph, Preformatted, SimpleDocTemplate,
                                Spacer, Table, TableStyle, HRFlowable)

HERE = Path(__file__).resolve().parent
SRC = HERE / "technical_report.md"
OUT = HERE / "technical_report.pdf"
TEMP_FILES = []

# ---------------------------------------------------------------------------
# Fonts: use a Unicode TrueType font when available (arrows, ×, •), otherwise
# fall back to the built-in Helvetica and replace unsupported characters.
# ---------------------------------------------------------------------------
FONT_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Arial.ttf",
     "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
     "/System/Library/Fonts/Supplemental/Arial Italic.ttf"),
    ("/Library/Fonts/Arial.ttf", "/Library/Fonts/Arial Bold.ttf", "/Library/Fonts/Arial Italic.ttf"),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
     "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
     "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf"),
]

BODY, BOLD, MONO = "Helvetica", "Helvetica-Bold", "Courier"
UNICODE_OK = False
for regular, bold, italic in FONT_CANDIDATES:
    if Path(regular).exists() and Path(bold).exists():
        pdfmetrics.registerFont(TTFont("RptSans", regular))
        pdfmetrics.registerFont(TTFont("RptSans-Bold", bold))
        it = italic if Path(italic).exists() else regular
        pdfmetrics.registerFont(TTFont("RptSans-Italic", it))
        pdfmetrics.registerFontFamily("RptSans", normal="RptSans", bold="RptSans-Bold",
                                      italic="RptSans-Italic", boldItalic="RptSans-Bold")
        BODY, BOLD, UNICODE_OK = "RptSans", "RptSans-Bold", True
        break


def fix_chars(s):
    if UNICODE_OK:
        return s
    return (s.replace("→", "->").replace("←", "<-").replace("•", "-")
             .replace("≥", ">=").replace("≤", "<="))


# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
ss = getSampleStyleSheet()
ACCENT = colors.HexColor("#1b5e4a")
S = {
    "title": ParagraphStyle("title", parent=ss["Title"], fontName=BOLD, fontSize=20,
                            leading=24, textColor=colors.HexColor("#1f2933"), spaceAfter=4),
    "subtitle": ParagraphStyle("subtitle", parent=ss["Normal"], fontName=BODY, fontSize=12.5,
                               leading=16, alignment=TA_CENTER, textColor=ACCENT, spaceAfter=10),
    "h2": ParagraphStyle("h2", parent=ss["Heading2"], fontName=BOLD, fontSize=14, leading=18, keepWithNext=1,
                         textColor=ACCENT, spaceBefore=12, spaceAfter=6),
    "h3": ParagraphStyle("h3", parent=ss["Heading3"], fontName=BOLD, fontSize=11.5, leading=15, keepWithNext=1,
                         textColor=colors.HexColor("#1f2933"), spaceBefore=8, spaceAfter=4),
    "body": ParagraphStyle("body", parent=ss["Normal"], fontName=BODY, fontSize=10, leading=14,
                           spaceAfter=6),
    "caption": ParagraphStyle("caption", parent=ss["Normal"], fontName=BODY, fontSize=8.8,
                              leading=12, alignment=TA_CENTER,
                              textColor=colors.HexColor("#4a5560"), spaceAfter=10),
    "cell": ParagraphStyle("cell", parent=ss["Normal"], fontName=BODY, fontSize=8.4, leading=10.5),
    "cellh": ParagraphStyle("cellh", parent=ss["Normal"], fontName=BOLD, fontSize=8.4,
                            leading=10.5, textColor=colors.white),
    "code": ParagraphStyle("code", parent=ss["Code"], fontName=MONO, fontSize=7.8, leading=10,
                           backColor=colors.HexColor("#f3f5f7"), borderPadding=6,
                           spaceBefore=4, spaceAfter=8),
}


def inline(md):
    """Convert inline Markdown to ReportLab paragraph markup."""
    s = fix_chars(md)
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    s = re.sub(r"`([^`]+)`", rf"<font name='{MONO}'>\1</font>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<![*\w])\*([^*]+)\*(?![*\w])", r"<i>\1</i>", s)
    s = re.sub(r"(https?://[^\s<]+)", r"<link href='\1' color='#1d5fa8'>\1</link>", s)
    return s


# ---------------------------------------------------------------------------
# Block builders
# ---------------------------------------------------------------------------
FRAME_W = A4[0] - 36 * mm


def build_table(rows):
    header, body = rows[0], rows[1:]
    ncol = len(header)
    data = [[Paragraph(inline(c), S["cellh"]) for c in header]]
    data += [[Paragraph(inline(c), S["cell"]) for c in r + [""] * (ncol - len(r))] for r in body]
    # Column widths: every column is at least as wide as its longest single
    # word (so headers never break mid-word); remaining width is shared in
    # proportion to the amount of text in each column.
    from reportlab.pdfbase.pdfmetrics import stringWidth
    pad = 8

    def plain(i, r):
        return re.sub(r"[*`]", "", r[i] if i < len(r) else "")

    min_w = []
    for i in range(ncol):
        words = [w for r in rows for w in plain(i, r).split()] or [""]
        font = BOLD
        min_w.append(max(stringWidth(w, font, 8.4) for w in words) + pad)
    weights = [min(max(len(plain(i, r)) for r in rows), 40) + 1 for i in range(ncol)]
    spare = max(FRAME_W - sum(min_w), 0)
    widths = [m + spare * w / sum(weights) for m, w in zip(min_w, weights)]
    if sum(widths) > FRAME_W:           # too many columns: scale down uniformly
        widths = [w * FRAME_W / sum(widths) for w in widths]
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), ACCENT),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c3ccd4")),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#f4f7f6")))
    t.setStyle(TableStyle(style))
    return [t, Spacer(1, 8)]


FRAME_H = A4[1] - 34 * mm


def build_image(path, caption):
    p = (SRC.parent / path).resolve()
    iw, ih = ImageReader(str(p)).getSize()
    if iw / ih > 2.6:
        # Very wide figure (long timing diagram): rotate 90 degrees and give it
        # its own page so the text stays readable.
        try:
            from PIL import Image as PILImage
            rotated = OUT.parent / f".rot_{p.stem}.png"
            PILImage.open(p).rotate(90, expand=True).save(rotated)
            TEMP_FILES.append(rotated)
            rw, rh = ih, iw
            h = FRAME_H - 20 * mm
            w = h * rw / rh
            if w > FRAME_W:
                w, h = FRAME_W, FRAME_W * rh / rw
            parts = [PageBreak(), Image(str(rotated), width=w, height=h)]
            if caption:
                parts.append(Paragraph(inline(caption + " (rotated for readability)"), S["caption"]))
            parts.append(PageBreak())
            return parts
        except ImportError:
            pass
    w = FRAME_W
    h = w * ih / iw
    max_h = 115 * mm
    if h > max_h:
        h, w = max_h, max_h * iw / ih
    parts = [Spacer(1, 4), Image(str(p), width=w, height=h)]
    if caption:
        parts.append(Paragraph(inline(caption), S["caption"]))
    return [KeepTogether(parts)]


def build_list(items, ordered):
    flow = [ListItem(Paragraph(inline(t), S["body"]), leftIndent=12) for t in items]
    return [ListFlowable(flow, bulletType="1" if ordered else "bullet",
                         start="1" if ordered else None, leftIndent=14,
                         bulletFontName=BODY, bulletFontSize=9)]


def parse(md):
    story = []
    lines = md.splitlines()
    i, n = 0, len(lines)
    first_h1 = True
    while i < n:
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue
        if stripped.startswith("```"):
            j = i + 1
            block = []
            while j < n and not lines[j].strip().startswith("```"):
                block.append(fix_chars(lines[j]))
                j += 1
            story.append(Preformatted("\n".join(block), S["code"]))
            i = j + 1
            continue
        if stripped == "---":
            story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#c3ccd4"),
                                    spaceBefore=4, spaceAfter=8))
            i += 1
            continue
        if stripped.startswith("# "):
            story.append(Paragraph(inline(stripped[2:]), S["title"]))
            first_h1 = False
            i += 1
            continue
        if stripped.startswith("## "):
            style = S["subtitle"] if (i < 6) else S["h2"]
            story.append(Paragraph(inline(stripped[3:]), style))
            i += 1
            continue
        if stripped.startswith("### "):
            story.append(Paragraph(inline(stripped[4:]), S["h3"]))
            i += 1
            continue
        m = re.match(r"!\[[^\]]*\]\(([^)]+)\)", stripped)
        if m:
            caption = ""
            j = i + 1
            while j < n and not lines[j].strip():
                j += 1
            if j < n and re.match(r"^\*[^*].*\*$", lines[j].strip()):
                caption = lines[j].strip()[1:-1]
                i = j
            story += build_image(m.group(1), caption)
            i += 1
            continue
        if stripped.startswith("|"):
            rows = []
            while i < n and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            story += build_table(rows)
            continue
        if re.match(r"^(- |\d+\. )", stripped):
            ordered = bool(re.match(r"^\d+\. ", stripped))
            items = []
            while i < n and re.match(r"^\s*(- |\d+\. )", lines[i]):
                text = re.sub(r"^\s*(- |\d+\. )", "", lines[i])
                indent = len(lines[i]) - len(lines[i].lstrip())
                if indent >= 2 and items:      # nested item: flatten into parent text
                    items[-1] += " - " + text
                else:
                    items.append(text)
                i += 1
            story += build_list(items, ordered)
            continue
        # Paragraph: join consecutive non-blank, non-special lines
        para = [stripped]
        i += 1
        while i < n and lines[i].strip() and not re.match(r"^(#|\||!\[|```|- |\d+\. |---)", lines[i].strip()):
            para.append(lines[i].strip())
            i += 1
        story.append(Paragraph(inline(" ".join(para)), S["body"]))
    return story


def on_page(canvas, doc):
    canvas.saveState()
    canvas.setFont(BODY, 8)
    canvas.setFillColor(colors.HexColor("#6b7680"))
    canvas.drawString(18 * mm, 10 * mm, "Vector Cores - Final Technical Report")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def main():
    md = SRC.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=18 * mm,
                            title="Vector Cores - Final Technical Report",
                            author="Vector Cores team")
    try:
        doc.build(parse(md), onFirstPage=on_page, onLaterPages=on_page)
    finally:
        for f in TEMP_FILES:
            f.unlink(missing_ok=True)
    print(f"wrote {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}"
          f" (unicode font: {UNICODE_OK})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
