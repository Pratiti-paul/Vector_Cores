#!/usr/bin/env python3
"""
render_waveforms.py - Annotated Harvard vs Von Neumann timing diagrams (SVG).

Reads the VCD produced by testbench/harvard_vs_vn_tb.v and draws one SVG
timing diagram per test program, showing the Harvard processor and the
Von Neumann baseline running the same program side by side.

Uses only the Python standard library (no matplotlib / GTKWave needed).

Usage (from the repository root, after running harvard_vs_vn_tb):
    python3 simulation/render_waveforms.py \
        simulation/waveforms/harvard_vs_vn_wave.vcd docs/waveforms

Output:
    docs/waveforms/harvard_vs_vn_p1.svg   program.hex (mixed ALU + memory)
    docs/waveforms/harvard_vs_vn_p2.svg   memory-heavy program
    docs/waveforms/harvard_vs_vn_p3.svg   compute-only loop

Signal values are sampled at the falling clock edge (mid-cycle), after all
combinational logic has settled, so each column shows what the processor
does during that clock cycle.
"""

import sys
from pathlib import Path
from xml.sax.saxutils import escape

TB = "harvard_vs_vn_tb"

# Signals read from the VCD (full hierarchical names)
SIGNALS = {
    "clk":        f"{TB}.clk",
    "reset":      f"{TB}.reset",
    "h_pc":       f"{TB}.h_pc",
    "h_instr":    f"{TB}.h_instr",
    "h_halted":   f"{TB}.h_halted",
    "h_mem_read": f"{TB}.harvard.mem_read",
    "h_mem_write": f"{TB}.harvard.mem_write",
    "h_dmem_addr": f"{TB}.harvard.dmem_addr",
    "v_pc":       f"{TB}.v_pc",
    "v_instr":    f"{TB}.v_instr",
    "v_halted":   f"{TB}.v_halted",
    "v_mem_addr": f"{TB}.v_mem_addr",
    "v_phase":    f"{TB}.v_mem_phase",
    "v_stall":    f"{TB}.v_stall",
}

PROGRAM_TITLES = {
    1: "P1 - program.hex (mixed ALU + memory)",
    2: "P2 - memory-heavy program",
    3: "P3 - compute-only loop (no LOAD/STORE)",
}


# ---------------------------------------------------------------------------
# VCD parsing
# ---------------------------------------------------------------------------

def parse_vcd(path, wanted):
    """Return {name: [(time, int_value_or_None), ...]} for wanted full names."""
    id_to_names = {}
    scope = []
    changes = {name: [] for name in wanted}
    time = 0
    in_defs = True

    def record(code, value):
        for name in id_to_names.get(code, ()):
            changes[name].append((time, value))

    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if in_defs:
                tok = line.split()
                if tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    code, ref = tok[3], tok[4]
                    full = ".".join(scope + [ref])
                    if full in wanted:
                        id_to_names.setdefault(code, []).append(full)
                elif tok[0] == "$enddefinitions":
                    in_defs = False
                continue
            if line[0] == "#":
                time = int(line[1:])
            elif line[0] in "bB":
                bits, code = line[1:].split()
                value = None if any(c in "xXzZ" for c in bits) else int(bits, 2)
                record(code, value)
            elif line[0] in "01xXzZ":
                value = int(line[0]) if line[0] in "01" else None
                record(line[1:], value)
    return changes


def value_at(trace, t):
    """Value of a signal at time t (last change at or before t)."""
    v = None
    for tt, vv in trace:
        if tt > t:
            break
        v = vv
    return v


# ---------------------------------------------------------------------------
# Instruction decoding (Vector Cores ISA)
# ---------------------------------------------------------------------------

