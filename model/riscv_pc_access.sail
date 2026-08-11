/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* accessors for default architectural addresses, for use from within instructions */

/*!
  Retrieves the architectural PC value. This is not necessarily the value
  found in the PC register as extensions may choose to override this function.
  The value in the PC register is the absolute virtual address of the instruction
  to fetch.
 */
val get_arch_pc : unit -> xlenbits
function get_arch_pc() = PC

val get_next_pc : unit -> xlenbits
function get_next_pc() = nextPC

val set_next_pc : xlenbits -> unit
function set_next_pc(pc) = {
  /* could check for internal errors here on invalid pc */
  let pc = convertInvalidAddr(pc);
  sail_branch_announce(xlen, pc);
  nextPC = pc;
}

val tick_pc : unit -> unit
function tick_pc() = {
  PCC = setCapAddrChecked(nextPCC, nextPC, false);
  PC = nextPC;
  pc_write_callback(PC);
}

// Note that although the Sail model ignores the address part of PCC (it uses
// PC instead), we require it to be correct when this function is called so
// that convertInvalidAddr() behaves correctly.
val set_next_pcc : Capability -> unit
function set_next_pcc(pcc) = {
  // This is technically redundant for CJALR since it already bounds checks
  // the reduced address and unseals the cap.
  nextPCC = convertInvalidAddr(pcc);
}

// For forcing PC from C. This is ugly.
function force_pc(pc : bits(64)) -> unit = {
  let addr = truncate(pc, xlen);
  PC = addr;
  PCC = setCapAddrChecked(PCC, addr, false);
}
