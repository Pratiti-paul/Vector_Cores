# Data Memory & Address Decoder — Phase II Verification Report

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Contributor:** Member 3 (Ganga)  
**Branch:** `phase2/data-memory-verification`  
**Tool:** Icarus Verilog (`iverilog` + `vvp`)

---

## 1. Module Overview

### Data Memory (`rtl/data_memory.v`)

The data memory is the runtime read/write storage for the Harvard Architecture processor. It is entirely separate from instruction memory, enabling simultaneous instruction fetch and data access in the same clock cycle.

| Parameter | Value |
|---|---|
| Capacity | 16 locations × 8 bits |
| Address width | 4 bits (from instruction `[9:6]` for LOAD/STORE) |
| Write | Synchronous — on `posedge clk` when `mem_write` is asserted |
| Read | Asynchronous (combinational) — gated by `mem_read`; outputs `8'h00` when disabled |
| Reset | Active-high synchronous — clears all 16 locations to `8'h00` |
| Address decoding | Internal `address_decoder` instance generates one-hot `write_select` lines |

**Write path:** On the rising clock edge, the internal address decoder produces a one-hot `write_select` signal. A write loop updates only the memory location whose select line is active.

**Read path:** The read is combinational (`assign`), gated by `mem_read`. When `mem_read = 0`, `read_data` outputs `8'h00` to prevent stale data leaking onto the datapath bus.

### Address Decoder (`rtl/address_decoder.v`)

A pure combinational 4-to-16 one-hot decoder with an enable control signal.

| Parameter | Value |
|---|---|
| Input address width | 4 bits |
| Output select lines | 16 bits (one-hot) |
| Enable control | Active-high; output is all zeros when disabled |
| Logic type | Pure combinational (no clock) |

When `enable = 1`: `select_lines = 16'b1 << addr` (exactly one bit set).  
When `enable = 0`: `select_lines = 16'b0` (all zero, no word line active).

---

## 2. Interface Specification

### Data Memory Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | System clock |
| `reset` | Input | 1 | Active-high synchronous reset |
| `mem_read` | Input | 1 | Read enable (from control unit, LOAD opcode `0001`) |
| `mem_write` | Input | 1 | Write enable (from control unit, STORE opcode `0010`) |
| `addr` | Input | 4 | Memory address (from instruction `[9:6]`) |
| `write_data` | Input | 8 | Data to write (register value for STORE) |
| `read_data` | Output | 8 | Data read (to register writeback for LOAD) |

### Address Decoder Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `enable` | Input | 1 | Active when `mem_read` or `mem_write` is asserted |
| `addr` | Input | 4 | 4-bit memory address |
| `select_lines` | Output | 16 | 16-bit one-hot decoded word-select |

### Timing Diagram (Textual)

**Synchronous Write:**
```
       ┌───┐   ┌───┐   ┌───┐
 clk   │   │   │   │   │   │
     ──┘   └───┘   └───┘   └──
       
 mem_write ━━━━━━━━━┓
                     ┗━━━━━━━━
 addr      ══╤══════════╤═════
 write_data  ═╤══════════╤═════
              ↑          
        data latched here (posedge clk)
```

**Asynchronous Read:**
```
 mem_read ━━━━━━━━━━━━━━━━━━━━
 addr     ═══╤═══════╤════════
 read_data   ╰→ immediate ╰→ immediate
              (no clock needed)
```

---

## 3. Test Cases — Address Decoder (`testbench/address_decoder_tb.v`)

### Test A1: One-hot verification for all 16 addresses (enable=1)
Loops through `addr = 0` to `15`, verifies `select_lines == (1 << addr)` and confirms exactly one bit is set (popcount = 1).

### Test A2: Enable=0 produces all-zero for all addresses
Loops through all 16 addresses with `enable = 0`, verifies `select_lines == 16'b0`.

### Test A3: Enable toggle mid-operation
Tests enable toggling (1→0→1) at addresses 7, 0, and 15 (boundaries), verifying correct transitions.

### Test A4: Rapid address sweep (combinational tracking)
Forward sweep (0→15), reverse sweep (15→0), and non-sequential jumps (0→15→8→3) — all at 1ns intervals confirming purely combinational output tracking.

### Actual Simulation Output