def decode(word):
    if word is None:
        return "?"
    op = (word >> 12) & 0xF
    rd = (word >> 10) & 0x3
    rs = (word >> 8) & 0x3
    rt = (word >> 6) & 0x3
    addr = (word >> 6) & 0xF
    imm = word & 0xFF
    simm = imm - 256 if imm & 0x80 else imm
    rtype = {0x3: "ADD", 0x4: "SUB", 0x8: "AND", 0x9: "OR", 0xA: "XOR"}
    if op == 0x1:
        return f"LOAD R{rd},[{addr}]"
    if op == 0x2:
        return f"STORE R{rd},[{addr}]"
    if op in rtype:
        return f"{rtype[op]} R{rd},R{rs},R{rt}"
    if op == 0x5:
        return f"ADDI R{rd},R{rs},{simm}"
    if op == 0x6:
        return f"BEQ R{rd},R{rs},{simm:+d}"
    if op == 0x7:
        return f"JUMP {word & 0xF}"
    if op == 0xF:
        return "HALT"
    return f"0x{word:04X}"


# ---------------------------------------------------------------------------
# Program segmentation and per-cycle sampling
# ---------------------------------------------------------------------------

def segments(tr):
    """Yield (start_posedge, end_time) for each program run (reset low)."""
    clk_rises = [t for t, v in tr["clk"] if v == 1]
    falls = [t for t, v in tr["reset"] if v == 0]
    rises = [t for t, v in tr["reset"] if v == 1]
    for fall in falls:
        start = max(t for t in clk_rises if t <= fall)
        nxt = [r for r in rises if r > fall]
        end = nxt[0] if nxt else clk_rises[-1]
        yield start, end


def sample_cycles(tr, start, end, period):
    """Sample every cycle from start until one cycle after both cores halt."""
    cycles = []
    t = start
    both_halted_seen = 0
    while t + period <= end:
        mid = t + period // 2
        c = {k: value_at(tr[k], mid) for k in tr}
        c["t"] = t
        cycles.append(c)
        if c["h_halted"] == 1 and c["v_halted"] == 1:
            both_halted_seen += 1
            if both_halted_seen >= 1:
                break
        t += period
    return cycles


# ---------------------------------------------------------------------------
# SVG rendering
# ---------------------------------------------------------------------------

COL_W = 106         # pixels per clock cycle
LABEL_W = 250       # signal-name column
ROW_H = 34
TOP = 96
FONT = "font-family='Menlo, Consolas, monospace'"

C_LINE = "#1f2933"
C_GRID = "#d5dbe1"
C_HARV = "#1b7f5a"     # Harvard accent (green)
C_HARV_BG = "#dff3ea"
C_VN = "#b4541a"       # Von Neumann accent (orange)
C_VN_BG = "#fbe6d6"
C_MUTED = "#5b6670"


def text(x, y, s, size=13, color=C_LINE, anchor="start", weight="normal"):
    return (f"<text x='{x}' y='{y}' {FONT} font-size='{size}' fill='{color}' "
            f"text-anchor='{anchor}' font-weight='{weight}'>{escape(s)}</text>")


def bus_row(y, labels, color=C_LINE, fill=None):
    """Draw a bus as hexagon segments; consecutive equal labels are merged."""
    out = []
    i = 0
    n = len(labels)
    while i < n:
        j = i
        while j + 1 < n and labels[j + 1] == labels[i]:
            j += 1
        x0 = LABEL_W + i * COL_W
        x1 = LABEL_W + (j + 1) * COL_W
        top, bot, mid = y + 5, y + ROW_H - 5, y + ROW_H / 2
        d = 4
        pts = f"{x0},{mid} {x0+d},{top} {x1-d},{top} {x1},{mid} {x1-d},{bot} {x0+d},{bot}"
        f = fill(labels[i]) if fill else "#ffffff"
        out.append(f"<polygon points='{pts}' fill='{f}' stroke='{color}' stroke-width='1.2'/>")
        out.append(text((x0 + x1) / 2, mid + 4.5, labels[i], 11.5, color, "middle"))
        i = j + 1
    return out


def bit_row(y, values, color=C_LINE):
    """Draw a 1-bit signal as a step waveform (one value per cycle)."""
    hi, lo = y + 7, y + ROW_H - 7
    pts = []
    prev = None
    for i, v in enumerate(values):
        x = LABEL_W + i * COL_W
        yy = hi if v == 1 else lo
        if prev is not None and prev != yy:
            pts.append(f"{x},{prev}")
        pts.append(f"{x},{yy}")
        pts.append(f"{x + COL_W},{yy}")
        prev = yy
    return [f"<polyline points='{' '.join(pts)}' fill='none' stroke='{color}' stroke-width='2'/>"]


