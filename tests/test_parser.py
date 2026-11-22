"""
tests/test_parser.py – Unit tests for the parser module.

Tests cover:
  - Comment stripping (# and ;)
  - Blank line handling
  - Label collection (forward, backward, duplicate detection)
  - Operand splitting
  - Case-insensitive mnemonic handling
  - Unknown instruction detection
  - Label-shadows-mnemonic detection
"""

import pytest
from assembler.parser import Parser, strip_comment, _split_operands
from assembler.validator import AssemblerError


# ---------------------------------------------------------------------------
# strip_comment
# ---------------------------------------------------------------------------

class TestStripComment:

    def test_hash_comment(self):
        assert strip_comment("ADDI R1, R0, 5  # set R1=5") == "ADDI R1, R0, 5"

    def test_semicolon_comment(self):
        assert strip_comment("HALT ; stop") == "HALT"

    def test_no_comment(self):
        assert strip_comment("ADD R1, R1, R2") == "ADD R1, R1, R2"

    def test_comment_only_hash(self):
        assert strip_comment("# this is a comment") == ""

    def test_comment_only_semicolon(self):
        assert strip_comment("; another comment") == ""

    def test_blank_line(self):
        assert strip_comment("   ") == ""

    def test_empty_string(self):
        assert strip_comment("") == ""


# ---------------------------------------------------------------------------
# _split_operands
# ---------------------------------------------------------------------------

class TestSplitOperands:

    def test_three_registers(self):
        assert _split_operands("R1, R1, R2") == ["R1", "R1", "R2"]

    def test_register_and_address(self):
        assert _split_operands("R3, [2]") == ["R3", "[2]"]

    def test_addi_operands(self):
        assert _split_operands("R1, R0, 5") == ["R1", "R0", "5"]

    def test_single_operand(self):
        assert _split_operands("5") == ["5"]

    def test_empty(self):
        assert _split_operands("") == []


# ---------------------------------------------------------------------------
# Label collection (Pass 1)
# ---------------------------------------------------------------------------

class TestCollectLabels:

    def test_simple_forward_label(self):
        src = "ADDI R1, R0, 0\nLOOP: BEQ R1, R2, 0\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        assert labels["LOOP"] == 1

    def test_label_on_own_line(self):
        src = "ADDI R1, R0, 0\nLOOP:\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        assert labels["LOOP"] == 1   # points to HALT at address 1

    def test_forward_label_at_end(self):
        src = "JUMP DONE\nADDI R1, R0, 0\nDONE: HALT"
        p = Parser(src)
        labels = p.collect_labels()
        assert labels["DONE"] == 2

    def test_duplicate_label_raises(self):
        src = "LOOP: ADDI R1, R0, 0\nLOOP: HALT"
        p = Parser(src)
        with pytest.raises(AssemblerError, match="Duplicate label"):
            p.collect_labels()

    def test_label_shadows_mnemonic_raises(self):
        src = "HALT: ADDI R1, R0, 0"
        p = Parser(src)
        with pytest.raises(AssemblerError, match="shadows an instruction"):
            p.collect_labels()

    def test_no_labels(self):
        src = "ADDI R1, R0, 5\nHALT"
        p = Parser(src)
        assert p.collect_labels() == {}

    def test_multiple_labels_same_address(self):
        """Two labels on consecutive own-lines both point to the next instruction."""
        src = "START:\nBEGIN:\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        assert labels["START"] == 0
        assert labels["BEGIN"] == 0


# ---------------------------------------------------------------------------
# Full parse (Pass 2)
# ---------------------------------------------------------------------------

class TestParse:

    def test_basic_sequence(self):
        src = "ADDI R1, R0, 5\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert len(instrs) == 2
        assert instrs[0].name == "ADDI"
        assert instrs[0].operands == ["R1", "R0", "5"]
        assert instrs[0].pc == 0
        assert instrs[1].name == "HALT"
        assert instrs[1].pc == 1

    def test_case_insensitive_mnemonic(self):
        src = "addi r1, r0, 5\nhalt"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert instrs[0].name == "ADDI"
        assert instrs[1].name == "HALT"

    def test_comment_lines_skipped(self):
        src = "# comment\nADDI R1, R0, 5\n; another\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert len(instrs) == 2

    def test_blank_lines_skipped(self):
        src = "\n\nADDI R1, R0, 5\n\n\nHALT\n"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert len(instrs) == 2

    def test_label_instruction_on_same_line(self):
        src = "LOOP: BEQ R1, R2, 0\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert instrs[0].name == "BEQ"
        assert instrs[0].pc == 0

    def test_unknown_instruction_raises(self):
        src = "MUL R1, R2, R3\nHALT"
        p = Parser(src)
        with pytest.raises(AssemblerError, match="Unknown instruction"):
            p.collect_labels()

    def test_line_numbers_reported(self):
        """ParsedInstruction.line_no must reflect the actual source line."""
        src = "\n\nADDI R1, R0, 5\nHALT"
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        assert instrs[0].line_no == 3
        assert instrs[1].line_no == 4

    def test_all_11_mnemonics_accepted(self):
        src = (
            "LOAD R1, [0]\n"
            "STORE R1, [1]\n"
            "ADD R1, R1, R2\n"
            "SUB R1, R1, R2\n"
            "ADDI R1, R0, 1\n"
            "BEQ R0, R0, 0\n"
            "JUMP 0\n"
            "AND R1, R1, R2\n"
            "OR R1, R1, R2\n"
            "XOR R1, R1, R2\n"
            "HALT\n"
        )
        p = Parser(src)
        labels = p.collect_labels()
        instrs = p.parse(labels)
        names = [i.name for i in instrs]
        assert names == [
            "LOAD", "STORE", "ADD", "SUB", "ADDI",
            "BEQ", "JUMP", "AND", "OR", "XOR", "HALT",
        ]
