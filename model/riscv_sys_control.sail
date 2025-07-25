/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Machine-mode and supervisor-mode functionality. */

/* CSR access control */

function csrAccess(csr : csreg) -> csrRW = csr[11..10]
function csrPriv(csr : csreg) -> priv_level = csr[9..8]

// Check that the CSR access is made with sufficient privilege.
function check_CSR_priv(csr : csreg, p : Privilege) -> bool =
  privLevel_to_bits(p) >=_u csrPriv(csr)

// Check that the CSR access isn't a write and read-only.
function check_CSR_access(csr : csreg, isWrite : bool) -> bool =
  not(isWrite & (csrAccess(csr) == 0b11))

function check_TVM_SATP(csr : csreg, p : Privilege) -> bool =
  not(csr == 0x180 & p == Supervisor & mstatus[TVM] == 0b1)

// There are several features that are controlled by machine/supervisor enable
// bits (m/senvcfg, m/scounteren, etc.). This abstracts that logic.
function feature_enabled_for_priv(p : Privilege, machine_enable_bit : bit, supervisor_enable_bit : bit) -> bool = match p {
  Machine => true,
  Supervisor => machine_enable_bit == bitone,
  User => machine_enable_bit == bitone & (not(extensionEnabled(Ext_S)) | supervisor_enable_bit == bitone),
}

// Return true if the counter is enabled OR the CSR is not a counter.
function check_Counteren(csr : csreg, p : Privilege) -> bool = {
  // Check if it is not a counter.
  if not(csr >=_u 0xC00 & csr <=_u 0xC1F | csr >=_u 0xC80 & csr <=_u 0xC9F)
  then return true;

  // Check the relevant bit in m/scounteren.
  let index = unsigned(csr[4 .. 0]);
  feature_enabled_for_priv(p, mcounteren.bits[index], scounteren.bits[index])
}

// Return true if the stimecmp[h] CSR is accessible OR the CSR is not stimecmp[h].
function check_Stimecmp(csr : csreg, p : Privilege) -> bool = {
  // Check if it is not stimecmp.
  if csr != 0x14D & csr != 0x15D then return true;

  p == Machine | (p == Supervisor & mcounteren[TM] == 0b1 & menvcfg[STCE] == 0b1)
}

/* Seed may only be accessed if we are doing a write, and access has been
 * allowed in the current priv mode
 */
function check_seed_CSR (csr : csreg, p : Privilege, isWrite : bool) -> bool = {
  if not(csr == 0x015) then {
    true
  } else if not(isWrite) then {
    /* Read-only access to the seed CSR is not allowed */
    false
  } else {
    match (p) {
      Machine => true,
      Supervisor => mseccfg[SSEED] == 0b1,
      User => mseccfg[USEED] == 0b1,
    }
  }
}

function check_CSR(csr : csreg, p : Privilege, isWrite : bool) -> bool =
    is_CSR_defined(csr)
  & check_CSR_priv(csr, p)
  & check_CSR_access(csr, isWrite)
  // TODO: If we add `p` back to is_CSR_defined() we could move these three
  // check_ functions back there. We should also rename is_CSR_defined()
  // to is_CSR_accessible() or similar.
  & check_TVM_SATP(csr, p)
  & check_Counteren(csr, p)
  & check_Stimecmp(csr, p)
  & check_seed_CSR(csr, p, isWrite)

/* Reservation handling for LR/SC.
 *
 * The reservation state is maintained external to the model since the
 * reservation behavior is platform-specific anyway and maintaining
 * this state outside the model simplifies the concurrency analysis.
 *
 * These are externs are defined here in the system module since
 * we currently perform reservation cancellation on privilege level
 * transition.  Ideally, the platform should get more visibility into
 * where cancellation can be performed.
 */

val speculate_conditional = impure {interpreter: "excl_res", c: "speculate_conditional", lem: "speculate_conditional_success"} : unit -> bool

val load_reservation = impure {interpreter: "Platform.load_reservation", c: "load_reservation", lem: "load_reservation"} : physaddrbits -> unit
val match_reservation = pure {interpreter: "Platform.match_reservation", lem: "match_reservation", c: "match_reservation"} : physaddrbits -> bool
val cancel_reservation = impure {interpreter: "Platform.cancel_reservation", c: "cancel_reservation", lem: "cancel_reservation"} : unit -> unit

/* Exception delegation: given an exception and the privilege at which
 * it occured, returns the privilege at which it should be handled.
 */
