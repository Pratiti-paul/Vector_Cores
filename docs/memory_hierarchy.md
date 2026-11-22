# Shared Lower-Level Memory (Two-Level Memory Hierarchy)

This document describes the optional **shared lower-level memory** from the Project 9 brief. The processor keeps separate instruction and data paths at level 1 (L1), using an instruction cache and a data cache. Both caches are backed by **one shared memory** at level 2 (L2). This "modified Harvard" organization is the one most real processors use.

## 1. Files

| File | Purpose |
|---|---|
| `rtl/hierarchy/shared_memory.v` | L2: 32 × 16 single-port memory with configurable wait states (`WAIT_CYCLES`, default 2) |
| `rtl/hierarchy/icache.v` | L1 instruction cache: direct-mapped, 8 lines × 16 bits |
| `rtl/hierarchy/dcache.v` | L1 data cache: direct-mapped, 4 lines × 8 bits, write-through, write-allocate |
| `rtl/hierarchy/mem_arbiter.v` | Connects both caches to the single L2 port (instruction cache has priority) |
| `rtl/hierarchy/mh_top_module.v` | Processor: same PC, control unit, register file and ALU as the Harvard design, plus stall logic |
| `testbench/memory_hierarchy_tb.v` | Runs four programs on four processors and checks state, cycles and cache statistics (376 checks) |

## 2. Organization

```text
                      Processor core (PC, control unit, register file, ALU)
                         | instruction path          | data path
                         v                           v
   Level 1 (Harvard)  +-----------------+        +-----------------+
                      | I-cache         |        | D-cache         |
                      | 8 x 16, direct- |        | 4 x 8, direct-  |
                      | mapped          |        | mapped, write-  |
                      +--------+--------+        | through         |
                               | refill          +--------+--------+
                               |                          | refill / write
                               +-----------+   +----------+
                                           v   v
                                      +-------------+
                                      | mem_arbiter |  I-cache first, one access at a time
                                      +------+------+
                                             v
   Level 2 (shared)               +----------------------+
                                  | shared_memory 32x16  |  0x00-0x0F instructions
                                  | single port,         |  0x10-0x1F data
                                  | 2 wait states        |
                                  +----------------------+
```

| Parameter | Value |
|---|---|
| I-cache | 8 lines × 1 instruction; index = PC[2:0], tag = PC[3] |
| D-cache | 4 lines × 1 byte; index = addr[1:0], tag = addr[3:2]; write-through, write-allocate |
| L2 memory | 32 × 16, single port, `WAIT_CYCLES` = 2 (an access takes 3 cycles) |
| I-cache miss penalty | WAIT_CYCLES + 1 = **3 cycles** (request and wait states, refill, then execute from the line) |
| D-cache LOAD miss penalty | WAIT_CYCLES = **2 cycles** (the data is forwarded to the register file) |
| STORE cost | WAIT_CYCLES = **2 cycles** (write-through to L2) |
| Cache disable | `CACHE_ENABLE = 0`: every fetch and LOAD goes to L2 (the "L2 only" configuration) |

**Cycle model:** for N instructions,

`cycles = N + 3 × (I-cache misses) + 2 × (LOAD misses + STOREs)`

The testbench checks this formula against the measured miss counts for every program.

**Design notes:**

- **Instruction path:** instructions are always executed from a cache line, never forwarded straight from L2. If they were, the decoded data address could select the L2 port address, which drives the L2 read data that feeds the instruction: a combinational loop. Filling first avoids this, at the cost of one extra cycle per instruction miss.
- **Write-through:** keeps L2 up to date, so the testbench checks the final data directly in L2. Instructions and data occupy separate L2 regions, and the instruction region is write-protected, so the caches never need to be kept coherent with each other.
- **Arbitration:** in this single-cycle core an instruction must be fetched before its data access is known. The two caches therefore take turns on the L2 port, and the arbiter only has to serialize them.

## 3. Results (simulation, 2 wait states)

| Program | N | Harvard | Von Neumann | **L1 caches + shared L2** | Shared L2 only | I-cache hit rate | LOAD hits |
|---|---:|---:|---:|---:|---:|---:|---:|
| P1 `program.hex` (straight line) | 7 | 7 | 9 | **33** | 35 | 0 / 8 (0%) | 1 / 1 |
| P2 memory-heavy | 10 | 10 | 17 | **51** | 57 | 0 / 11 (0%) | 3 / 3 |
| P3 compute loop | 16 | 16 | 16 | **34** | 67 | 11 / 17 (64.7%) | - |
| P4 memory loop (6 iterations) | 37 | 37 | 49 | **78** | 175 | 29 / 38 (76.3%) | 5 / 6 |

