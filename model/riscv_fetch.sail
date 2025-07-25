/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Current fetch hooks for RISC-V extensions call extensions
 * to check PC validity *before* standard fetch processing checks.
 */


function fetch() -> FetchResult =
  /* fetch PC check for extensions: extensions return a transformed PC to fetch,
   * but any exceptions use the untransformed PC.
   */
  match ext_fetch_check_pc(PC, PC) {
    Ext_FetchAddr_Error(e)     => F_Error(e, PC),
    Ext_FetchAddr_Ext_Error(e) => F_Ext_Error(e),
    Ext_FetchAddr_OK(use_pc)   => {
      let use_pc_bits = virtaddr_bits(use_pc);
      if   (use_pc_bits[0] != bitzero | (use_pc_bits[1] != bitzero & not(extensionEnabled(Ext_Zca))))
      then F_Error(E_Fetch_Addr_Align(), PC)
      else match translateAddr(use_pc, Execute()) {
        TR_Failure(e, _) => F_Error(e, PC),
        TR_Address(ppclo, pbmt, _) => {
          /* split instruction fetch into 16-bit granules to handle RVC, as
           * well as to generate precise fault addresses in any fetch
           * exceptions.
           */
          match ext_fetch_mem_read_lo(ppclo, pbmt) {
            Err(e)  => F_Error(e, PC),
            Ok(ilo) => {
              if   isRVC(ilo)
              then F_RVC(ilo)
              else {
                /* fetch PC check for the next instruction granule */
                let PC_hi = PC + 2;
                match ext_fetch_check_pc(PC, PC_hi) {
                  Ext_FetchAddr_Error(e)      => F_Error(e, PC_hi),
                  Ext_FetchAddr_Ext_Error(e)  => F_Ext_Error(e),
                  Ext_FetchAddr_OK(use_pc_hi) => {
                    match translateAddr(use_pc_hi, Execute()) {
                      TR_Failure(e, _) => F_Error(e, PC_hi),
                      TR_Address(ppchi, pbmt, _) => {
                        match ext_fetch_mem_read_hi(ppchi, pbmt) {
                          Err(e)  => F_Error(e, PC_hi),
                          Ok(ihi) => F_Base(append(ihi, ilo))
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