function exception_delegatee(e : ExceptionType, p : Privilege) -> Privilege = {
  let idx   = num_of_ExceptionType(e);
  let super = bit_to_bool(medeleg.bits[idx]);
  let deleg = if extensionEnabled(Ext_S) & super then Supervisor else Machine;
  /* We cannot transition to a less-privileged mode. */
  if   privLevel_to_bits(deleg) <_u privLevel_to_bits(p)
  then p else deleg
}

/* Interrupts are prioritized in privilege order, and for each
 * privilege, in the order: external, software, timers.
 */
function findPendingInterrupt(ip : xlenbits) -> option(InterruptType) = {
  let ip = Mk_Minterrupts(ip);
  if      ip[MEI] == 0b1 then Some(I_M_External)
  else if ip[MSI] == 0b1 then Some(I_M_Software)
  else if ip[MTI] == 0b1 then Some(I_M_Timer)
  else if ip[SEI] == 0b1 then Some(I_S_External)
  else if ip[SSI] == 0b1 then Some(I_S_Software)
  else if ip[STI] == 0b1 then Some(I_S_Timer)
  else if ip[LCOFI] == 0b1 then Some(Local_Counter_Overflow)
  else                        None()
}

/* Given the current privilege level, return the pending set
 * of interrupts for the highest privilege that has any pending.
 *
 * We don't use the lowered views of {xie,xip} here, since the spec
 * allows for example the M_Timer to be delegated to the S-mode.
 */
function getPendingSet(priv : Privilege) -> option((xlenbits, Privilege)) = {
  // mideleg can only be non-zero if we support Supervisor mode.
  assert(extensionEnabled(Ext_S) | mideleg.bits == zeros());

  let pending_m = mip.bits & mie.bits & ~(mideleg.bits);
  let pending_s = mip.bits & mie.bits & mideleg.bits;

  let mIE = (priv == Machine    & mstatus[MIE] == 0b1) | priv == Supervisor | priv == User;
  let sIE = (priv == Supervisor & mstatus[SIE] == 0b1) | priv == User;

  if      mIE & (pending_m != zeros()) then Some((pending_m, Machine))
  else if sIE & (pending_s != zeros()) then Some((pending_s, Supervisor))
  else None()
}

/* Examine the current interrupt state and return an interrupt to be *
 * handled (if any), and the privilege it should be handled at.
 */
function dispatchInterrupt(priv : Privilege) -> option((exc_code, Privilege)) = {
  match getPendingSet(priv) {
    None()       => None(),
    Some(ip, p)  => match findPendingInterrupt(ip) {
                      None()  => None(),
                      Some(i) => Some((interruptType_to_bits(i), p)),
                    }
  }
}

/* types of privilege transitions */

union ctl_result = {
  CTL_TRAP : sync_exception,
  CTL_SRET : unit,
  CTL_MRET : unit,
}

/* trap value */

function tval(excinfo : option(xlenbits)) -> xlenbits = {
  match (excinfo) {
    Some(e) => e,
    None()  => zeros()
  }
}

$ifdef RVFI_DII
val rvfi_trap : unit -> unit
// TODO: record rvfi_trap_data
function rvfi_trap () =
  rvfi_inst_data[rvfi_trap] = 0x01
$else
val rvfi_trap : unit -> unit
function rvfi_trap () = ()
$endif

/* handle exceptional ctl flow by updating nextPC and operating privilege */

function trap_handler(del_priv : Privilege, intr : bool, c : exc_code, pc : xlenbits, info : option(xlenbits), ext : option(ext_exception))
                     -> xlenbits = {
  rvfi_trap();
  if   get_config_print_platform()
  then print_platform("handling " ^ (if intr then "int#" else "exc#")
                      ^ BitStr(c) ^ " at priv " ^ to_str(del_priv)
                      ^ " with tval " ^ BitStr(tval(info)));

  let newPc : xlenbits = match del_priv {
    Machine => {
      mcause[IsInterrupt] = bool_to_bits(intr);
      mcause[Cause]       = zero_extend(c);
      mstatus[MPIE] = mstatus[MIE];
      mstatus[MIE]  = 0b0;
      mstatus[MPP]  = privLevel_to_bits(cur_privilege());
      mtval         = tval(info);
      set_mepc(pc);

      set_cur_privilege(del_priv);

      prepare_trap_vector(del_priv, mcause)
    },
    Supervisor => {
      assert (extensionEnabled(Ext_S), "no supervisor mode present for delegation");

      scause[IsInterrupt] = bool_to_bits(intr);
      scause[Cause]       = zero_extend(c);

      mstatus[SPIE] = mstatus[SIE];
      mstatus[SIE]  = 0b0;
      mstatus[SPP]  = match cur_privilege() {
                        User => 0b0,
                        Supervisor => 0b1,
                        Machine => internal_error(__FILE__, __LINE__, "invalid privilege for s-mode trap")
                      };
      stval         = tval(info);
      set_sepc(pc);

      set_cur_privilege(del_priv);

      prepare_trap_vector(del_priv, scause)
    },
    User => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
  };

  handle_trap_extension(del_priv, pc, ext);

  newPc
}

