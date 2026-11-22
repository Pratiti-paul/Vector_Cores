#!/usr/bin/env bash
# Yosys synthesis reports for the Harvard processor, the Von Neumann
# baseline and the memory-hierarchy processor. No FPGA vendor tools are
# needed.
#
#   1. Generic flow (README Section 10.1): proc/opt/memory/opt/check/stat
#   2. AMD Xilinx 7-Series technology mapping with Yosys `synth_xilinx`
#      (resource counts only - Yosys cannot perform Xilinx timing analysis;
#       Fmax is measured with the iCE40 flow in synthesis/run_ice40.sh)
#
# Run from the repository root (instruction memory loads program.hex by a
# relative path):
#   bash synthesis/run_yosys_reports.sh
#
# Outputs:
#   synthesis/generic/<design>_generic.txt   full Yosys log of the generic flow
#   synthesis/xilinx/<design>_xc7.txt        synth_xilinx cell statistics
#
# Hierarchy is kept for the technology mapping (synth_xilinx does not flatten
# by default), so data memory is not specialised to the contents of
# program.hex.

set -euo pipefail

COMMON="rtl/program_counter.v rtl/control_unit.v rtl/register_file.v rtl/alu.v rtl/address_decoder.v"
HARVARD="$COMMON rtl/instruction_memory.v rtl/data_memory.v rtl/top_module.v"
VN="$COMMON rtl/baseline/unified_memory.v rtl/baseline/vn_top_module.v"
MH="$COMMON rtl/hierarchy/shared_memory.v rtl/hierarchy/mem_arbiter.v rtl/hierarchy/icache.v rtl/hierarchy/dcache.v rtl/hierarchy/mh_top_module.v"

mkdir -p synthesis/generic synthesis/xilinx

generic () {
    local name=$1 top=$2 files=$3
    echo "== $name: generic flow"
    yosys -p "
read_verilog $files
hierarchy -check -top $top
proc
opt
memory
opt
check
stat
" > "synthesis/generic/${name}_generic.txt"
    grep -E "Found and reported" "synthesis/generic/${name}_generic.txt" | tail -1
}

xilinx () {
    local name=$1 top=$2 files=$3
    echo "== $name: Xilinx 7-Series mapping"
    yosys -q -p "read_verilog $files; synth_xilinx -family xc7 -top $top; tee -q -o synthesis/xilinx/${name}_xc7.txt stat" \
        > /dev/null
}

generic harvard top_module    "$HARVARD"
generic vn      vn_top_module "$VN"
generic mh      mh_top_module "$MH"
xilinx  harvard top_module    "$HARVARD"
xilinx  vn      vn_top_module "$VN"
xilinx  mh      mh_top_module "$MH"

echo
echo "Xilinx 7-Series resource summary (processor core, hierarchy totals):"
for d in harvard vn mh; do
    awk '/=== design hierarchy ===/{h=1} h' "synthesis/xilinx/${d}_xc7.txt" \
      | awk -v d="$d" '
          /LUT[1-6]/      {lut+=$1}
          /FD[A-Z]*/      {ff+=$1}
          /CARRY4/        {c+=$1}
          /MUXF[78]/      {m+=$1}
          /RAM[0-9]+[A-Z]/ {r+=$1}
          END {printf "  %-8s LUTs=%d  FFs=%d  CARRY4=%d  MUXF7/8=%d  LUTRAM=%d\n", d, lut, ff, c, m, r}'
done
