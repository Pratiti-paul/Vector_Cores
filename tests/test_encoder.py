"""
tests/test_encoder.py – Unit tests for the encoder module.

Expected values are hand-calculated independently from the encoder under test.
Every binary derivation is shown in the comment above each test.

Bit layout reminder:
  [15:12] opcode (4 bits)
  [11:10] rd / rs_beq
  [9:8]   rs / rt_beq
  [7:6]   rt (R-type only)
  [5:0]   reserved zeros  (LOAD/STORE/R-type)
  [7:0]   imm/offset (ADDI/BEQ)
  [3:0]   addr (JUMP)
"""

import pytest
from assembler.encoder import (
    encode_load, encode_store, encode_rtype,
    encode_addi, encode_beq, encode_jump, encode_halt,
    to_hex_line,
)


# ---------------------------------------------------------------------------
# LOAD
# ---------------------------------------------------------------------------

class TestEncodeLoad:

    def test_load_r3_addr2(self):
        """
        LOAD R3, [2]
        opcode=0001  rd=11  addr=0010  unused=000000
        0001 11 0010 000000  = 0001_1100_1000_0000 = 0x1C80
        """
        assert encode_load(rd=3, dmem_addr=2) == 0x1C80

    def test_load_r0_addr0(self):
        """
        LOAD R0, [0]
        0001 00 0000 000000 = 0001_0000_0000_0000 = 0x1000
        """
        assert encode_load(rd=0, dmem_addr=0) == 0x1000

    def test_load_r1_addr15(self):
        """
        LOAD R1, [15]
        0001 01 1111 000000 = 0001_0111_1100_0000 = 0x17C0
        """
        assert encode_load(rd=1, dmem_addr=15) == 0x17C0

    def test_load_r2_addr8(self):
        """
        LOAD R2, [8]  addr=1000
        0001 10 1000 000000 = 0001_1010_0000_0000 = 0x1A00
        """
        assert encode_load(rd=2, dmem_addr=8) == 0x1A00

    def test_load_reserved_bits_zero(self):
        """Reserved bits [5:0] must be zero."""
        word = encode_load(rd=1, dmem_addr=3)
        assert (word & 0x003F) == 0


# ---------------------------------------------------------------------------
# STORE
# ---------------------------------------------------------------------------

class TestEncodeStore:

    def test_store_r1_addr2(self):
        """
        STORE R1, [2]
        opcode=0010  rs=01  addr=0010  unused=000000
        0010 01 0010 000000 = 0010_0100_1000_0000 = 0x2480
        """
        assert encode_store(rs=1, dmem_addr=2) == 0x2480

    def test_store_r0_addr0(self):
        """
        STORE R0, [0]
        0010 00 0000 000000 = 0x2000
        """
        assert encode_store(rs=0, dmem_addr=0) == 0x2000

    def test_store_r3_addr15(self):
        """
        STORE R3, [15]
        0010 11 1111 000000 = 0010_1111_1100_0000 = 0x2FC0
        """
        assert encode_store(rs=3, dmem_addr=15) == 0x2FC0

    def test_store_reserved_bits_zero(self):
        word = encode_store(rs=2, dmem_addr=5)
        assert (word & 0x003F) == 0


# ---------------------------------------------------------------------------
# ADD
# ---------------------------------------------------------------------------

class TestEncodeAdd:

    def test_add_r1_r1_r2(self):
        """
        ADD R1, R1, R2
        opcode=0011  rd=01  rs=01  rt=10  unused=000000
        0011 01 01 10 000000 = 0011_0101_1000_0000 = 0x3580
        """
        assert encode_rtype("ADD", rd=1, rs=1, rt=2) == 0x3580

    def test_add_r0_r0_r0(self):
        """
        ADD R0, R0, R0
        0011 00 00 00 000000 = 0x3000
        """
        assert encode_rtype("ADD", rd=0, rs=0, rt=0) == 0x3000

    def test_add_r3_r2_r1(self):
        """
        ADD R3, R2, R1
        0011 11 10 01 000000 = 0011_1110_0100_0000 = 0x3E40
        """
        assert encode_rtype("ADD", rd=3, rs=2, rt=1) == 0x3E40

    def test_add_reserved_bits_zero(self):
        word = encode_rtype("ADD", rd=1, rs=2, rt=3)
        assert (word & 0x003F) == 0


# ---------------------------------------------------------------------------
# SUB
# ---------------------------------------------------------------------------

