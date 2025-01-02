/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Functional specification for the 'Smclic' fast interrupts extension. */

// Return the mode for a privilege, taking nmbits into account.
function clicInterruptPrivMode(intr : range(0, 4095)) -> bits(2) = {
  let mode = clicintattr[intr][MODE];
  match mcliccfg[nmbits] {
    0b00 => 0b11, // Machine
    0b01 => [mode with 0=bitone], // Machine or Supervisor
    0b10 => mode,
    0b11 => mode, // Reserved
  }
}

// Return the interrupt level, taking into account nlbits.
function clicInterruptLevel(intr : range(0, 4095)) -> ilbits = {
  // The number of bits in clicintctl used for interrupt level is controlled
  // by cliccfg xnlbits.
  let nlbits : bits(4) = match privLevel_of_bits(clicInterruptPrivMode(intr)) {
    Machine    => mcliccfg[mnlbits],
    Supervisor => mcliccfg[snlbits],
    User       => mcliccfg[unlbits],
  };

  // If xnlbits < 8 then the lower bits of the 8-bit interrupt level
  // are are assumed to be all 1s.
  if nlbits <_u 0b1000 then {
    let nlbits_capped : range(0, 7) = unsigned(nlbits[2 .. 0]);
    [clicintctl[intr] with (7 - nlbits_capped) .. 0 = ones()]
  } else clicintctl[intr]
}

// Details about a CLIC interrupt.
struct ClicInterrupt = {
  vectored : bool,
  level : ilbits,
  privilege : Privilege,
  code : exc_code,
}

// PRIVATE: Return the highest priority pending interrupt. This function
// assumes that there is one, so don't call it directly (it is only called
// by clicPendingInterrupt()).
function clicHighestPriorityPendingInterrupt() -> ClicInterrupt = {
  var top_ip_code : exc_code = zeros();
  var top_ip_priv : bits(2) = zeros();
  var top_ip_ctl : ilbits = zeros();

  var found : bool = false;

  foreach (i from 0 to (4096 - 1)) {
    // Note we don't handle edge detection etc. That affects the value in
    // clicintip but we inject that directly from C++.
    if clicintip[i] == bitone & clicintie[i] == bitone then {
      found = true;

      let ip_priv  = clicInterruptPrivMode(i);
      let ip_ctl = clicintctl[i];

      if ip_priv @ ip_ctl >=_u top_ip_priv @ top_ip_ctl then {
        top_ip_code = to_bits(12, i);
        top_ip_priv = ip_priv;
        top_ip_ctl = ip_ctl;
      };
    };
  };

  assert(found);

  struct {
    code = top_ip_code,
    privilege = privLevel_of_bits(top_ip_priv),
    level = clicInterruptLevel(unsigned(top_ip_code)),
    // For convenience.
    vectored = clicintattr[unsigned(top_ip_code)][SHV] == 0b1,
  }
}

// Return the highest priority interrupt (or none if none).
// Interrupts are prioritised by their privilege and then their level.
// The privilege and level of the interrupt are also returned.
function clicPendingInterrupt() -> option(ClicInterrupt) = {
  // Fast path if there are no pending interrupts.
  if (clicintip & clicintie) == zeros() then {
    None()
  } else {
    Some(clicHighestPriorityPendingInterrupt())
  }
}

/* Given the current privilege level, iterate over privileges to get a
 * pending set for an enabled privilege.
 */
function dispatchClicInterrupt(priv : Privilege) -> option((exc_code, Privilege)) = {
  assert(extensionEnabled(Ext_U), "no user mode: M/U or M/S/U system required");

  match clicPendingInterrupt() {
    None() => None(),
    Some(intr) => {
      // Interrupts to level 0 are never taken, otherwise:
      //
      // * Interrupts to higher privileges are always taken.
      // * Interrupts to lower privileges are never taken.
      // * Interrupts to the current privilege are taken if mstatus[XIE] is set
      //   and the new interrupt level is greater than the current level.
      let priv_higher = num_of_Privilege(intr.privilege) > num_of_Privilege(priv);
      let priv_equal = num_of_Privilege(intr.privilege) == num_of_Privilege(priv);

      let enabled = intr.level != zeros() & (priv_higher | priv_equal & (match intr.privilege {
        Machine    => mstatus[MIE] == 0b1 & intr.level >_u max(mintthresh, mil),
        Supervisor => mstatus[SIE] == 0b1 & intr.level >_u max(sintthresh, sil),
        User       => internal_error(__FILE__, __LINE__, "N extension not supported"),
      }));

      if enabled then Some((intr.code, intr.privilege)) else None()
    },
  }
}

