; branch_jump.asm – Vector Cores Phase II Sample Program
;
; Demonstrates: BEQ (forward + backward reference), JUMP, ADDI, HALT
;
; Program behaviour:
;   Count R1 from 0 up to 3, then stop.
;   Each iteration: check if R1 == R2 (limit=3); if equal, branch to DONE.
;   Otherwise increment R1 and jump back to LOOP.
;
; Expected final register state:
;   R1 = 3  (loop stopped when R1 reached the limit)
;   R2 = 3  (limit, unchanged)
;
; Instruction addresses and expected encodings:
;   Addr 0:  ADDI R1, R0, 0    → 5400   R1 = 0
;   Addr 1:  ADDI R2, R0, 3    → 5803   R2 = 3
;   Addr 2:  BEQ  R1, R2, DONE → 6602   offset = 5−(2+1) = +2 → branch to addr 5
;   Addr 3:  ADDI R1, R1, 1    → 5501   R1++
;   Addr 4:  JUMP LOOP         → 7002   absolute jump to addr 2
;   Addr 5:  HALT              → F000
;
; BEQ offset calculation (PC+1-relative, confirmed in top_module.v):
;   branch_target = (PC + 1) + offset[3:0]
;   For BEQ at addr 2 targeting DONE at addr 5:
;     offset = 5 − (2 + 1) = +2

        ADDI R1, R0, 0     ; Addr 0: R1 = 0 (counter)
        ADDI R2, R0, 3     ; Addr 1: R2 = 3 (loop limit)
LOOP:   BEQ  R1, R2, DONE  ; Addr 2: if R1 == R2, skip to DONE (forward ref)
        ADDI R1, R1, 1     ; Addr 3: R1++
        JUMP LOOP          ; Addr 4: go back to LOOP (backward ref)
DONE:   HALT               ; Addr 5: stop
