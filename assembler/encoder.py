"""
encoder.py – 16-bit instruction encoder for the Vector Cores assembler.

Each encode_* function takes validated integer field values and returns
the complete 16-bit instruction word as a Python int.

Bit layout summary (all fields confirmed against RTL):
  [15:12]  opcode  (4 bits)
  [11:10]  rd / rs  (2 bits) – role depends on instruction
  [9:8]    rs / rt  (2 bits)
  [7:6]    rt       (2 bits)  – R-type only
  [9:6]    dmem_addr (4 bits) – LOAD / STORE
  [7:0]    imm8 / offset8 (8 bits, signed, 2's complement) – ADDI / BEQ
  [3:0]    jump_addr (4 bits) – JUMP
  others   reserved zeros

All reserved fields are explicitly zero-filled.
"""

from assembler.instructions import INSTRUCTIONS


def _pack(opcode: int, body: int) -> int:
    """Combine a 4-bit opcode with the lower 12 instruction bits."""
    assert 0 <= opcode <= 0xF, f"Opcode out of range: {opcode}"
    assert 0 <= body <= 0xFFF, f"Body out of range: {body:#05x}"
    return (opcode << 12) | body


def _signed8_to_uint8(value: int) -> int:
    """
    Convert a signed 8-bit integer (−128 to +127) to its
    unsigned 8-bit two's-complement representation (0–255).
    Python integers have arbitrary precision, so masking is required.
    """
    return value & 0xFF


# ---------------------------------------------------------------------------
# Individual instruction encoders
# ---------------------------------------------------------------------------

def encode_load(rd: int, dmem_addr: int) -> int:
    """
    LOAD rd, [addr]
    [15:12]=0001  [11:10]=rd  [9:6]=addr  [5:0]=000000
    """
    body = (rd << 10) | (dmem_addr << 6)
    return _pack(INSTRUCTIONS["LOAD"].opcode, body)


def encode_store(rs: int, dmem_addr: int) -> int:
    """
    STORE rs, [addr]
    [15:12]=0010  [11:10]=rs  [9:6]=addr  [5:0]=000000
    """
    body = (rs << 10) | (dmem_addr << 6)
    return _pack(INSTRUCTIONS["STORE"].opcode, body)


def encode_rtype(instr_name: str, rd: int, rs: int, rt: int) -> int:
    """
    R-type: ADD / SUB / AND / OR / XOR
    [15:12]=opcode  [11:10]=rd  [9:8]=rs  [7:6]=rt  [5:0]=000000
    """
    opcode = INSTRUCTIONS[instr_name].opcode
    body = (rd << 10) | (rs << 8) | (rt << 6)
    return _pack(opcode, body)


def encode_addi(rd: int, rs: int, imm: int) -> int:
    """
    ADDI rd, rs, imm   (imm is a signed 8-bit value)
    [15:12]=0101  [11:10]=rd  [9:8]=rs  [7:0]=imm (2's complement)
    """
    body = (rd << 10) | (rs << 8) | _signed8_to_uint8(imm)
    return _pack(INSTRUCTIONS["ADDI"].opcode, body)


def encode_beq(rs: int, rt: int, offset: int) -> int:
    """
    BEQ rs, rt, offset   (offset is signed 8-bit, PC+1-relative)
    [15:12]=0110  [11:10]=rs  [9:8]=rt  [7:0]=offset (2's complement)

    Branch semantics (confirmed in top_module.v):
      branch_target = (PC + 1) + offset[3:0]
      → offset = target_address − (BEQ_address + 1)
    """
    body = (rs << 10) | (rt << 8) | _signed8_to_uint8(offset)
    return _pack(INSTRUCTIONS["BEQ"].opcode, body)


def encode_jump(addr: int) -> int:
    """
    JUMP addr   (absolute 4-bit instruction address)
    [15:12]=0111  [11:4]=00000000  [3:0]=addr
    """
    body = addr & 0xF          # only lower 4 bits; [11:4] remain zero
    return _pack(INSTRUCTIONS["JUMP"].opcode, body)


def encode_halt() -> int:
    """
    HALT
    [15:12]=1111  [11:0]=000000000000
    """
    return _pack(INSTRUCTIONS["HALT"].opcode, 0)


# ---------------------------------------------------------------------------
# Hex output helper
# ---------------------------------------------------------------------------

def to_hex_line(word: int) -> str:
    """Format a 16-bit instruction word as 4 uppercase hex characters."""
    assert 0 <= word <= 0xFFFF, f"Word out of 16-bit range: {word}"
    return f"{word:04X}"