```
=================================================================
   ADDRESS DECODER (4-to-16 ONE-HOT) VERIFICATION TESTBENCH
=================================================================
--- Test A1: One-hot output for all 16 addresses (enable=1) ---
PASS A1 addr= 0 select_lines=0000000000000001 (bit 0 set)
PASS A1 addr= 1 select_lines=0000000000000010 (bit 1 set)
PASS A1 addr= 2 select_lines=0000000000000100 (bit 2 set)
PASS A1 addr= 3 select_lines=0000000000001000 (bit 3 set)
PASS A1 addr= 4 select_lines=0000000000010000 (bit 4 set)
PASS A1 addr= 5 select_lines=0000000000100000 (bit 5 set)
PASS A1 addr= 6 select_lines=0000000001000000 (bit 6 set)
PASS A1 addr= 7 select_lines=0000000010000000 (bit 7 set)
PASS A1 addr= 8 select_lines=0000000100000000 (bit 8 set)
PASS A1 addr= 9 select_lines=0000001000000000 (bit 9 set)
PASS A1 addr=10 select_lines=0000010000000000 (bit 10 set)
PASS A1 addr=11 select_lines=0000100000000000 (bit 11 set)
PASS A1 addr=12 select_lines=0001000000000000 (bit 12 set)
PASS A1 addr=13 select_lines=0010000000000000 (bit 13 set)
PASS A1 addr=14 select_lines=0100000000000000 (bit 14 set)
PASS A1 addr=15 select_lines=1000000000000000 (bit 15 set)
--- Test A2: Enable=0 produces all-zero for all addresses ---
PASS A2 addr= 0 select_lines=0000000000000000 (all zero)
PASS A2 addr= 1 select_lines=0000000000000000 (all zero)
PASS A2 addr= 2 select_lines=0000000000000000 (all zero)
PASS A2 addr= 3 select_lines=0000000000000000 (all zero)
PASS A2 addr= 4 select_lines=0000000000000000 (all zero)
PASS A2 addr= 5 select_lines=0000000000000000 (all zero)
PASS A2 addr= 6 select_lines=0000000000000000 (all zero)
PASS A2 addr= 7 select_lines=0000000000000000 (all zero)
PASS A2 addr= 8 select_lines=0000000000000000 (all zero)
PASS A2 addr= 9 select_lines=0000000000000000 (all zero)
PASS A2 addr=10 select_lines=0000000000000000 (all zero)
PASS A2 addr=11 select_lines=0000000000000000 (all zero)
PASS A2 addr=12 select_lines=0000000000000000 (all zero)
PASS A2 addr=13 select_lines=0000000000000000 (all zero)
PASS A2 addr=14 select_lines=0000000000000000 (all zero)
PASS A2 addr=15 select_lines=0000000000000000 (all zero)
--- Test A3: Enable toggle mid-operation ---
PASS A3.1 enable=1 addr=7 select_lines=0000000010000000
PASS A3.2 enable=0 addr=7 select_lines=0000000000000000 (gated off)
PASS A3.3 enable=1 addr=7 select_lines=0000000010000000 (re-enabled)
PASS A3.4 enable=1 addr=0 select_lines=0000000000000001 (bit 0)
PASS A3.5 enable=0 addr=0 select_lines=0000000000000000 (gated off)
PASS A3.6 enable=1 addr=15 select_lines=1000000000000000 (bit 15)
PASS A3.7 enable=0 addr=15 select_lines=0000000000000000 (gated off)
--- Test A4: Rapid address sweep (combinational tracking) ---
PASS A4 rapid sweep: forward, reverse, and non-sequential all correct
=================================================================
ALL ADDRESS DECODER TESTS PASSED (0 errors)
=================================================================
```

**Compilation command:**
```bash
iverilog -o addr_dec_test rtl/address_decoder.v testbench/address_decoder_tb.v
vvp addr_dec_test
```

---

## 4. Test Cases — Data Memory (`testbench/data_memory_tb.v`)

### Test D1: Reset verification (all 16 locations)
Assert synchronous reset for one clock cycle, then read all 16 locations with `mem_read = 1`. All must return `8'h00`.

### Test D2: Individual write/read to all 16 addresses
Write a unique value `(addr * 17 + 3) & 0xFF` to each address individually, read each back immediately after writing. Verifies all 16 addresses are independently accessible.

### Test D3: Independent read (never-written address)
After a fresh reset, read from addresses 7, 0, and 15 without writing first. Must return `8'h00` (not X or Z), confirming clean initialization.

### Test D4: Independent write (deferred read)
Write `0xAB` to addr 3 and `0xCD` to addr 10 without reading between writes. Only then read both back. Proves writes are independent of read operations.