All four processors reach identical final registers, data memory and PC on every program.

- **Harvard and Von Neumann:** these baselines assume a memory that answers in the same cycle. They show the upper bound on performance.
- **The hierarchy:** it assumes the large memory is slow (2 wait states) and adds small, fast L1 caches in front of it.
- **Cache speed-up over "L2 only":**

  | Program | Speed-up |
  |---|---:|
  | P1 | 1.06× |
  | P2 | 1.12× |
  | P3 | **1.97×** |
  | P4 | **2.24×** |

  Straight-line code (P1, P2) gains little, because every instruction is fetched only once and every fetch is a compulsory miss. Loops (P3, P4) hit in the I-cache after the first iteration, and repeated LOADs hit in the D-cache.

### 3.1 Effect of Memory Latency

The same testbench run with 0, 2 and 5 wait states (set `localparam WAIT` in `testbench/memory_hierarchy_tb.v`):

| Program | Wait states | L1 + L2 cycles | L2-only cycles | Cache speed-up |
|---|---:|---:|---:|---:|
| P3 compute loop | 0 | 22 | 33 | 1.50× |
| P3 compute loop | 2 | 34 | 67 | 1.97× |
| P3 compute loop | 5 | 52 | 118 | 2.27× |
| P4 memory loop | 0 | 46 | 75 | 1.63× |
| P4 memory loop | 2 | 78 | 175 | 2.24× |
| P4 memory loop | 5 | 126 | 325 | 2.58× |

The slower the shared memory, the more the L1 caches are worth.

- **With 0 wait states:** the memory loop P4 takes 46 cycles with caches, against 49 for the Von Neumann processor. Even here the cached design wins, because LOADs hit in the D-cache instead of needing a second memory cycle.
- **At every latency tested:** all final-state checks and the cycle model pass.

### 3.2 Steady State of the P4 Loop

After the first iteration, each loop iteration (LOAD, ADDI, STORE, ADDI, BEQ, JUMP) runs entirely from the L1 caches. The only exception is the STORE, which is written through to L2.

| Configuration | Cycles per iteration | CPI |
|---|---:|---:|
| Ideal Harvard | 6 | 1.00 |
| Von Neumann | 8 | 1.33 |
| L1 caches + L2 | 8 | 1.33 |
| Shared L2 only | 6 + 3 × 6 + 2 × 2 = 28 | 4.67 |

## 4. Synthesis (iCE40 HX8K and Xilinx 7-Series)

| Metric | Harvard | Von Neumann | L1 caches + shared L2 |
|---|---:|---:|---:|
| iCE40 LUT4 | 321 | 571 | 689 |
| iCE40 flip-flops | 156 | 301 | 476 |
| **iCE40 Fmax (median of 5 seeds)** | **63.86 MHz** | **37.69 MHz** | **42.33 MHz** |
| Xilinx 7-Series LUTs | 202 | 287 | 325 |
| Xilinx flip-flops | 156 | 301 | 300 |
| Xilinx distributed RAM (`RAM32M`) | 0 | 0 | 5 (cache arrays) |

Reproduce with `bash synthesis/run_ice40.sh` and `bash synthesis/run_yosys_reports.sh`.

- **Hierarchy critical path (a LOAD miss):** PC → I-cache line read → decode → D-cache tag compare → arbiter address → L2 read → forwarded into the register file.
- **Comparison:** this path is shorter than the Von Neumann fetch path but longer than pure Harvard.
- **Possible improvement:** refilling the D-cache first and executing the LOAD in the next cycle, as the I-cache already does, would shorten the clock period at the cost of one cycle per LOAD miss.

## 5. How to Run

From the repository root:

```bash
iverilog -g2012 -s memory_hierarchy_tb -o mh_test rtl/*.v rtl/baseline/*.v rtl/hierarchy/*.v testbench/memory_hierarchy_tb.v
vvp mh_test
rm -f mh_test
```

The waveform is written to `simulation/waveforms/memory_hierarchy_wave.vcd`. Useful signals:

- **Core:** `mh.pc_current`, `mh.stall`
- **Caches:** `mh.icache_inst.hit`, `mh.dcache_inst.hit`
- **L2 port:** `mh.arb_inst.grant_d`, `mh.smem_inst.wait_cnt`, `mh.smem_inst.ready`
