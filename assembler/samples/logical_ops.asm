; logical_ops.asm – Vector Cores Phase II Sample Program
;
; Demonstrates: AND, OR, XOR (new Phase II instructions)
;
; Hardware note:
;   These instructions use opcodes:
;     AND = 1000, OR = 1001, XOR = 1010
;   control_unit.v decodes these opcodes and drives the 3-bit alu_control
;   (AND = 010, OR = 011, XOR = 100); alu.v executes them. They run on the
;   processor and are verified by testbench/logical_ops_tb.v.
;
; Bitwise operation reference (R1=0x0C=12, R2=0x0A=10):
;   R1 in binary: 0000 1100
;   R2 in binary: 0000 1010
;   AND result  : 0000 1000 = 0x08 = 8
;   OR  result  : 0000 1110 = 0x0E = 14
;   XOR result  : 0000 0110 = 0x06 = 6
;
; Expected encodings:
;   Addr 0:  ADDI R1, R0, 12   → 540C
;   Addr 1:  ADDI R2, R0, 10   → 580A
;   Addr 2:  AND  R3, R1, R2   → 8D80  (opcode=1000, rd=11, rs=01, rt=10)
;   Addr 3:  OR   R3, R1, R2   → 9D80  (opcode=1001, rd=11, rs=01, rt=10)
;   Addr 4:  XOR  R3, R1, R2   → AD80  (opcode=1010, rd=11, rs=01, rt=10)
;   Addr 5:  HALT              → F000

ADDI R1, R0, 12    ; R1 = 12 = 0x0C = 0000 1100
ADDI R2, R0, 10    ; R2 = 10 = 0x0A = 0000 1010
AND  R3, R1, R2    ; R3 = R1 AND R2 = 0000 1000 = 8
OR   R3, R1, R2    ; R3 = R1 OR  R2 = 0000 1110 = 14
XOR  R3, R1, R2    ; R3 = R1 XOR R2 = 0000 0110 = 6
HALT