### Test D5: Disabled write verification (multiple addresses)
Write known values to addr 0, 5, and 15. Then attempt writes with `mem_write = 0` using different data to the same addresses. Verify original values are preserved at all three locations.

### Test D6: Read control gating (multiple addresses)
With stored data at addr 0, 5, and 15: read with `mem_read = 0` (output must be `8'h00`), then read with `mem_read = 1` (output must match stored data). Tests gating at three different addresses.

### Test D7: Consecutive back-to-back operations
- **Write-Write:** Consecutive writes to addr 0 and addr 1 with no idle cycles.
- **Write-Read:** Write to addr 2, immediately read addr 2 on the next cycle.
- **Read-Read:** Consecutive reads from addr 0, 1, 2 with no idle cycles.

### Test D8: Simultaneous mem_read and mem_write
Assert both `mem_read = 1` and `mem_write = 1` simultaneously on the same address. Verifies that the combinational read sees the **old** value before the clock edge, and the **new** value is available after the clock edge.

### Test D9: Mid-operation reset
Populate addresses 0, 7, and 15 with data, verify population, then assert reset. Confirm all 16 locations are cleared to `8'h00`.

### Test D10: Write timing verification
Set up a write operation and sample `read_data` **before** the rising clock edge (must still see old value `8'h00`), then sample **after** the edge (must see new value `8'h77`). Confirms synchronous write timing.

### Test D11: Read timing (combinational)
Write distinct values to addresses 4, 9, and 6. Change `addr` between them without any clock edge — verify `read_data` updates immediately each time, confirming purely combinational read path.

### Test D12: LOAD/STORE processor compatibility
- Simulate the exact `STORE R1, [2]` → `LOAD R3, [2]` sequence from `program.hex` (value = 8).
- Test boundary STORE/LOAD at addr 0 and addr 15.
- Cross-verify that addr 2 still holds its value after boundary operations.

### Actual Simulation Output

```
===================================================================
  DATA MEMORY PHASE II — COMPREHENSIVE VERIFICATION TESTBENCH
===================================================================
--- Test D1: Reset verification (all 16 locations) ---
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
PASS D1 reset actual=00
--- Test D2: Individual write/read all 16 addresses ---
PASS D2 addr actual=03
PASS D2 addr actual=14
PASS D2 addr actual=25
PASS D2 addr actual=36
PASS D2 addr actual=47
PASS D2 addr actual=58
PASS D2 addr actual=69
PASS D2 addr actual=7a
PASS D2 addr actual=8b
PASS D2 addr actual=9c
PASS D2 addr actual=ad
PASS D2 addr actual=be
PASS D2 addr actual=cf
PASS D2 addr actual=e0
PASS D2 addr actual=f1
PASS D2 addr actual=02
--- Test D3: Independent read (never-written address) ---
PASS D3 never-written addr=7 actual=00
PASS D3 never-written addr=0 actual=00
PASS D3 never-written addr=15 actual=00
--- Test D4: Independent write (deferred read) ---
PASS D4 deferred read addr=3 actual=ab
PASS D4 deferred read addr=10 actual=cd
--- Test D5: Disabled write (multiple addresses) ---
PASS D5 write-inhibit addr=0 actual=11
PASS D5 write-inhibit addr=5 actual=55
PASS D5 write-inhibit addr=15 actual=ff
--- Test D6: Read control gating ---
PASS D6 mem_read=0 addr=0 actual=00
PASS D6 mem_read=0 addr=5 actual=00
PASS D6 mem_read=0 addr=15 actual=00
PASS D6 mem_read=1 addr=0 actual=11
PASS D6 mem_read=1 addr=5 actual=55
PASS D6 mem_read=1 addr=15 actual=ff
--- Test D7: Consecutive back-to-back operations ---
PASS D7 write-write addr=0 actual=a0
PASS D7 write-write addr=1 actual=b1
PASS D7 write-then-read addr=2 actual=c2
PASS D7 read-read addr=0 actual=a0
PASS D7 read-read addr=1 actual=b1
PASS D7 read-read addr=2 actual=c2
--- Test D8: Simultaneous mem_read and mem_write ---
PASS D8 simultaneous pre-clk (old value) actual=10
PASS D8 simultaneous post-clk (new value) actual=20
--- Test D9: Mid-operation reset ---
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
PASS D9 mid-reset actual=00
--- Test D10: Write timing verification ---
PASS D10 before posedge (not yet written) actual=00
PASS D10 after posedge (written) actual=77
--- Test D11: Read timing (combinational) ---
PASS D11 combinational read addr=4 actual=44
PASS D11 combinational read addr=9 (no clk) actual=99
PASS D11 combinational read addr=6 (no clk) actual=77
--- Test D12: LOAD/STORE processor compatibility ---
PASS D12 STORE/LOAD addr=2 (program.hex) actual=08
PASS D12 boundary STORE/LOAD addr=0 actual=a5
PASS D12 boundary STORE/LOAD addr=15 actual=5a
PASS D12 cross-verify addr=2 unchanged actual=08
===================================================================
Total Checks Passed: 79
Total Checks Failed: 0
===================================================================
ALL DATA MEMORY PHASE II TESTS PASSED
===================================================================
```