class TestEncodeSub:

    def test_sub_r1_r1_r2(self):
        """
        SUB R1, R1, R2
        opcode=0100  rd=01  rs=01  rt=10  unused=000000
        0100 01 01 10 000000 = 0100_0101_1000_0000 = 0x4580
        """
        assert encode_rtype("SUB", rd=1, rs=1, rt=2) == 0x4580

    def test_sub_r3_r3_r0(self):
        """
        SUB R3, R3, R0
        0100 11 11 00 000000 = 0100_1111_0000_0000 = 0x4F00
        """
        assert encode_rtype("SUB", rd=3, rs=3, rt=0) == 0x4F00

    def test_sub_reserved_bits_zero(self):
        word = encode_rtype("SUB", rd=0, rs=1, rt=2)
        assert (word & 0x003F) == 0


# ---------------------------------------------------------------------------
# ADDI
# ---------------------------------------------------------------------------

class TestEncodeAddi:

    def test_addi_r1_r0_pos5(self):
        """
        ADDI R1, R0, 5
        opcode=0101  rd=01  rs=00  imm=0000_0101
        0101 01 00 0000_0101 = 0101_0100_0000_0101 = 0x5405
        """
        assert encode_addi(rd=1, rs=0, imm=5) == 0x5405

    def test_addi_r2_r0_pos3(self):
        """
        ADDI R2, R0, 3
        0101 10 00 0000_0011 = 0x5803
        """
        assert encode_addi(rd=2, rs=0, imm=3) == 0x5803

    def test_addi_r3_r3_pos1(self):
        """
        ADDI R3, R3, 1
        0101 11 11 0000_0001 = 0101_1111_0000_0001 = 0x5F01
        """
        assert encode_addi(rd=3, rs=3, imm=1) == 0x5F01

    def test_addi_r0_r0_neg1(self):
        """
        ADDI R0, R0, -1   imm = -1 → two's complement 0xFF
        0101 00 00 1111_1111 = 0101_0000_1111_1111 = 0x50FF
        """
        assert encode_addi(rd=0, rs=0, imm=-1) == 0x50FF

    def test_addi_min_imm(self):
        """
        ADDI R1, R0, -128   imm = 0x80
        0101 01 00 1000_0000 = 0101_0100_1000_0000 = 0x5480
        """
        assert encode_addi(rd=1, rs=0, imm=-128) == 0x5480

    def test_addi_max_imm(self):
        """
        ADDI R1, R0, 127   imm = 0x7F
        0101 01 00 0111_1111 = 0101_0100_0111_1111 = 0x547F
        """
        assert encode_addi(rd=1, rs=0, imm=127) == 0x547F

    def test_addi_r1_r0_pos12(self):
        """
        ADDI R1, R0, 12 = 0x0C
        0101 01 00 0000_1100 = 0x540C
        """
        assert encode_addi(rd=1, rs=0, imm=12) == 0x540C

    def test_addi_r2_r0_pos10(self):
        """
        ADDI R2, R0, 10 = 0x0A
        0101 10 00 0000_1010 = 0x580A
        """
        assert encode_addi(rd=2, rs=0, imm=10) == 0x580A

    def test_addi_r1_r0_pos0(self):
        """
        ADDI R1, R0, 0
        0101 01 00 0000_0000 = 0x5400
        """
        assert encode_addi(rd=1, rs=0, imm=0) == 0x5400


# ---------------------------------------------------------------------------
# BEQ
# ---------------------------------------------------------------------------

class TestEncodeBeq:

    def test_beq_r1_r2_offset_pos2(self):
        """
        BEQ R1, R2, +2
        opcode=0110  rs=01  rt=10  offset=0000_0010
        0110 01 10 0000_0010 = 0110_0110_0000_0010 = 0x6602
        """
        assert encode_beq(rs=1, rt=2, offset=2) == 0x6602

    def test_beq_r0_r1_offset_neg1(self):
        """
        BEQ R0, R1, -1  offset = 0xFF
        0110 00 01 1111_1111 = 0110_0001_1111_1111 = 0x61FF
        """
        assert encode_beq(rs=0, rt=1, offset=-1) == 0x61FF

    def test_beq_r0_r0_offset_zero(self):
        """
        BEQ R0, R0, 0  (infinite loop on equality)
        0110 00 00 0000_0000 = 0x6000
        """
        assert encode_beq(rs=0, rt=0, offset=0) == 0x6000

    def test_beq_r3_r2_offset_neg4(self):
        """
        BEQ R3, R2, -4  offset = 0xFC
        0110 11 10 1111_1100 = 0110_1110_1111_1100 = 0x6EFC
        """
        assert encode_beq(rs=3, rt=2, offset=-4) == 0x6EFC

    def test_beq_min_offset(self):
        """offset = -128 → 0x80"""
        word = encode_beq(rs=0, rt=0, offset=-128)
        assert (word & 0x00FF) == 0x80

    def test_beq_max_offset(self):
        """offset = +127 → 0x7F"""
        word = encode_beq(rs=0, rt=0, offset=127)
        assert (word & 0x00FF) == 0x7F


