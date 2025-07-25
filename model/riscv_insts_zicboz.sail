/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// Cache Block Operations - Zero

function clause extensionEnabled(Ext_Zicboz) = sys_enable_zicboz()

function cbo_zero_enabled(p : Privilege) -> bool = feature_enabled_for_priv(p, menvcfg[CBZE][0], senvcfg[CBZE][0])

/* ****************************************************************** */
union clause ast = RISCV_ZICBOZ : (regidx)

mapping clause encdec = RISCV_ZICBOZ(rs1)                            if extensionEnabled(Ext_Zicboz)
  <-> 0b000000000100 @ encdec_reg(rs1) @ 0b010 @ 0b00000 @ 0b0001111 if extensionEnabled(Ext_Zicboz)

mapping clause assembly = RISCV_ZICBOZ(rs1)
  <-> "cbo.zero" ^ spc() ^ "(" ^ opt_spc() ^ reg_name(rs1) ^ opt_spc() ^ ")"

function clause execute(RISCV_ZICBOZ(rs1)) = {
  if cbo_zero_enabled(cur_privilege()) then {
    let rs1_val = X(rs1);
    let cache_block_size_exp = plat_cache_block_size_exp();
    let cache_block_size = 2 ^ cache_block_size_exp;

    // Offset from rs1 to the beginning of the cache block. This is 0 if rs1
    // is aligned to the cache block, or negative if rs1 is misaligned.
    let negative_offset = (rs1_val & ~(zero_extend(ones(cache_block_size_exp)))) - rs1_val;

    match ext_data_get_addr(rs1, negative_offset, Cache(Zero), cache_block_size) {
      Ext_DataAddr_Error(e) => { ext_handle_data_check_error(e); RETIRE_FAIL },
      Ext_DataAddr_OK(vaddr) => {
        // "An implementation may update the bytes in any order and with any granularity
        //  and atomicity, including individual bytes."
        //
        // This implementation does a single atomic write.
        match translateAddr(vaddr, Write(Data)) {
          // vaddr is the aligned address, but errors report the address that
          // was encoded in the instruction. We subtract the negative offset
          // (add the positive offset) to get it. Normally this will be
          // equal to rs1, but pointer masking can change that.
          TR_Failure(e, ext_ptw) => { handle_translate_exception(vaddr - negative_offset, e, ext_ptw); RETIRE_FAIL },
          TR_Address(paddr, pbmt, _) => {
            match mem_write_ea(paddr, cache_block_size, false, false, false) {
              Err(e) => { handle_mem_exception(vaddr - negative_offset, e); RETIRE_FAIL },
              Ok(_)  => {
                let ep = effectivePrivilege(Cache(Zero), mstatus, cur_privilege());
                match mem_write_value_priv_meta(pbmt, paddr, cache_block_size, zeros(), Cache(Zero), ep, default_meta, false, false, false) {
                  Ok(true)  => RETIRE_SUCCESS,
                  Ok(false) => internal_error(__FILE__, __LINE__, "store got false from mem_write_value"),
                  Err(e)    => { handle_mem_exception(vaddr - negative_offset, e); RETIRE_FAIL },
                }
              }
            }
          }
        }
      },
    }
  } else {
    handle_illegal();
    RETIRE_FAIL
  }
}