**Compilation command:**
```bash
iverilog -o dmem_test rtl/address_decoder.v rtl/data_memory.v testbench/data_memory_tb.v
vvp dmem_test
```

---

## 5. Timing Analysis

### Write Timing: Synchronous (posedge clk)

Data is latched into the memory array **only** on the rising edge of `clk` when `mem_write = 1`. This was explicitly verified in **Test D10**:
- Before the clock edge: `read_data` still shows the old value (`0x00`).
- After the clock edge: `read_data` shows the newly written value (`0x77`).

This synchronous write ensures data integrity and prevents glitches from propagating into memory during combinational settling.

### Read Timing: Asynchronous (Combinational)

The read path is purely combinational with no clock dependency. This was explicitly verified in **Test D11**:
- Changing `addr` from 4 → 9 → 6 without any clock edge caused `read_data` to update immediately each time.
- This is essential for the single-cycle processor: the loaded value must settle within the same cycle for register writeback.

### Simultaneous Read/Write Behavior

Verified in **Test D8**: When both `mem_read = 1` and `mem_write = 1` are asserted on the same address:
- The combinational read sees the **old** stored value (before the clock edge).
- The new value is written on the clock edge and becomes visible on subsequent reads.

This matches the expected single-cycle processor behavior where STORE writes happen on the clock edge and do not affect the current cycle's read path.

---

## 6. LOAD/STORE Integration Compatibility

### How Data Memory Wires into Top Module

From `top_module.v` (lines 203–213):

| Top Module Signal | Data Memory Port | Source |
|---|---|---|
| `clk` | `clk` | System clock |
| `reset` | `reset` | Active-high synchronous reset |
| `mem_read` | `mem_read` | Control unit (LOAD opcode `0001`) |
| `mem_write` | `mem_write` | Control unit (STORE opcode `0010`) |
| `dmem_addr` = `instr[9:6]` | `addr` | Instruction field — 4-bit memory address |
| `read_data1` | `write_data` | Register file read port 1 (source register for STORE) |
| `dmem_read_data` | `read_data` | Fed to writeback mux via `mem_to_reg` |

### Verified Against `program.hex`

**Test D12** directly simulates the STORE/LOAD sequence from `program.hex`:

| Instruction | Hex | Action | Verified |
|---|---|---|---|
| `STORE R1, [2]` | `2480` | Write value 8 to `DMEM[2]` | ✅ PASS |
| `LOAD R3, [2]` | `1C80` | Read `DMEM[2]` → R3 = 8 | ✅ PASS |

Boundary addresses (0 and 15) were also verified with STORE/LOAD round-trips to confirm the full 4-bit address space works correctly.

The full processor testbench (`testbench/processor_tb.v`) independently confirms `uut.dmem_inst.mem[2] == 8'd8` as the expected final state.

---

## 7. Summary

| Test Suite | Tests | Passed | Failed |
|---|---|---|---|
| Address Decoder (`address_decoder_tb.v`) | A1–A4 (40+ individual checks) | All | 0 |
| Data Memory (`data_memory_tb.v`) | D1–D12 (79 individual checks) | 79 | 0 |
| **Total** | **119+ checks** | **All** | **0** |

### VCD Waveform Files Generated
- `address_decoder.vcd` — Address decoder signal transitions
- `data_memory_phase2.vcd` — Data memory read/write timing waveforms

### Files in This PR
| File | Action |
|---|---|
| `testbench/data_memory_tb.v` | Rewritten — 12 test categories, 79 automated checks |
| `testbench/address_decoder_tb.v` | New — 4 test categories with full one-hot verification |
| `docs/data_memory_verification.md` | New — this document |

### Files NOT Modified
- `rtl/data_memory.v` — RTL unchanged (verification only)
- `rtl/address_decoder.v` — RTL unchanged (verification only)
- `rtl/control_unit.v` — Not in scope
- `rtl/top_module.v` — Not in scope
