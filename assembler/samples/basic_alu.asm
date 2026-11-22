; basic_alu.asm – Vector Cores Phase II Sample Program
;
; Demonstrates: LOAD, STORE, ADD, SUB, ADDI, HALT
;
; Expected register state after execution:
;   R1 = 5    (8 − 3)
;   R2 = 3    (unchanged after subtraction)
;   R3 = 9    (loaded 8 from memory, then +1)
;
; Expected data memory state:
;   DMEM[2] = 8
;
; Expected hex output (must match existing program.hex exactly):
;   5405  ADDI R1, R0, 5
;   5803  ADDI R2, R0, 3
;   3580  ADD  R1, R1, R2
;   2480  STORE R1, [2]
;   4580  SUB  R1, R1, R2
;   1C80  LOAD R3, [2]
;   5F01  ADDI R3, R3, 1
;   F000  HALT
;   F000  (padding × 8)

ADDI R1, R0, 5     ; R1 = 0 + 5 = 5
ADDI R2, R0, 3     ; R2 = 0 + 3 = 3
ADD  R1, R1, R2    ; R1 = 5 + 3 = 8
STORE R1, [2]      ; DMEM[2] = 8
SUB  R1, R1, R2    ; R1 = 8 − 3 = 5
LOAD R3, [2]       ; R3 = DMEM[2] = 8
ADDI R3, R3, 1     ; R3 = 8 + 1 = 9
HALT
