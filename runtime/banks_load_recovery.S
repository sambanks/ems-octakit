/*
 * After a stock bank load that returned an error, apply the current bank
 * the way stock's own load loop applies a bank that parsed
 * (0x400907b8..0x400907ea: the SRAM working copy, the pattern request, the
 * engine part load) -- the loop skips that apply for a bank whose file
 * failed, so the engine's bank/part bytes (0x80001828/9) and the SRAM
 * working bank stay the previous project's while 0x80000002/3 name the
 * new one, and gk_ui_transition_prepare_entry_release returns CORRUPT at
 * its engine-bank compare on the first activation.
 *
 * Called from gk_stock_banks_load_work in place of its
 * `tst.l %d0 / bmi.s .Lgk_banks_load_return / move.l %d0,-(%sp)` (six
 * bytes, her layout kept), with %d0 = the stock result; returns with %d0
 * pushed the way that site left it, so the post step and the activation
 * run on the stock result in every case and the stock result is what the
 * caller sees.  The apply runs only when the engine's bytes disagree with
 * the current bank/part, i.e. when stock skipped it.
 *
 * The engine part load goes through her trampoline: her wrapper at the
 * stock entry accepts four stock callers in the quiesced state and this
 * is a fifth.  The pattern request wrapper replays stock when no queue
 * commit is prepared (none is during a load).
 */
        .include "abi.inc"
        /* Copies a resident bank into the SRAM working bank; stock's bank
           select (0x400622b2) and its load loop (0x400907c4) call it. */
        .set    GK_STOCK_BANK_WORKING_COPY_LOCAL,0x4000faf0
        .section .runtime.recovery,"ax"
        .align  4
        .global gk_banks_load_recover
        .type   gk_banks_load_recover,@function
gk_banks_load_recover:
        tst.l   %d0
        bpl.s   .Lgk_banks_load_recover_done
        lea     -56(%sp),%sp
        movem.l %d1-%d7/%a0-%a6,(%sp)
        move.l  %d0,%d2
        moveq   #0,%d3
        move.b  GK_STOCK_CURRENT_BANK_MIRROR,%d3
        moveq   #0,%d4
        move.b  GK_STOCK_CURRENT_PART_MIRROR,%d4
        moveq   #0,%d0
        move.b  GK_STOCK_ENGINE_BANK,%d0
        cmp.l   %d3,%d0
        bne.s   .Lgk_banks_load_recover_apply
        moveq   #0,%d0
        move.b  GK_STOCK_ENGINE_PART,%d0
        cmp.l   %d4,%d0
        beq.s   .Lgk_banks_load_recover_restore
.Lgk_banks_load_recover_apply:
        move.l  %d3,-(%sp)
        jsr     GK_STOCK_BANK_WORKING_COPY_LOCAL
        moveq   #0,%d0
        move.b  GK_STOCK_CURRENT_PATTERN,%d0
        move.l  %d0,-(%sp)
        move.l  %d3,-(%sp)
        jsr     GK_STOCK_PATTERN_SCHEDULE_REQUEST_ENTRY
        move.l  %d4,-(%sp)
        move.l  %d3,-(%sp)
        jsr     gk_stock_engine_part_load_trampoline
        lea     20(%sp),%sp
.Lgk_banks_load_recover_restore:
        move.l  %d2,%d0
        movem.l (%sp),%d1-%d7/%a0-%a6
        lea     56(%sp),%sp
.Lgk_banks_load_recover_done:
        move.l  (%sp)+,%a1
        move.l  %d0,-(%sp)
        jmp     (%a1)
        .size   gk_banks_load_recover,.-gk_banks_load_recover
