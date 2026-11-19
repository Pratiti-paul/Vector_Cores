"""
validator.py – Operand validation for the Vector Cores assembler.

All validation functions raise AssemblerError on failure.
Every error message includes the source line number.
"""

from assembler.instructions import (
    REGISTERS, IMEM_SIZE, IMM8_MIN, IMM8_MAX,
)


class AssemblerError(Exception):
    """Raised for any assembly-time error."""
    pass


def _fmt(line_no: int, msg: str) -> str:
    return f"Error at line {line_no}:\n  {msg}"


def validate_register(token: str, line_no: int) -> int:
    """
    Validate and return the 2-bit integer address for a register token.
    Accepts case-insensitive names (r0, R0, r1, R1, …).
    """
    upper = token.upper()
    if upper not in REGISTERS:
        raise AssemblerError(
            _fmt(line_no,
                 f"Invalid register '{token}'.\n"
                 f"  Supported registers: R0, R1, R2, R3.")
        )
    return REGISTERS[upper]


def validate_dmem_address(token: str, line_no: int) -> int:
    """
    Validate a data-memory address token of the form [n] where 0 ≤ n ≤ 15.
    Returns the integer address.
    """
    stripped = token.strip()
    if not (stripped.startswith("[") and stripped.endswith("]")):
        raise AssemblerError(
            _fmt(line_no,
                 f"Invalid memory address syntax '{token}'.\n"
                 f"  Expected format: [0] to [15].")
        )
    inner = stripped[1:-1].strip()
    try:
        addr = _parse_int(inner, line_no)
    except AssemblerError:
        raise AssemblerError(
            _fmt(line_no,
                 f"Invalid memory address value '{inner}'.\n"
                 f"  Expected an integer 0–15.")
        )
    if not (0 <= addr <= 15):
        raise AssemblerError(
            _fmt(line_no,
                 f"Data memory address {addr} is out of range.\n"
                 f"  Valid range: 0 to 15 (4-bit address space).")
        )
    return addr


def validate_imm8(token: str, line_no: int) -> int:
    """
    Validate a signed 8-bit immediate value (−128 to +127).
    Accepts decimal (5, -3) and hexadecimal (0x0A, 0xFF) literals.
    Returns the integer value.
    """
    value = _parse_int(token, line_no)
    if not (IMM8_MIN <= value <= IMM8_MAX):
        raise AssemblerError(
            _fmt(line_no,
                 f"Immediate value {value} is out of signed 8-bit range.\n"
                 f"  Valid range: {IMM8_MIN} to {IMM8_MAX}.")
        )
    return value


def validate_iaddr(token: str, line_no: int) -> int:
    """
    Validate an absolute instruction-memory address (0–15).
    Used by JUMP when a numeric target is given (not a label).
    Returns the integer address.
    """
    value = _parse_int(token, line_no)
    if not (0 <= value <= 15):
        raise AssemblerError(
            _fmt(line_no,
                 f"Instruction address {value} is out of range.\n"
                 f"  Valid range: 0 to 15 (4-bit instruction memory).")
        )
    return value


def validate_beq_offset(offset: int, line_no: int) -> int:
    """
    Validate a resolved BEQ offset value (−128 to +127).
    Called after label resolution; offset is already an integer.
    """
    if not (IMM8_MIN <= offset <= IMM8_MAX):
        raise AssemblerError(
            _fmt(line_no,
                 f"BEQ branch offset {offset} is out of signed 8-bit range.\n"
                 f"  Valid range: {IMM8_MIN} to {IMM8_MAX}.\n"
                 f"  Hint: target address and BEQ address are too far apart.")
        )
    return offset


def validate_operand_count(instr_name: str, expected: int,
                           got: int, line_no: int) -> None:
    """Raise if the wrong number of operands was supplied."""
    if got != expected:
        raise AssemblerError(
            _fmt(line_no,
                 f"'{instr_name}' expects {expected} operand(s), got {got}.")
        )


def validate_program_size(instruction_count: int) -> None:
    """Raise if the assembled program exceeds instruction memory capacity."""
    if instruction_count > IMEM_SIZE:
        raise AssemblerError(
            f"Program too large: {instruction_count} instructions assembled.\n"
            f"  Instruction memory holds a maximum of {IMEM_SIZE} words."
        )


# ---------------------------------------------------------------------------
# Internal helper
# ---------------------------------------------------------------------------

def _parse_int(token: str, line_no: int) -> int:
    """Parse a decimal or hexadecimal integer literal."""
    stripped = token.strip()
    try:
        if stripped.lower().startswith("0x"):
            return int(stripped, 16)
        return int(stripped, 10)
    except ValueError:
        raise AssemblerError(
            _fmt(line_no,
                 f"Cannot parse '{token}' as an integer literal.")
        )