def clock_row(y, n):
    hi, lo = y + 7, y + ROW_H - 7
    pts = []
    for i in range(n):
        x = LABEL_W + i * COL_W
        pts += [f"{x},{lo}", f"{x},{hi}", f"{x + COL_W/2},{hi}",
                f"{x + COL_W/2},{lo}", f"{x + COL_W},{lo}"]
    return [f"<polyline points='{' '.join(pts)}' fill='none' stroke='{C_MUTED}' stroke-width='1.5'/>"]


def render(cycles, title, out_path):
    n = len(cycles)
    h_access = [c["h_mem_read"] == 1 or c["h_mem_write"] == 1 for c in cycles]
    v_data = [c["v_phase"] == 1 for c in cycles]
    h_done = next((i for i, c in enumerate(cycles) if c["h_halted"] == 1), n)
    v_done = next((i for i, c in enumerate(cycles) if c["v_halted"] == 1), n)

    def h_dmem(c):
        if c["h_mem_write"] == 1:
            return f"WR [{c['h_dmem_addr']}]"
        if c["h_mem_read"] == 1:
            return f"RD [{c['h_dmem_addr']}]"
        return "idle"

    def v_port(c):
        a = c["v_mem_addr"]
        if a is None:
            return "?"
        return f"DATA [{a & 0xF}]" if a & 0x10 else f"FETCH {a & 0xF}"

    rows = [
        ("clk", "clock", None, None),
        ("cycle", "cycle", None, None),
        ("H", "HARVARD (top_module)", C_HARV, None),
        ("h_pc", "PC / IMEM address", C_HARV, [str(c["h_pc"]) for c in cycles]),
        ("h_instr", "IMEM -> instruction", C_HARV, [decode(c["h_instr"]) for c in cycles]),
        ("h_dmem", "DMEM port", C_HARV, [h_dmem(c) for c in cycles]),
        ("h_halted", "halted", C_HARV, [c["h_halted"] for c in cycles]),
        ("V", "VON NEUMANN (vn_top_module)", C_VN, None),
        ("v_pc", "PC", C_VN, [str(c["v_pc"]) for c in cycles]),
        ("v_port", "shared memory port", C_VN, [v_port(c) for c in cycles]),
        ("v_instr", "instruction (fetched / IR)", C_VN, [decode(c["v_instr"]) for c in cycles]),
        ("v_stall", "stall", C_VN, [c["v_stall"] for c in cycles]),
        ("v_halted", "halted", C_VN, [c["v_halted"] for c in cycles]),
    ]

    width = LABEL_W + n * COL_W + 24
    body_h = len(rows) * ROW_H
    height = TOP + body_h + 92
    svg = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' "
           f"viewBox='0 0 {width} {height}'>",
           f"<rect width='100%' height='100%' fill='#ffffff'/>",
           text(16, 30, f"Harvard vs Von Neumann - {title}", 18, C_LINE, weight="bold"),
           text(16, 54, f"Same program on both cores.  Harvard finishes in {h_done} cycles, "
                        f"Von Neumann in {v_done} cycles.  Values sampled mid-cycle "
                        f"(falling clock edge).", 12.5, C_MUTED),
           ]

    # Row y positions
    ys = {key: TOP + i * ROW_H for i, (key, *_rest) in enumerate(rows)}
    h_top, h_bot = ys["h_pc"], ys["h_halted"] + ROW_H
    v_top, v_bot = ys["v_pc"], ys["v_halted"] + ROW_H

    # Highlight columns
    for i in range(n):
        x = LABEL_W + i * COL_W
        if h_access[i]:
            svg.append(f"<rect x='{x}' y='{h_top}' width='{COL_W}' height='{h_bot - h_top}' fill='{C_HARV_BG}'/>")
        if v_data[i]:
            svg.append(f"<rect x='{x}' y='{v_top}' width='{COL_W}' height='{v_bot - v_top}' fill='{C_VN_BG}'/>")

    # Cycle grid
    for i in range(n + 1):
        x = LABEL_W + i * COL_W
        svg.append(f"<line x1='{x}' y1='{TOP}' x2='{x}' y2='{TOP + body_h}' stroke='{C_GRID}' stroke-width='1'/>")

    # Halt markers
    for done, color, top, bot in ((h_done, C_HARV, h_top, h_bot), (v_done, C_VN, v_top, v_bot)):
        if done < n:
            x = LABEL_W + done * COL_W
            svg.append(f"<line x1='{x}' y1='{top}' x2='{x}' y2='{bot}' stroke='{color}' "
                       f"stroke-width='2.5' stroke-dasharray='6 4'/>")

    for key, label, color, data in rows:
        y = ys[key]
        if key in ("H", "V"):
            svg.append(f"<line x1='8' y1='{y + ROW_H - 4}' x2='{width - 12}' y2='{y + ROW_H - 4}' "
                       f"stroke='{color}' stroke-width='1.5'/>")
            svg.append(text(16, y + ROW_H - 10, label, 13.5, color, weight="bold"))
            continue
        svg.append(text(24, y + ROW_H / 2 + 4.5, label, 12.5, color or C_MUTED))
        if key == "clk":
            svg += clock_row(y, n)
        elif key == "cycle":
            for i in range(n):
                svg.append(text(LABEL_W + i * COL_W + COL_W / 2, y + ROW_H / 2 + 4.5,
                                str(i), 12, C_MUTED, "middle"))
        elif key in ("h_halted", "v_halted", "v_stall"):
            svg += bit_row(y, data, color)
        elif key == "h_dmem":
            svg += bus_row(y, data, color,
                           fill=lambda s: "#c4ead8" if s != "idle" else "#ffffff")
        elif key == "v_port":
            svg += bus_row(y, data, color,
                           fill=lambda s: "#f6c9a8" if s.startswith("DATA") else "#ffffff")
        else:
            svg += bus_row(y, data, color)

    # Legend / annotations
    ly = TOP + body_h + 26
    svg.append(f"<rect x='16' y='{ly - 13}' width='18' height='16' fill='{C_HARV_BG}' stroke='{C_HARV}'/>")
    svg.append(text(42, ly, "Harvard: instruction fetch and data-memory access in the SAME cycle "
                            "(separate IMEM and DMEM ports)", 12.5, C_HARV))
    svg.append(f"<rect x='16' y='{ly + 13}' width='18' height='16' fill='{C_VN_BG}' stroke='{C_VN}'/>")
    svg.append(text(42, ly + 26, "Von Neumann: the single shared port is busy with the data access, "
                                 "so the next fetch waits one cycle (stall)", 12.5, C_VN))
    svg.append(f"<line x1='16' y1='{ly + 49}' x2='34' y2='{ly + 49}' stroke='{C_LINE}' "
               f"stroke-width='2.5' stroke-dasharray='6 4'/>")
    svg.append(text(42, ly + 53, "first cycle in which the core is halted", 12.5, C_MUTED))

    svg.append("</svg>")
    out_path.write_text("\n".join(svg) + "\n")
    return h_done, v_done


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 1
    vcd, out_dir = Path(argv[1]), Path(argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    raw = parse_vcd(vcd, set(SIGNALS.values()))
    tr = {k: raw[v] for k, v in SIGNALS.items()}
    missing = [k for k, v in tr.items() if not v]
    if missing:
        print(f"error: signals not found in VCD: {missing}")
        return 1

    clk_rises = [t for t, v in tr["clk"] if v == 1]
    period = clk_rises[1] - clk_rises[0]

    for idx, (start, end) in enumerate(segments(tr), start=1):
        cycles = sample_cycles(tr, start, end, period)
        title = PROGRAM_TITLES.get(idx, f"program {idx}")
        out = out_dir / f"harvard_vs_vn_p{idx}.svg"
        h, v = render(cycles, title, out)
        print(f"{out}: Harvard {h} cycles, Von Neumann {v} cycles")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
