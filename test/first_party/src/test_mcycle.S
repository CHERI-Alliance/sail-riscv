// This test was written with AI assistance. Please see the commit log for details.

.global main
main:
    # Self-checking regression test for mcycle incrementing via tick_clock().
    mv t6, ra

    # Ensure mcycle is not inhibited and reset it to 0.
    csrci mcountinhibit, 1
#if __riscv_xlen == 32
    csrw mcycleh, zero
#endif
    csrw mcycle, zero

    # Run enough instructions to trigger multiple clock ticks.
    csrr t0, mcycle
    li t5, 64
1:
    addi t5, t5, -1
    bnez t5, 1b
    csrr t1, mcycle
    bleu t1, t0, fail

    # Inhibiting mcycle via mcountinhibit.CY must stop it from incrementing.
    csrsi mcountinhibit, 1
    csrr t2, mcycle
    li t5, 64
2:
    addi t5, t5, -1
    bnez t5, 2b
    csrr t3, mcycle
    bne t3, t2, fail

    # Re-enabling mcycle must resume incrementing.
    csrci mcountinhibit, 1
    li t5, 64
3:
    addi t5, t5, -1
    bnez t5, 3b
    csrr t4, mcycle
    bleu t4, t3, fail

#if __riscv_xlen == 32
    # Verify carry from mcycle into mcycleh on RV32.
    li t0, -1
    csrw mcycleh, zero
    csrw mcycle, t0
    li t5, 16
4:
    addi t5, t5, -1
    bnez t5, 4b
    csrr t1, mcycleh
    beqz t1, fail
#endif

pass:
    li a0, 0
    mv ra, t6
    ret
fail:
    li a0, 1
    mv ra, t6
    ret
