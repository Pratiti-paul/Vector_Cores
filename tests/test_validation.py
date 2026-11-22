"""
tests/test_validation.py – Unit tests for the validator module.

Tests all validation functions with both valid and invalid inputs.
Error messages must include the source line number.
"""

import pytest
from assembler.validator import (
    AssemblerError,
    validate_register, validate_dmem_address, validate_imm8,
    validate_iaddr, validate_beq_offset, validate_operand_count,
    validate_program_size,
)


# ---------------------------------------------------------------------------
# validate_register
# ---------------------------------------------------------------------------

class TestValidateRegister:

    @pytest.mark.parametrize("token,expected", [
        ("R0", 0), ("R1", 1), ("R2", 2), ("R3", 3),
        ("r0", 0), ("r1", 1), ("r2", 2), ("r3", 3),
        ("R0", 0), ("R2", 2),
    ])
    def test_valid_registers(self, token, expected):
        assert validate_register(token, line_no=1) == expected

    @pytest.mark.parametrize("bad", ["R4", "R5", "R10", "X0", "REG1", "0", ""])
    def test_invalid_registers(self, bad):
        with pytest.raises(AssemblerError, match="Invalid register"):
            validate_register(bad, line_no=5)

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 7"):
            validate_register("R9", line_no=7)

    def test_error_lists_valid_registers(self):
        with pytest.raises(AssemblerError, match="R0, R1, R2, R3"):
            validate_register("R8", line_no=1)


# ---------------------------------------------------------------------------
# validate_dmem_address
# ---------------------------------------------------------------------------

class TestValidateDmemAddress:

    @pytest.mark.parametrize("token,expected", [
        ("[0]", 0), ("[15]", 15), ("[8]", 8), ("[2]", 2),
    ])
    def test_valid_addresses(self, token, expected):
        assert validate_dmem_address(token, line_no=1) == expected

    def test_missing_brackets(self):
        with pytest.raises(AssemblerError, match="syntax"):
            validate_dmem_address("2", line_no=1)

    def test_only_open_bracket(self):
        with pytest.raises(AssemblerError, match="syntax"):
            validate_dmem_address("[2", line_no=1)

    def test_address_too_large(self):
        with pytest.raises(AssemblerError, match="out of range"):
            validate_dmem_address("[16]", line_no=3)

    def test_negative_address(self):
        with pytest.raises(AssemblerError, match="out of range"):
            validate_dmem_address("[-1]", line_no=3)

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 9"):
            validate_dmem_address("[16]", line_no=9)


# ---------------------------------------------------------------------------
# validate_imm8
# ---------------------------------------------------------------------------

class TestValidateImm8:

    @pytest.mark.parametrize("token,expected", [
        ("0", 0), ("127", 127), ("-128", -128), ("5", 5),
        ("-1", -1), ("100", 100), ("0x0A", 10), ("0x7F", 127),
    ])
    def test_valid_immediates(self, token, expected):
        assert validate_imm8(token, line_no=1) == expected

    def test_too_large(self):
        with pytest.raises(AssemblerError, match="out of signed 8-bit range"):
            validate_imm8("128", line_no=2)

    def test_too_small(self):
        with pytest.raises(AssemblerError, match="out of signed 8-bit range"):
            validate_imm8("-129", line_no=2)

    def test_non_numeric(self):
        with pytest.raises(AssemblerError, match="Cannot parse"):
            validate_imm8("abc", line_no=1)

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 11"):
            validate_imm8("999", line_no=11)

    def test_boundary_min(self):
        assert validate_imm8("-128", line_no=1) == -128

    def test_boundary_max(self):
        assert validate_imm8("127", line_no=1) == 127


# ---------------------------------------------------------------------------
# validate_iaddr (JUMP target)
# ---------------------------------------------------------------------------

class TestValidateIaddr:

    @pytest.mark.parametrize("token,expected", [
        ("0", 0), ("15", 15), ("5", 5), ("10", 10),
    ])
    def test_valid_addresses(self, token, expected):
        assert validate_iaddr(token, line_no=1) == expected

    def test_too_large(self):
        with pytest.raises(AssemblerError, match="out of range"):
            validate_iaddr("16", line_no=1)

    def test_negative(self):
        with pytest.raises(AssemblerError, match="out of range"):
            validate_iaddr("-1", line_no=1)

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 4"):
            validate_iaddr("20", line_no=4)


# ---------------------------------------------------------------------------
# validate_beq_offset
# ---------------------------------------------------------------------------

class TestValidateBeqOffset:

    @pytest.mark.parametrize("offset", [0, 1, 127, -1, -128, 2, -4])
    def test_valid_offsets(self, offset):
        assert validate_beq_offset(offset, line_no=1) == offset

    def test_too_large(self):
        with pytest.raises(AssemblerError, match="out of signed 8-bit range"):
            validate_beq_offset(128, line_no=1)

    def test_too_small(self):
        with pytest.raises(AssemblerError, match="out of signed 8-bit range"):
            validate_beq_offset(-129, line_no=1)

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 6"):
            validate_beq_offset(200, line_no=6)


# ---------------------------------------------------------------------------
# validate_operand_count
# ---------------------------------------------------------------------------

class TestValidateOperandCount:

    def test_correct_count_passes(self):
        validate_operand_count("ADD", expected=3, got=3, line_no=1)  # no raise

    def test_too_few_raises(self):
        with pytest.raises(AssemblerError, match="expects 3 operand"):
            validate_operand_count("ADD", expected=3, got=2, line_no=1)

    def test_too_many_raises(self):
        with pytest.raises(AssemblerError, match="expects 1 operand"):
            validate_operand_count("JUMP", expected=1, got=3, line_no=1)

    def test_zero_operands_halt(self):
        validate_operand_count("HALT", expected=0, got=0, line_no=1)  # no raise

    def test_error_contains_line_number(self):
        with pytest.raises(AssemblerError, match="line 8"):
            validate_operand_count("ADD", expected=3, got=1, line_no=8)


# ---------------------------------------------------------------------------
# validate_program_size
# ---------------------------------------------------------------------------

class TestValidateProgramSize:

    @pytest.mark.parametrize("count", [0, 1, 8, 15, 16])
    def test_valid_sizes(self, count):
        validate_program_size(count)  # must not raise

    def test_too_large(self):
        with pytest.raises(AssemblerError, match="too large"):
            validate_program_size(17)

    def test_exactly_17_raises(self):
        with pytest.raises(AssemblerError, match="17 instructions"):
            validate_program_size(17)