// Return the address in the CLIC vector table of the function pointer for
// the interrupt handler for `code`.
function clic_trap_table_entry_address(p : Privilege, code : exc_code) -> xlenbits = {
  let tbase : xlenbits = match p {
    Machine    => mtvt,
    Supervisor => stvt,
    User       => internal_error(__FILE__, __LINE__, "N extension not supported"),
  };

  tbase + unsigned(code) * xlen_bytes
}


val vector_table_fetch : (xlenbits) -> VectorTableFetchResult

// Return the address for a hardware vectored CLIC trap. Note this function
// is only called for interrupts that have hardware vectoring enabled.
function prepare_shv_clic_trap_vector(p : Privilege, code : exc_code) -> xlenbits = {
  let table_entry_addr = clic_trap_table_entry_address(p, code);

  match vector_table_fetch(table_entry_addr) {
    F_TableEntry(table_entry) => align_pc(table_entry),
    F_TableError(e, table_addr) => {
      inhv = 0b1;
      // TODO (CLIC): This is supposed to set xepc to `table_entry_addr`
      // and then handle the exception e, but you can't just call
      // handle_mem_exception here since we're already in the trap_handler
      // function.
      // handle_mem_exception(table_entry_addr, e);
      internal_error(__FILE__, __LINE__, "CLIC vector table fetch errors are not handled yet");
      table_entry_addr
    },
  }
}

// Return the address for a hardware vectored CLIC xret.
function prepare_clic_xret_vectored_target(p : Privilege) -> xlenbits = {
  // "The trap handler function address is obtained from the current privilege mode's
  // xepc with the low bits of the address cleared to force the access to be naturally
  // aligned to an XLEN/8-byte table entry."
  let table_entry_addr = get_xepc(p) & ~(zero_extend(ones(log2_xlen_bytes)));

  // TODO (CLIC): This code is identical to the code above. It should maybe just
  // be moved into `vector_table_fetch()`.
  match vector_table_fetch(table_entry_addr) {
    F_TableEntry(table_entry) => align_pc(table_entry),
    F_TableError(e, table_addr) => {
      inhv = 0b1;
      // TODO (CLIC): This is supposed to set xepc to `table_entry_addr`
      // and then handle the exception e, but you can't just call
      // handle_mem_exception here since we're already in the trap_handler
      // function.
      // handle_mem_exception(table_entry_addr, e);
      internal_error(__FILE__, __LINE__, "CLIC vector table fetch errors are not handled yet");
      table_entry_addr
    },
  }
}

function reset_clic() -> unit = {
  // These are the only registers that the spec requires to be reset.
  mil = zeros();
  sil = zeros();
}

function clicClearPendingIfEdgeTriggered(code : exc_code) -> unit = {
  let code = unsigned(code);
  if clicintattr[code][TRIG][0] == bitone then clicintip[code..code] = 0b0
}

// Read or write the `nxti` CSR. CLIC has very particular requirements
// for CSR access that don't conform to the normal expectations for CSRs.
//
// The read value returned by this function is a pointer to an entry in
// the trap handler table. The write updates the lowest 5 bits of mstatus
// (most of the xIE interrupt enable bits).
function access_xnxti(
  csr : csreg,
  rs1_val : xlenbits,
  op : csrop,
  is_imm : bool,
  isWrite : bool,
  priv : Privilege) -> xlenbits = {

  // ======== Write to mstatus ========

  // Update mstatus regardless of interrupt readiness.
  // Lowest 5 bits of mstatus are interrupt enables. There are actually 6,
  // but the instruction immediate is only 5 bits so we can't affect the 6th one.

  if isWrite then {
    let rs1_val_lower_5_bits = rs1_val[4 .. 0];
    let xstatus = get_xstatus(priv);

    let xstatus = [
      xstatus with 4 .. 0 = match op {
        CSRRS => xstatus[4 .. 0] | rs1_val_lower_5_bits,
        CSRRC => xstatus[4 .. 0] & ~(rs1_val_lower_5_bits),
        // This is actually reserved, but this is the logical behaviour.
        CSRRW => rs1_val_lower_5_bits,
      }
    ];

    set_xstatus(priv, xstatus);
  };

  // ======== Read next interrupt handler address ========

  // Return 0 if there is no suitable interrupt to service, or we're
  // not in CLIC mode. Otherwise a non-zero address of the entry in the
  // trap handler table for software trap vectoring.

  if inSmclicMode() then {
    // Value that CLIC level gets compared to changes based on whether the instruction
    // uses immediates.
    let xcause = get_xcause(priv);
    let min_pil = if is_imm then xcause[Xpil] else rs1_val[23..16];
    let min_thresh : ilbits = match priv {
      Machine => mintthresh,
      Supervisor => sintthresh,
      User => internal_error(__FILE__, __LINE__, "N extension not supported"),
    };

    match clicPendingInterrupt() {
      Some(intr) if intr.privilege == priv &
                    intr.level >_u min_pil &
                    intr.level >_u min_thresh &
                    not(intr.vectored) => {
        if isWrite then {
          match priv {
            Machine => {
              mil = intr.level;
              mcause[ClicExcCode] = intr.code;
              mcause[IsInterrupt] = 0b1;
            },
            Supervisor => {
              sil = intr.level;
              scause[ClicExcCode] = intr.code;
              scause[IsInterrupt] = 0b1;
            },
            User => internal_error(__FILE__, __LINE__, "N extension not supported"),
          };

          clicClearPendingIfEdgeTriggered(intr.code);
        };

        // Return pointer to trap handler.
        clic_trap_table_entry_address(priv, intr.code)
      },
      _ => {
        // Either no pending interrupt, or the interrupt that is pending
        // is for a different mode, too low level or has hardware vectoring
        // enabled.
        zeros()
      },
    }
  } else {
    // "In CLINT mode, reads of xnxti return 0, updates to xstatus proceed as
    // in CLIC mode, but updates to xintstatus and xcause do not take effect."
    zeros()
  }
}