function exception_handler(cur_priv : Privilege, ctl : ctl_result,
                           pc: xlenbits) -> xlenbits = {
  match (cur_priv, ctl) {
    (_, CTL_TRAP(e)) => {
      let del_priv = exception_delegatee(e.trap, cur_priv);
      if   get_config_print_platform()
      then print_platform("trapping from " ^ to_str(cur_priv) ^ " to " ^ to_str(del_priv)
                          ^ " to handle " ^ to_str(e.trap));
      trap_handler(del_priv, false, exceptionType_to_bits(e.trap), pc, e.excinfo, e.ext)
    },
    (_, CTL_MRET())  => {
      let prev_priv   = cur_privilege();
      mstatus[MIE]  = mstatus[MPIE];
      mstatus[MPIE] = 0b1;
      set_cur_privilege(privLevel_of_bits(mstatus[MPP]));
      mstatus[MPP]  = privLevel_to_bits(if extensionEnabled(Ext_U) then User else Machine);
      if   cur_privilege() != Machine
      then mstatus[MPRV] = 0b0;

      if   get_config_print_reg()
      then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));
      if   get_config_print_platform()
      then print_platform("ret-ing from " ^ to_str(prev_priv) ^ " to " ^ to_str(cur_privilege()));
      prepare_xret_target(Machine)
    },
    (_, CTL_SRET())  => {
      let prev_priv   = cur_privilege();
      mstatus[SIE]  = mstatus[SPIE];
      mstatus[SPIE] = 0b1;
      set_cur_privilege(if mstatus[SPP] == 0b1 then Supervisor else User);
      mstatus[SPP]  = 0b0;
      if   cur_privilege() != Machine
      then mstatus[MPRV] = 0b0;

      if   get_config_print_reg()
      then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));
      if   get_config_print_platform()
      then print_platform("ret-ing from " ^ to_str(prev_priv)
                          ^ " to " ^ to_str(cur_privilege()));

      prepare_xret_target(Supervisor)
    },
  }
}

// Non-Maskable Interrupt handler address.
val plat_nmi_handler = pure "plat_nmi_handler" : unit -> xlenbits

function nmi_handler() -> xlenbits = {
  set_mepc(PC);

  mcause[Cause] = zero_extend(nmi_cause);
  mcause[IsInterrupt] = 0b1;

  mstatus[MPIE] = mstatus[MIE];
  mstatus[MIE]  = 0b0;
  mstatus[MPP]  = privLevel_to_bits(cur_privilege());
  mtval           = tval(None());

  set_cur_privilege(Machine);

  // The address to jump to.
  let handler_address = plat_nmi_handler();

  handle_nmi_extension(PC, handler_address);

  handler_address
}

function handle_mem_exception(virtaddr(addr) : virtaddr, e : ExceptionType) -> unit = {
  let addr = convertInvalidAddr(addr);
  let t : sync_exception = struct { trap    = e,
                                    excinfo = Some(addr),
                                    ext     = None() } in
  set_next_pc(exception_handler(cur_privilege(), CTL_TRAP(t), PC))
}

// Handle a fault during address translation. For the base model this is identical
// to handle_mem_exception() but for CHERI it also sets mtval2 based on ext_ptw.
function handle_translate_exception(virtaddr(addr) : virtaddr, e : ExceptionType, ext_ptw : ext_ptw) -> unit = {
  let addr = convertInvalidAddr(addr);
  let t : sync_exception = struct { trap    = e,
                                    excinfo = Some(addr),
                                    ext     = Some(ext_ptw_exception_info(ext_ptw)) } in
  set_next_pc(exception_handler(cur_privilege(), CTL_TRAP(t), PC))
}

function handle_exception(e: ExceptionType) -> unit = {
  let t : sync_exception = struct { trap    = e,
                                    excinfo = None(),
                                    ext     = None() } in
  set_next_pc(exception_handler(cur_privilege(), CTL_TRAP(t), PC))
}

