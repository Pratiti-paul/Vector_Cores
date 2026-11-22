"""
assembler.py – Main entry point for the Vector Cores Python assembler.

Usage:
    python -m assembler.assembler <input.asm> [-o <output.hex>]
    python -m assembler.assembler --help

The assembler performs a two-pass assembly:
  Pass 1 – collect all label definitions (supports forward references)
  Pass 2 – parse + encode each instruction

Output is a program.hex file compatible with the Verilog $readmemh directive
used by instruction_memory.v:
  - Exactly 16 lines
  - 4 uppercase hexadecimal characters per line
  - No '0x' prefix
  - Unused locations padded with F000 (HALT)
"""

import argparse
import sys
from pathlib import Path
from typing import List

from assembler.instructions import (
    INSTRUCTIONS, IMEM_SIZE, HALT_ENCODING, PENDING_HW_OPCODES,
)
from assembler.parser import Parser
from assembler.encoder import (
    encode_load, encode_store, encode_rtype,
    encode_addi, encode_beq, encode_jump, encode_halt,
    to_hex_line,
)
from assembler.validator import (
    AssemblerError,
    validate_register, validate_dmem_address, validate_imm8,
    validate_iaddr, validate_beq_offset, validate_operand_count,
    validate_program_size, _parse_int,
)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def assemble(source: str) -> List[int]:
    """
    Assemble *source* (a complete assembly program as a string) and return
    a list of exactly IMEM_SIZE (16) 16-bit instruction words.

    Raises AssemblerError for any syntax or semantic error.
    """
    parser = Parser(source)

    # Pass 1 – build label table
    labels = parser.collect_labels()

    # Pass 2 – parse into instruction tokens
    parsed = parser.parse(labels)

    # Size guard
    validate_program_size(len(parsed))

    # Warn about instructions that need hardware support
    _warn_pending_hw(parsed)

    # Encode each instruction
    words: List[int] = []
    for instr in parsed:
        word = _encode_instruction(instr, labels)
        words.append(word)

    # Pad to IMEM_SIZE with HALT
    while len(words) < IMEM_SIZE:
        words.append(HALT_ENCODING)

    return words


def words_to_hex(words: List[int]) -> str:
    """Convert a list of 16-bit words to a $readmemh-compatible hex string."""
    return "\n".join(to_hex_line(w) for w in words) + "\n"


def assemble_file(src_path: Path, out_path: Path) -> int:
    """
    Read *src_path*, assemble it, write *out_path*.
    Returns the number of real (non-padding) instructions assembled.
    """
    source = src_path.read_text(encoding="utf-8")
    words = assemble(source)
    real_count = sum(1 for w in words if w != HALT_ENCODING)
    out_path.write_text(words_to_hex(words), encoding="utf-8")
    return real_count


# ---------------------------------------------------------------------------
# Instruction dispatcher
# ---------------------------------------------------------------------------

RTYPE_NAMES = {"ADD", "SUB", "AND", "OR", "XOR"}


def _encode_instruction(instr, labels: dict) -> int:
    """Dispatch to the correct encoder for a ParsedInstruction."""
    name = instr.name
    ops = instr.operands
    ln = instr.line_no
    pc = instr.pc
    idef = INSTRUCTIONS[name]
    expected = len(idef.operands)
    validate_operand_count(name, expected, len(ops), ln)

    if name == "LOAD":
        rd   = validate_register(ops[0], ln)
        addr = validate_dmem_address(ops[1], ln)
        return encode_load(rd, addr)

    if name == "STORE":
        rs   = validate_register(ops[0], ln)
        addr = validate_dmem_address(ops[1], ln)
        return encode_store(rs, addr)

    if name in RTYPE_NAMES:
        rd = validate_register(ops[0], ln)
        rs = validate_register(ops[1], ln)
        rt = validate_register(ops[2], ln)
        return encode_rtype(name, rd, rs, rt)

    if name == "ADDI":
        rd  = validate_register(ops[0], ln)
        rs  = validate_register(ops[1], ln)
        imm = validate_imm8(ops[2], ln)
        return encode_addi(rd, rs, imm)

    if name == "BEQ":
        rs = validate_register(ops[0], ln)
        rt = validate_register(ops[1], ln)
        offset = _resolve_beq_offset(ops[2], pc, labels, ln)
        return encode_beq(rs, rt, offset)

    if name == "JUMP":
        addr = _resolve_jump_target(ops[0], labels, ln)
        return encode_jump(addr)

    if name == "HALT":
        return encode_halt()

    # Should never reach here (parser catches unknown instructions)
    raise AssemblerError(f"Internal error: unhandled instruction '{name}'.")