/* Smclic CSRs */

// mtvt
function clause read_CSR(0x307, _) = mtvt

// mintstatus
function clause read_CSR(0xFB1, _) = get_xintstatus(Machine).bits

// mintthresh
function clause read_CSR(0x347, _) = zero_extend(mintthresh)

// mtvt
function clause write_CSR(0x307, value) = { mtvt = legalize_tvt(mtvt, value); mtvt }

// mintstatus; writes are ignored
function clause write_CSR(0xFB1, value) = get_xintstatus(Machine).bits

// mintthresh
function clause write_CSR(0x347, value) = { mintthresh = value[7..0]; zero_extend(mintthresh) }

/* Ssclic CSRs */

// stvt
function clause read_CSR(0x107, _) = stvt

// sintstatus
function clause read_CSR(0xDB1, _) = get_xintstatus(Supervisor).bits

// sintthresh
function clause read_CSR(0x147, _) = zero_extend(sintthresh)

// stvt
function clause write_CSR(0x107, value) = { stvt = legalize_tvt(stvt, value); stvt }

// mintstatus; writes are ignored
function clause write_CSR(0xDB1, value) = get_xintstatus(Supervisor).bits

// sintthresh
function clause write_CSR(0x147, value) = { sintthresh = value[7..0]; zero_extend(sintthresh) }

/* xscratchcsw[l] */

// Note the read functions are very weird and require access to the write value,
// which is why read_CSR has a write_val parameter that is only used here.

function clause read_CSR(0x348, write_val) = if not(currentPrivilegeMatchesPrevious()) then get_mscratch() else write_val // mscratchcsw
function clause read_CSR(0x349, write_val) = if (mcause[Xpil] == zeros()) != (mil == zeros()) then get_mscratch() else write_val // mscratchcswl
function clause read_CSR(0x148, write_val) = if not(currentPrivilegeMatchesPrevious()) then get_sscratch() else write_val // sscratchcsw
function clause read_CSR(0x149, write_val) = if (scause[Xpil] == zeros()) != (sil == zeros()) then get_sscratch() else write_val // sscratchcswl

// The return value from the write functions is not used except for logging
// so it doesn't really need to makes sense.

// mscratchcsw
function clause write_CSR(0x348, value) = {
  if not(currentPrivilegeMatchesPrevious()) then set_mscratch(value);
  value
}

// mscratchcswl
function clause write_CSR(0x349, value) = {
  if (mcause[Xpil] == zeros()) != (mil == zeros()) then set_mscratch(value);
  value
}

// sscratchcsw
function clause write_CSR(0x148, value) = {
  if not(currentPrivilegeMatchesPrevious()) then set_sscratch(value);
  value
}

// sscratchcswl
function clause write_CSR(0x149, value) = {
  // TODO (CLIC): Should this always use s[p]il, or should it use x[p]il based
  // on the current privilege mode.
  if (scause[Xpil] == zeros()) != (sil == zeros()) then set_sscratch(value);
  value
}
