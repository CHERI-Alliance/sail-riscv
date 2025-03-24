/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// ----------------
// Check access permissions in PTE

// For (non-standard) extensions: this function gets the extension-available bits
// of the PTE in pte_ext_bits, and the accumulated information of the page-table-walk
// in ext_ptw. It should return the updated ext_ptw in both success and failure cases.

// This appears to be redundant but it is here so CHERI
// can override it without reimplementing pte_rwxu_permission_ok().
function pte_permission_ok(
  ac      : AccessType(ext_access_type),
  priv    : Privilege,
  mxr     : bool,
  do_sum  : bool,
  pte     : PTE_Flags,
  ext     : option(PTE_Ext), // None() for Sv32.
  ext_ptw : ext_ptw,
) -> (bool, ext_ptw) =
  (pte_rwxu_permission_ok(ac, priv, mxr, do_sum, pte), ext_ptw)

// Update a PTE's A/D bits and write it to memory. This returns
//
// * Ok(Some(pte)) if a write was needed and was successful. pte is the new value.
// * Ok(None()) if no write was needed.
// * Err(e) if a write was needed but there was an error.
//
function update_pte forall 'pte_width, 'pte_width in {4, 8} . (
  pte_width : int('pte_width),
  pteAddr   : physaddr,
  pte       : bits('pte_width * 8),
  ac        : AccessType(ext_access_type),
  ext_ptw   : ext_ptw,
) -> (result(option(bits('pte_width * 8)), PTW_Error), ext_ptw) =
  (match updated_pte_bits(pte, ac) {
    None() => Ok(None()),
    Some(pte) =>
      if not(plat_enable_dirty_update()) then {
        // PTE needs dirty/accessed update but that is not enabled.
        Err(PTW_PTE_Update())
      } else {
        // Writeback the PTE (which has new A/D bits).
        match write_pte(pteAddr, 'pte_width, pte) {
          Ok(_) => Ok(Some(pte)),
          Err(_) => Err(PTW_Access()),
        }
      },
  }, ext_ptw)
