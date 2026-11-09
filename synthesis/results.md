## Instruction Memory – Simulation Results

**Tool:** Icarus Verilog, waveform viewed in Surfer.
**Command:**
```
iverilog -o imem testbench/instruction_memory_tb.v rtl/instruction_memory.v
vvp imem
```

**Result:** all 16 locations passed and every instruction decoded correctly.
```
PASS addr=0 instr=5405
PASS addr=1 instr=5803
PASS addr=2 instr=3580
PASS addr=3 instr=2480
PASS addr=4 instr=4580
PASS addr=5 instr=1c80
PASS addr=6 instr=5f01
PASS addr=7..15 instr=f000 (HALT)
--- Instruction format check ---
addr=0 ADDI  rd=R1, rs=R0, imm=5
addr=1 ADDI  rd=R2, rs=R0, imm=3
addr=2 ADD   rd=R1, rs=R1, rt=R2
addr=3 STORE rs=R1, [2]
addr=4 SUB   rd=R1, rs=R1, rt=R2
addr=5 LOAD  rd=R3, [2]
addr=6 ADDI  rd=R3, rs=R3, imm=1
addr=7 HALT
ALL INSTRUCTION MEMORY TESTS PASSED
```

### Waveform
![Instruction memory waveform](../docs/report/instruction_memory_waveform.png)

*Figure: `instr` changes immediately with `addr` (asynchronous read). Addresses 0-6 return the program, addresses 7-15 return HALT (F000), and the final addr 0 -> F -> 5 sequence confirms non-sequential access.*

### Observations
- Instruction memory is read-only and needs no clock; latency is purely combinational.
- Because it is separate from data memory, instruction fetch and data access can happen in the same cycle (Harvard advantage). A shared-memory design would need to serialise them.
- Synthesis results (resource utilisation and maximum frequency) are reported separately in the synthesis section.