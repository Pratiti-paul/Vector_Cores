"""
instructions.py – Centralized instruction definitions for the Vector Cores assembler.

This module is the single source of truth for:
  - Opcode assignments
  - Instruction formats and field widths
  - Register definitions

Architecture reference:
  - 16-bit instruction word
  - 4-bit opcode  [15:12]
  - 4 general-purpose registers R0–R3 (2-bit addresses)
  - R0 is HARDWARE-ENFORCED as zero (confirmed in register_file.v:
      write blocked when write_reg == 2'b00; reads return 8'b0)
  - Instruction memory: 16 locations × 16 bits (4-bit PC)
  - Data memory:        16 locations × 8 bits  (4-bit address)

BEQ branch offset convention (confirmed in top_module.v):
  branch_target = pc_plus_1 + offset[3:0]
  → offset = target_address − (BEQ_address + 1)   [PC+1-relative]

JUMP uses an absolute 4-bit instruction address from instr[3:0].

AND / OR / XOR status:
  - Opcodes 1000 / 1001 / 1010 are PROPOSED by this assembler (Phase II).
  - The ALU (alu.v on main) already supports AND/OR/XOR with 3-bit alu_control.
  - control_unit.v on main still uses 2-bit alu_control and does NOT yet
    decode opcodes 1000/1001/1010 (they hit 'default: pc_enable=0').
  - Hardware integration of AND/OR/XOR in the control unit is pending
    (tracked on branch alisha/alu-3bit).
  - The assembler correctly encodes these instructions; they will execute
    once the hardware team merges the control-unit update.
"""

from dataclasses import dataclass, field
from typing import Dict, List


# ---------------------------------------------------------------------------
# Register definitions
# ---------------------------------------------------------------------------

REGISTERS: Dict[str, int] = {
    "R0": 0,
    "R1": 1,
    "R2": 2,
    "R3": 3,
}

VALID_REGISTERS = list(REGISTERS.keys())   # ["R0", "R1", "R2", "R3"]

# ---------------------------------------------------------------------------
# Instruction memory limits
# ---------------------------------------------------------------------------

IMEM_SIZE = 16          # Maximum instruction words
IMEM_ADDR_BITS = 4      # Bits in instruction address (PC width)
DMEM_ADDR_BITS = 4      # Bits in data memory address
REG_ADDR_BITS = 2       # Bits in register address (R0–R3)
INSTRUCTION_WIDTH = 16  # Total instruction word width in bits
HALT_ENCODING = 0xF000  # Default fill for unused memory locations

# ---------------------------------------------------------------------------
# Immediate / offset ranges
# ---------------------------------------------------------------------------

IMM8_MIN = -128
IMM8_MAX = 127

# ---------------------------------------------------------------------------
# Instruction format descriptors
# ---------------------------------------------------------------------------

@dataclass
class InstructionDef:
    """Describes one instruction's opcode and operand format."""
    name: str
    opcode: int           # 4-bit opcode value (0–15)
    operands: List[str]   # Ordered list of operand types for validation
    # Operand type tokens:
    #   "REG"   – 2-bit register address (R0–R3)
    #   "DMEM"  – 4-bit data-memory address [0–15], written as [n]
    #   "IMM8"  – signed 8-bit immediate
    #   "OFF8"  – signed 8-bit BEQ offset (PC+1-relative)
    #   "IADDR" – 4-bit absolute instruction address (JUMP target)


# ---------------------------------------------------------------------------
# Opcode table
# ---------------------------------------------------------------------------
# Key: uppercase instruction name
# Value: InstructionDef

INSTRUCTIONS: Dict[str, InstructionDef] = {
    "LOAD":  InstructionDef("LOAD",  0b0001, ["REG",  "DMEM"]),
    "STORE": InstructionDef("STORE", 0b0010, ["REG",  "DMEM"]),
    "ADD":   InstructionDef("ADD",   0b0011, ["REG",  "REG",  "REG"]),
    "SUB":   InstructionDef("SUB",   0b0100, ["REG",  "REG",  "REG"]),
    "ADDI":  InstructionDef("ADDI",  0b0101, ["REG",  "REG",  "IMM8"]),
    "BEQ":   InstructionDef("BEQ",   0b0110, ["REG",  "REG",  "OFF8"]),
    "JUMP":  InstructionDef("JUMP",  0b0111, ["IADDR"]),
    # --- Logical instructions (Phase II – opcodes pending CU hardware merge) ---
    "AND":   InstructionDef("AND",   0b1000, ["REG",  "REG",  "REG"]),
    "OR":    InstructionDef("OR",    0b1001, ["REG",  "REG",  "REG"]),
    "XOR":   InstructionDef("XOR",   0b1010, ["REG",  "REG",  "REG"]),
    # --- Terminal instruction ---
    "HALT":  InstructionDef("HALT",  0b1111, []),
}

# Opcodes that require hardware-team merge before they execute on the processor
PENDING_HW_OPCODES = {"AND", "OR", "XOR"}
