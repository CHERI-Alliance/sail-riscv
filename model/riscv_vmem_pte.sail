/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// ****************************************************************
// PTE (Page Table Entry) in PTN (Page Table Node)

// PTE            EXT       PPNs      RSW   FLAGS
// Sv32            -       31..10    9..8    7..0
// Sv39/48/57    63..54    53..10    9..8    7..0

// PRIVATE: extract ext bits of PTE above the PPN.
val ext_bits_of_PTE : forall 'pte_size, 'pte_size in {32, 64}. bits('pte_size) -> option(PTE_Ext)
function ext_bits_of_PTE(pte) =
  if 'pte_size == 64 then Some(Mk_PTE_Ext(pte[63 .. 54])) else None()

// PRIVATE: extract full PPN from a PTE
val PPN_of_PTE : forall 'pte_size, 'pte_size in {32, 64}.
  bits('pte_size) -> bits(if 'pte_size == 32 then 22 else 44)
function PPN_of_PTE(pte) = if 'pte_size == 32 then pte[31 .. 10] else pte[53 .. 10]

// PRIVATE: check if a PTE is valid
function pte_is_invalid(pte_flags : PTE_Flags, pte_ext : option(PTE_Ext)) -> bool =
    pte_flags[V] == 0b0
  | (pte_flags[W] == 0b1 & pte_flags[R] == 0b0)
  // If this is a non-leaf page, A/D/U bits are reserved
  | pte_flags[A] != zeros() & pte_is_ptr(pte_flags)
  | pte_flags[D] != zeros() & pte_is_ptr(pte_flags)
  | pte_flags[U] != zeros() & pte_is_ptr(pte_flags)
  | ((match pte_ext {
      Some(pte_ext) =>
        // These bits must be zero unless the relevant extension is supported
        // and this is a leaf node.
          pte_ext[N]    != zeros() & (not(extensionEnabled(Ext_Svnapot)) | pte_is_ptr(pte_flags))
        | pte_ext[PBMT] != zeros() & (not(extensionEnabled(Ext_Svpbmt))  | pte_is_ptr(pte_flags))
        // PBMT 0b11 is always reserved. This applies even without PBMT support.
        | pte_ext[PBMT] == 0b11
        // Reserved bits must be 0.
        | pte_ext[reserved] != zeros(),
      None() => false,
    }) : bool)
  | ext_pte_is_invalid(pte_flags, pte_ext)

// Return the updated the PTE with A/D set, if needed.
function updated_pte_bits forall 'pte_size, 'pte_size in {32, 64} . (
  pte : bits('pte_size),
  a   : AccessType(ext_access_type),
) -> option(bits('pte_size)) = {

  let is_write : bool = match a {
    Execute()       => false,
    Read(_)         => false,
    Write(_)        => true,
    ReadWrite(_, _) => true,
    Cache(Zero)     => true,
    // Clean, inval and flush don't require address translation
    // so we should never reach this point.
    Cache(_)        => internal_error(__FILE__, __LINE__,
                                      "Invalid CacheAccessType; Inval, Clean and Flush do not update PTE bits."),
  };

  let pte_flags = Mk_PTE_Flags(pte[7 .. 0]);

  let new_pte_flags = [
    pte_flags with
    // Accessed
    A = 0b1,
    // Dirty
    D = pte_flags[D] | bool_to_bits(is_write),
  ];

  let new_pte = [pte with 7 .. 0 = new_pte_flags.bits];

  if new_pte != pte then Some(new_pte) else None()
}

// Return true if the standard RWUX permissions are ok.
// False indicates a page fault should be raised.
function pte_rwxu_permission_ok(
  ac     : AccessType(ext_access_type),
  priv   : Privilege,
  mxr    : bool,
  do_sum : bool,
  pte    : PTE_Flags,
) -> bool =
  match (ac, priv) {
    (Read(_),      User)       => (pte[U] == 0b1)
                                  & ((pte[R] == 0b1)
                                     | ((pte[X] == 0b1 & mxr))),
    (Write(_),     User)       => (pte[U] == 0b1) & (pte[W] == 0b1),
    (ReadWrite(_), User)       => (pte[U] == 0b1)
                                  & (pte[W] == 0b1)
                                  & ((pte[R] == 0b1) | ((pte[X] == 0b1) & mxr)),
    (Execute(),    User)       => (pte[U] == 0b1) & (pte[X] == 0b1),
    (Cache(Zero),  User)       => (pte[U] == 0b1) & (pte[W] == 0b1),
    (Read(_),      Supervisor) => ((pte[U] == 0b0) | do_sum)
                                  & ((pte[R] == 0b1) | ((pte[X] == 0b1) & mxr)),
    (Write(_),     Supervisor) => ((pte[U] == 0b0) | do_sum)
                                  & (pte[W] == 0b1),
    (ReadWrite(_), Supervisor) => ((pte[U] == 0b0) | do_sum)
                                  & (pte[W] == 0b1)
                                  & ((pte[R] == 0b1)
                                     | ((pte[X] == 0b1) & mxr)),
    (Execute(),    Supervisor) => (pte[U] == 0b0) & (pte[X] == 0b1),
    (Cache(Zero),  Supervisor) => ((pte[U] == 0b0) | do_sum)
                                  & (pte[W] == 0b1),
    (_,            Machine)    => internal_error(__FILE__, __LINE__,
                                                 "m-mode mem perm check"),
    (Cache(_),     _) => internal_error(__FILE__, __LINE__,
                                        "Invalid CacheAccessType; Inval, Clean and Flush check Read/Write permissions."),
  }