def _resolve_beq_offset(token: str, current_pc: int,
                        labels: dict, line_no: int) -> int:
    """
    Resolve a BEQ offset operand.
    - If it is a label name: offset = label_addr − (current_pc + 1)
    - If it is a numeric literal: use it directly (user pre-computed)
    Both paths validate the resulting offset is in [−128, +127].
    """
    stripped = token.strip()

    if stripped in labels:
        target = labels[stripped]
        offset = target - (current_pc + 1)
        return validate_beq_offset(offset, line_no)

    # Try as a numeric literal
    try:
        offset = _parse_int(stripped, line_no)
        return validate_beq_offset(offset, line_no)
    except AssemblerError:
        pass

    # Neither a label nor a number
    raise AssemblerError(
        f"Error at line {line_no}:\n"
        f"  Undefined label or invalid offset '{token}'.\n"
        f"  Use a defined label or a numeric offset."
    )


def _resolve_jump_target(token: str, labels: dict, line_no: int) -> int:
    """
    Resolve a JUMP target operand.
    - If it is a label name: return its instruction address
    - If it is a numeric literal: validate it is 0–15
    """
    stripped = token.strip()

    if stripped in labels:
        addr = labels[stripped]
        return validate_iaddr(str(addr), line_no)

    return validate_iaddr(stripped, line_no)


# ---------------------------------------------------------------------------
# Hardware warning
# ---------------------------------------------------------------------------

def _warn_pending_hw(parsed) -> None:
    """Print a warning if the program uses instructions without CU support."""
    used = {i.name for i in parsed if i.name in PENDING_HW_OPCODES}
    if used:
        print(
            f"[WARNING] The following instructions are encoded correctly but\n"
            f"  require the hardware team to merge branch alisha/alu-3bit\n"
            f"  before they will execute on the processor: {', '.join(sorted(used))}\n"
        )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="python -m assembler.assembler",
        description=(
            "Vector Cores Phase II Assembler\n"
            "Converts .asm source files into 16-bit hexadecimal machine code\n"
            "compatible with the $readmemh directive in instruction_memory.v."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Supported instructions:\n"
            "  LOAD, STORE, ADD, SUB, ADDI, BEQ, JUMP, AND, OR, XOR, HALT\n\n"
            "Register names: R0–R3 (case-insensitive). R0 is hardware zero.\n\n"
            "Examples:\n"
            "  python -m assembler.assembler assembler/samples/basic_alu.asm\n"
            "  python -m assembler.assembler assembler/samples/logical_ops.asm -o out.hex\n"
        ),
    )
    p.add_argument(
        "input",
        type=Path,
        help="Path to the .asm assembly source file.",
    )
    p.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Output .hex file path (default: program.hex in current directory).",
    )
    return p


def main(argv=None) -> int:
    parser = _build_argparser()
    args = parser.parse_args(argv)

    src_path: Path = args.input
    out_path: Path = args.output or Path("program.hex")

    if not src_path.exists():
        print(f"Error: Input file '{src_path}' not found.", file=sys.stderr)
        return 1

    try:
        count = assemble_file(src_path, out_path)
    except AssemblerError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(f"Assembly successful.")
    print(f"  Instructions assembled : {count} / {IMEM_SIZE}")
    print(f"  Padding                : {IMEM_SIZE - count} × F000 (HALT)")
    print(f"  Output written to      : {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
