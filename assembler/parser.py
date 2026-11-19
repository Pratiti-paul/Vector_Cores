"""
parser.py – Assembly source parser for the Vector Cores assembler.

Responsibilities:
  - Strip comments (# and ;) and blank lines.
  - Collect label definitions (Pass 1).
  - Tokenize each instruction line into (name, operands, source_line_no).
  - Support labels on their own line or prefixed on an instruction line.
  - Support forward and backward label references.
"""

import re
from typing import Dict, List, NamedTuple, Optional

from assembler.instructions import INSTRUCTIONS
from assembler.validator import AssemblerError


class ParsedInstruction(NamedTuple):
    """One fully tokenized instruction ready for encoding."""
    name: str             # Uppercase instruction mnemonic
    operands: List[str]   # Raw operand tokens (not yet validated/converted)
    line_no: int          # 1-based source line number for error reporting
    pc: int               # Instruction address (0-based index in output)


def strip_comment(line: str) -> str:
    """Remove everything from the first # or ; to end of line."""
    # Handle both comment styles while respecting content inside []
    result = []
    for ch in line:
        if ch in ("#", ";"):
            break
        result.append(ch)
    return "".join(result).strip()


def _is_label(token: str) -> bool:
    """Return True if token ends with ':' and is a valid label name."""
    if not token.endswith(":"):
        return False
    name = token[:-1]
    # Label must start with a letter or underscore, followed by [A-Za-z0-9_]
    return bool(re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name))


def _split_operands(raw: str) -> List[str]:
    """
    Split a comma-separated operand string into individual tokens.
    Preserves brackets so '[2]' stays as one token.
    """
    if not raw.strip():
        return []
    return [tok.strip() for tok in raw.split(",")]


class Parser:
    """Two-pass assembly parser."""

    def __init__(self, source: str):
        self._lines = source.splitlines()

    # ------------------------------------------------------------------
    # Pass 1 – collect label → PC-address mapping
    # ------------------------------------------------------------------

    def collect_labels(self) -> Dict[str, int]:
        """
        Scan every source line and build a label→instruction-address map.
        Labels on their own line point to the NEXT instruction.
        Labels on the same line as an instruction point to THAT instruction.
        Raises AssemblerError on duplicate labels or labels shadowing mnemonics.
        """
        labels: Dict[str, int] = {}
        pc = 0  # instruction address counter

        for line_no, raw in enumerate(self._lines, start=1):
            line = strip_comment(raw)
            if not line:
                continue

            # Tokenise by whitespace first to detect label prefix
            tokens = line.split()
            idx = 0

            # Collect consecutive labels at the front of the line
            while idx < len(tokens) and _is_label(tokens[idx]):
                label_name = tokens[idx][:-1]  # strip ':'
                self._check_label_name(label_name, line_no)
                if label_name in labels:
                    raise AssemblerError(
                        f"Error at line {line_no}:\n"
                        f"  Duplicate label '{label_name}'."
                    )
                labels[label_name] = pc
                idx += 1

            # If anything follows after label(s), it must be an instruction
            if idx < len(tokens):
                mnemonic = tokens[idx].upper()
                if mnemonic not in INSTRUCTIONS:
                    raise AssemblerError(
                        f"Error at line {line_no}:\n"
                        f"  Unknown instruction '{tokens[idx]}'.\n"
                        f"  Supported: {', '.join(sorted(INSTRUCTIONS))}."
                    )
                pc += 1

        return labels

    # ------------------------------------------------------------------
    # Pass 2 – produce ParsedInstruction list
    # ------------------------------------------------------------------

    def parse(self, labels: Dict[str, int]) -> List[ParsedInstruction]:
        """
        Parse every instruction line and return an ordered list of
        ParsedInstruction objects with raw operand tokens.
        Labels have already been resolved to addresses in `labels`.
        """
        instructions: List[ParsedInstruction] = []
        pc = 0

        for line_no, raw in enumerate(self._lines, start=1):
            line = strip_comment(raw)
            if not line:
                continue

            tokens = line.split()
            idx = 0

            # Skip leading labels (already handled in pass 1)
            while idx < len(tokens) and _is_label(tokens[idx]):
                idx += 1

            if idx >= len(tokens):
                continue  # label-only line

            mnemonic = tokens[idx].upper()
            if mnemonic not in INSTRUCTIONS:
                raise AssemblerError(
                    f"Error at line {line_no}:\n"
                    f"  Unknown instruction '{tokens[idx]}'.\n"
                    f"  Supported: {', '.join(sorted(INSTRUCTIONS))}."
                )

            # Everything after the mnemonic is the operand string
            operand_str = " ".join(tokens[idx + 1:])
            operands = _split_operands(operand_str)

            instructions.append(
                ParsedInstruction(
                    name=mnemonic,
                    operands=operands,
                    line_no=line_no,
                    pc=pc,
                )
            )
            pc += 1

        return instructions

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _check_label_name(name: str, line_no: int) -> None:
        """Reject label names that shadow instruction mnemonics."""
        if name.upper() in INSTRUCTIONS:
            raise AssemblerError(
                f"Error at line {line_no}:\n"
                f"  Label '{name}' shadows an instruction mnemonic.\n"
                f"  Choose a different label name."
            )