# ---------------------------------------------------------------------------
# JUMP
# ---------------------------------------------------------------------------

class TestEncodeJump:

    def test_jump_addr5(self):
        """
        JUMP 5
        opcode=0111  reserved=0000_0000  addr=0101
        0111 0000_0000 0101 = 0111_0000_0000_0101 = 0x7005
        """
        assert encode_jump(addr=5) == 0x7005

    def test_jump_addr0(self):
        """
        JUMP 0
        0111 0000_0000 0000 = 0x7000
        """
        assert encode_jump(addr=0) == 0x7000

    def test_jump_addr15(self):
        """
        JUMP 15 = 0xF
        0111 0000_0000 1111 = 0x700F
        """
        assert encode_jump(addr=15) == 0x700F

    def test_jump_addr2(self):
        """JUMP 2 → 0x7002"""
        assert encode_jump(addr=2) == 0x7002

    def test_jump_reserved_bits_zero(self):
        """Bits [11:4] must be 0."""
        word = encode_jump(addr=7)
        assert (word & 0x0FF0) == 0


# ---------------------------------------------------------------------------
# AND
# ---------------------------------------------------------------------------

class TestEncodeAnd:

    def test_and_r3_r1_r2(self):
        """
        AND R3, R1, R2
        opcode=1000  rd=11  rs=01  rt=10  unused=000000
        1000 11 01 10 000000 = 1000_1101_1000_0000 = 0x8D80
        """
        assert encode_rtype("AND", rd=3, rs=1, rt=2) == 0x8D80

    def test_and_r0_r0_r0(self):
        """
        AND R0, R0, R0
        1000 00 00 00 000000 = 0x8000
        """
        assert encode_rtype("AND", rd=0, rs=0, rt=0) == 0x8000

    def test_and_reserved_bits_zero(self):
        word = encode_rtype("AND", rd=1, rs=2, rt=3)
        assert (word & 0x003F) == 0

    def test_and_opcode(self):
        """AND opcode must be 0b1000."""
        word = encode_rtype("AND", rd=0, rs=0, rt=0)
        assert (word >> 12) == 0b1000


# ---------------------------------------------------------------------------
# OR
# ---------------------------------------------------------------------------

class TestEncodeOr:

    def test_or_r3_r1_r2(self):
        """
        OR R3, R1, R2
        opcode=1001  rd=11  rs=01  rt=10  unused=000000
        1001 11 01 10 000000 = 1001_1101_1000_0000 = 0x9D80
        """
        assert encode_rtype("OR", rd=3, rs=1, rt=2) == 0x9D80

    def test_or_reserved_bits_zero(self):
        word = encode_rtype("OR", rd=1, rs=2, rt=3)
        assert (word & 0x003F) == 0

    def test_or_opcode(self):
        word = encode_rtype("OR", rd=0, rs=0, rt=0)
        assert (word >> 12) == 0b1001


# ---------------------------------------------------------------------------
# XOR
# ---------------------------------------------------------------------------

class TestEncodeXor:

    def test_xor_r3_r1_r2(self):
        """
        XOR R3, R1, R2
        opcode=1010  rd=11  rs=01  rt=10  unused=000000
        1010 11 01 10 000000 = 1010_1101_1000_0000 = 0xAD80
        """
        assert encode_rtype("XOR", rd=3, rs=1, rt=2) == 0xAD80

    def test_xor_reserved_bits_zero(self):
        word = encode_rtype("XOR", rd=1, rs=2, rt=3)
        assert (word & 0x003F) == 0

    def test_xor_opcode(self):
        word = encode_rtype("XOR", rd=0, rs=0, rt=0)
        assert (word >> 12) == 0b1010


# ---------------------------------------------------------------------------
# HALT
# ---------------------------------------------------------------------------

class TestEncodeHalt:

    def test_halt(self):
        """HALT → 0xF000"""
        assert encode_halt() == 0xF000

    def test_halt_opcode(self):
        assert (encode_halt() >> 12) == 0b1111

    def test_halt_body_zero(self):
        """Lower 12 bits must all be zero."""
        assert (encode_halt() & 0x0FFF) == 0


# ---------------------------------------------------------------------------
# to_hex_line
# ---------------------------------------------------------------------------

class TestToHexLine:

    def test_uppercase(self):
        assert to_hex_line(0x1C80) == "1C80"

    def test_zero_padded(self):
        assert to_hex_line(0x0005) == "0005"

    def test_max(self):
        assert to_hex_line(0xFFFF) == "FFFF"

    def test_halt_line(self):
        assert to_hex_line(0xF000) == "F000"

    def test_four_chars(self):
        """Every output must be exactly 4 characters."""
        for val in [0x0000, 0x0001, 0x1000, 0xFFFF, 0x5405]:
            assert len(to_hex_line(val)) == 4
