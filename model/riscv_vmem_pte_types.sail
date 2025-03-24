/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// Number of flag bits.
type pte_flags_bits = bits(8)

// Flags.
bitfield PTE_Flags : pte_flags_bits = {
  D : 7,    // dirty
  A : 6,    // accessed
  G : 5,    // global
  U : 4,    // User
  X : 3,    // Execute permission
  W : 2,    // Write permission
  R : 1,    // Read permission
  V : 0     // Valid
}

// Number of ext bits. These are only available on RV64.
type pte_ext_bits = bits(10)

// Is a PTE is a pointer to next level (non-leaf).
function pte_is_ptr(pte_flags : PTE_Flags) -> bool =
    pte_flags[X] == 0b0
  & pte_flags[W] == 0b0
  & pte_flags[R] == 0b0

// Write a Page Table Entry.
function write_pte forall 'n, 'n in {4, 8} . (
  paddr    : physaddr,
  pte_size : int('n),
  pte      : bits('n * 8),
) -> MemoryOpResult(bool) =
  mem_write_value_priv(PMA, paddr, pte_size, pte, Supervisor, false, false, false)

// Read a Page Table Entry.
function read_pte forall 'n, 'n in {4, 8} . (
  paddr    : physaddr,
  pte_size : int('n),
) -> MemoryOpResult(bits(8 * 'n)) =
  mem_read_priv(Read(Data), Supervisor, PMA, paddr, pte_size, false, false, false)
