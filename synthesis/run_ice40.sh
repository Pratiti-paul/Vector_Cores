#!/usr/bin/env bash
# Synthesis + place-and-route for the Harvard processor and the Von Neumann
# baseline on a Lattice iCE40 HX8K (CT256) using the open-source flow:
#   Yosys (synth_ice40)  ->  nextpnr-ice40 (place, route, static timing)
#
# Run from the repository root (instruction memory loads program.hex by a
# relative path):
#   bash synthesis/run_ice40.sh
#
# Outputs (in synthesis/ice40/):
#   <design>_resources.txt   Yosys cell statistics for the processor core
#   <design>_pnr_seed<N>.txt nextpnr report (utilisation + critical path)
#   summary.txt              Fmax per seed, median Fmax, resource summary
#
# Notes:
#   - Synthesis keeps the module hierarchy (-noflatten) so data memory is not
#     specialised to the particular program in program.hex.
#   - Fmax is measured on synthesis/fmax_wrappers.v, which registers every
#     core output so all timed paths are flip-flop to flip-flop.
#   - 5 placement seeds are run per design; the median is reported.

set -euo pipefail

OUT=synthesis/ice40
SEEDS="1 2 3 4 5"
DEVICE="--hx8k --package ct256"
mkdir -p "$OUT"

COMMON="rtl/program_counter.v rtl/control_unit.v rtl/register_file.v rtl/alu.v rtl/address_decoder.v"
HARVARD="$COMMON rtl/instruction_memory.v rtl/data_memory.v rtl/top_module.v"
VN="$COMMON rtl/baseline/unified_memory.v rtl/baseline/vn_top_module.v"

run_design () {
    local name=$1 core=$2 wrapper=$3 files=$4
    echo "== $name: synthesis"

    # Core resources (hierarchy kept)
    yosys -q -p "read_verilog $files; synth_ice40 -noflatten -top $core; tee -q -o $OUT/${name}_resources.txt stat" \
        > /dev/null

    # Netlist for timing (wrapper with registered outputs)
    yosys -q -p "read_verilog $files synthesis/fmax_wrappers.v; synth_ice40 -noflatten -top $wrapper -json $OUT/${name}.json" \
        > /dev/null

    echo "== $name: place and route"
    for s in $SEEDS; do
        nextpnr-ice40 $DEVICE --json "$OUT/${name}.json" --pcf-allow-unconstrained \
            --freq 12 --seed "$s" --log "$OUT/${name}_pnr_seed${s}.txt" --quiet > /dev/null 2>&1
    done
    rm -f "$OUT/${name}.json"
}

fmax_list () {
    local name=$1
    for s in $SEEDS; do
        grep -E "Max frequency for clock" "$OUT/${name}_pnr_seed${s}.txt" | tail -1 \
            | sed -E 's/.*: ([0-9.]+) MHz.*/\1/'
    done
}

median () { sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }

core_cells () {   # LUTs, flip-flops, carry cells of the core (hierarchy total)
    local f=$1
    awk '/=== design hierarchy ===/{h=1} h' "$f" \
        | awk '/SB_LUT4/{l+=$1} /SB_DFF/{d+=$1} /SB_CARRY/{c+=$1} END{printf "%d %d %d", l, d, c}'
}

run_design harvard top_module    harvard_fmax_top "$HARVARD"
run_design vn      vn_top_module vn_fmax_top      "$VN"

{
    echo "iCE40 HX8K (CT256) - Yosys $(yosys -V | awk '{print $2}') / nextpnr-ice40"
    echo
    printf "%-10s %8s %8s %8s %10s   %s\n" design LUT4 DFF CARRY "Fmax(MHz)" "per-seed Fmax (MHz)"
    for d in harvard vn; do
        read -r l f c <<< "$(core_cells "$OUT/${d}_resources.txt")"
        seeds=$(fmax_list "$d" | tr '\n' ' ')
        med=$(fmax_list "$d" | median)
        printf "%-10s %8s %8s %8s %10s   %s\n" "$d" "$l" "$f" "$c" "$med" "$seeds"
    done
} | tee "$OUT/summary.txt"