function handle_interrupt(i : exc_code, del_priv : Privilege) -> unit =
  set_next_pc(trap_handler(del_priv, true, i, PC, None(), None()))

function handle_nmi() -> unit = {
  set_next_pc(nmi_handler());
}


// Reset misa to enable the maximal set of supported extensions.
function reset_misa() -> unit = {
  misa[A]   = 0b1;                             /* atomics */
  misa[C]   = bool_to_bits(sys_enable_rvc());  /* RVC */
  misa[B]   = bool_to_bits(sys_enable_bext()); /* Bit-manipulation */
  misa[I]   = 0b1;                             /* base integer ISA */
  misa[M]   = 0b1;                             /* integer multiply/divide */
  misa[U]   = bool_to_bits(sys_enable_user()); /* user-mode */
  misa[S]   = bool_to_bits(sys_enable_supervisor()); /* supervisor-mode */
  misa[V]   = bool_to_bits(sys_enable_vext()); /* vector extension */
  misa[X]   = bool_to_bits(sys_misa_x());      /* non-standard extension */

  if   sys_enable_fdext() & sys_enable_zfinx()
  then internal_error(__FILE__, __LINE__, "F and Zfinx cannot both be enabled!");

  /* We currently support both F and D */
  misa[F]   = bool_to_bits(sys_enable_fdext());      /* single-precision */
  misa[D]   = if   flen >= 64
              then bool_to_bits(sys_enable_fdext())  /* double-precision */
              else 0b0;
}

// This function is called on reset, so it should only perform the reset actions
// described in the "Reset" section of the privileged architecture specification.
function reset_sys() -> unit = {
  // "Upon reset, a hart's privilege mode is set to M."
  set_cur_privilege(Machine);

  // "The mstatus fields MIE and MPRV are reset to 0."
  mstatus[MIE] = 0b0;
  mstatus[MPRV] = 0b0;

  // "If little-endian memory accesses are supported, the mstatus/mstatush field
  // MBE is reset to 0."
  // TODO: The handling of mstatush is a bit awkward currently, but the model
  // currently only supports little endian so MBE is always 0.
  // See https://github.com/riscv/sail-riscv/issues/639
  // mstatus[MBE] = 0b0;

  // "The misa register is reset to enable the maximal set of supported extensions"
  reset_misa();

  // "For implementations with the "A" standard extension, there is no valid load reservation."
  cancel_reservation();

  // "The pc is set to an implementation-defined reset vector."
  // This is outside the scope of this function.

  // "The mcause register is set to a value indicating the cause of the reset."
  // "The mcause values after reset have implementation-specific interpretation,
  // but the value 0 should be returned on implementations that do not
  // distinguish different reset conditions."
  mcause.bits = zeros();

  // "Writable PMP registers’ A and L fields are set to 0, unless the platform
  // mandates a different reset value for some PMP registers’ A and L fields."
  reset_pmp();

  // TODO: Probably need to remove these vector resets too but it needs
  // refactoring anyway. See https://github.com/riscv/sail-riscv/issues/566 etc.

  /* initialize vector csrs */
  vstart             = zeros();
  vl                 = zeros();
  vcsr[vxrm]       = 0b00;
  vcsr[vxsat]      = 0b0;
  vtype[vill]      = 0b1;
  vtype[reserved]  = zeros();
  vtype[vma]       = 0b0;
  vtype[vta]       = 0b0;
  vtype[vsew]      = 0b000;
  vtype[vlmul]     = 0b000;

  // log compatibility with spike
  if   get_config_print_reg()
  then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits) ^ " (input: " ^ BitStr(zeros() : xlenbits) ^ ")")
}

/* memory access exceptions, defined here for use by the platform model. */

type MemoryOpResult('a : Type) = result('a, ExceptionType)

val MemoryOpResult_add_meta : forall ('t : Type). (MemoryOpResult('t), mem_meta) -> MemoryOpResult(('t, mem_meta))
function MemoryOpResult_add_meta(r, m) = match r {
  Ok(v)  => Ok(v, m),
  Err(e) => Err(e)
}

val MemoryOpResult_drop_meta : forall ('t : Type). MemoryOpResult(('t, mem_meta)) -> MemoryOpResult('t)
function MemoryOpResult_drop_meta(r) = match r {
  Ok(v, m)  => Ok(v),
  Err(e) => Err(e)
}
