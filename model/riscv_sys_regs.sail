/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Machine-mode and supervisor-mode state definitions. */

/* privilege level */

register debug_mode_active : bool = false

// The underlying privilege if we were not in debug mode.
register true_cur_privilege : Privilege

// The effective privilege taking debug mode into account, which executes
// with machine mode privileges.
function cur_privilege() -> Privilege =
  if debug_mode_active then Machine else true_cur_privilege

function set_cur_privilege(v : Privilege) -> unit = {
  true_cur_privilege = v;
}

/* current instruction bits, used for illegal instruction exceptions */

register cur_inst : xlenbits

/* State projections
 *
 * Some machine state is processed via projections from machine-mode views to
 * views from lower privilege levels.  So, for e.g. when mstatus is read from
 * lower privilege levels, we use 'lowering_' projections:
 *
 *   mstatus  ->  sstatus  ->  ustatus
 *
 * Similarly, when machine state is written from lower privileges, that state is
 * lifted into the appropriate value for the machine-mode state.
 *
 *   ustatus  ->  sstatus  ->  mstatus
 *
 * In addition, several fields in machine state registers are WARL or WLRL,
 * requiring that values written to the registers be legalized.  For each such
 * register, there will be an associated 'legalize_' function.  These functions
 * will need to be supplied externally, and will depend on the legal values
 * supported by a platform/implementation (or misa).  The legalize_ functions
 * generate a legal value from the current value and the written value.  In more
 * complex cases, they will also implicitly read the current values of misa,
 * mstatus, etc.
 *
 * Each register definition below is followed by custom projections
 * and choice of legalizations if needed.  For now, we typically
 * implement the simplest legalize_ alternatives.
 */


/* M-mode registers */

bitfield Misa : xlenbits = {
  MXL  : xlen - 1 .. xlen - 2,

  Z    : 25,
  Y    : 24,
  X    : 23,
  W    : 22,
  V    : 21,
  U    : 20,
  T    : 19,
  S    : 18,
  R    : 17,
  Q    : 16,
  P    : 15,
  O    : 14,
  N    : 13,
  M    : 12,
  L    : 11,
  K    : 10,
  J    : 9,
  I    : 8,
  H    : 7,
  G    : 6,
  F    : 5,
  E    : 4,
  D    : 3,
  C    : 2,
  B    : 1,
  A    : 0
}
register misa : Misa =
  [ Mk_Misa(zeros()) with
    // MXL is a read-only field that specifies the native XLEN.
    MXL = architecture(if xlen == 32 then RV32 else RV64),
  ]

/* whether misa is R/W */
val sys_enable_writable_misa = pure "sys_enable_writable_misa" : unit -> bool
/* whether misa.c was enabled at boot */
val sys_enable_rvc = pure "sys_enable_rvc" : unit -> bool
/* whether misa.{f,d} were enabled at boot */
val sys_enable_fdext = pure "sys_enable_fdext" : unit -> bool
/* whether Svinval was enabled at boot */
val sys_enable_svinval = pure "sys_enable_svinval" : unit -> bool
/* whether Zcb was enabled at boot */
val sys_enable_zcb = pure "sys_enable_zcb" : unit -> bool
/* whether zfinx was enabled at boot */
val sys_enable_zfinx = pure "sys_enable_zfinx" : unit -> bool
/* whether Zfh/Zfhmin was enabled at boot */
val sys_enable_zfh = pure "sys_enable_zfh" : unit -> bool
val sys_enable_zfhmin = pure "sys_enable_zfhmin" : unit -> bool
/* whether Zvfh/Zvfhmin was enabled at boot */
val sys_enable_zvfh = pure "sys_enable_zvfh" : unit -> bool
val sys_enable_zvfhmin = pure "sys_enable_zvfhmin" : unit -> bool
/* whether Zba was enabled at boot */
val sys_enable_zba = pure "sys_enable_zba" : unit -> bool
/* whether Zbb was enabled at boot */
val sys_enable_zbb = pure "sys_enable_zbb" : unit -> bool
/* whether Zbc was enabled at boot */
val sys_enable_zbc = pure "sys_enable_zbc" : unit -> bool
/* whether Zbs was enabled at boot */
val sys_enable_zbs = pure "sys_enable_zbs" : unit -> bool
/* whether Crypto extensions were enabled at boot */
val sys_enable_zbkb = pure "sys_enable_zbkb" : unit -> bool
val sys_enable_zbkc = pure "sys_enable_zbkc" : unit -> bool
val sys_enable_zbkx = pure "sys_enable_zbkx" : unit -> bool
val sys_enable_zknd = pure "sys_enable_zknd" : unit -> bool
val sys_enable_zkne = pure "sys_enable_zkne" : unit -> bool
val sys_enable_zknh = pure "sys_enable_zknh" : unit -> bool
val sys_enable_zksed = pure "sys_enable_zksed" : unit -> bool
val sys_enable_zksh = pure "sys_enable_zksh" : unit -> bool
/* whether misa.X should be set to indicate non-standard extensions */
val sys_misa_x = pure "sys_misa_x" : unit -> bool

// Force the set bits of mcountinhibit to 1
val sys_force_countinhibit_bits = pure "sys_force_countinhibit_bits" : unit -> bits(32)

val sys_medeleg_writable_bits = pure "sys_medeleg_writable_bits" : unit -> bits(64)
val sys_mideleg_writable_bits = pure "sys_mideleg_writable_bits" : unit -> bits(64)
val sys_xtvec_writable_bits = pure "sys_xtvec_writable_bits" : unit -> bits(64)

val sys_xcause_bits = pure "sys_xcause_bits" : unit -> range(0, 64)

/* How many PMP entries are implemented. This must be 0, 16 or 64 (this is checked at runtime). */
val sys_pmp_count = pure "sys_pmp_count" : unit -> range(0, 64)
/* Which PMP entries are writable. This is a bitmask. 1 means writable, 0 means read-only zero. */
val sys_pmp_writable = pure "sys_pmp_writable" : unit -> bits(64)
/* G parameter that specifies the PMP grain size. The grain size is 2^(G+2), e.g.
   G=0 -> 4 bytes, G=10 -> 4096 bytes. */
val sys_pmp_grain = pure "sys_pmp_grain" : unit -> range(0, 63)

/* Which HPM counters are supported (as a bit mask). Bits [2 .. 0] are ignored. */
val sys_writable_hpm_counters = pure "sys_writable_hpm_counters" : unit -> bits(32)

// Physical address size. This must be at least 12 so you can address one page.
// The minimum of 13 is due to https://github.com/rems-project/sail/issues/471
val sys_pa_bits = pure "sys_pa_bits" : unit -> range(13, if xlen == 32 then 34 else 56)

// Address Space ID size (max 16 bits). Currently this must be at least 1 due to
// https://github.com/rems-project/sail/issues/471
val sys_asid_bits = pure "sys_asid_bits" : unit -> range(1, if xlen == 32 then 9 else 16)

/* Which virtual addressing modes are supported. Note Sv57 is not implemented yet. */
val sys_enable_sv32 = pure "sys_enable_sv32" : unit -> bool
val sys_enable_sv39 = pure "sys_enable_sv39" : unit -> bool
val sys_enable_sv48 = pure "sys_enable_sv48" : unit -> bool
val sys_enable_sv57 = pure "sys_enable_sv57" : unit -> bool

val sys_enable_tlb = pure "sys_enable_tlb" : unit -> bool

val sys_enable_svnapot = pure "sys_enable_svnapot" : unit -> bool

/* whether misa.v was enabled at boot */
val sys_enable_vext = pure "sys_enable_vext" : unit -> bool

/* whether misa.b was enabled at boot */
val sys_enable_bext = pure "sys_enable_bext" : unit -> bool

// CBO extensions. Zicbop cannot be enabled/disabled because it has no effect
// at all on this model.
val sys_enable_zicbom = pure "sys_enable_zicbom" : unit -> bool
val sys_enable_zicboz = pure "sys_enable_zicboz" : unit -> bool

// maskmax6 value for Sdtrig
val sys_maskmax6 = pure "sys_maskmax6" : unit -> range(0, 63)

function legalize_misa(m : Misa, v : xlenbits) -> Misa = {
  let  v = Mk_Misa(v);
  /* Suppress updates to MISA if MISA is not writable or if by disabling C next PC would become misaligned or an extension vetoes */
  if   not(sys_enable_writable_misa()) | (v[C] == 0b0 & (nextPC[1] == bitone))
  then m
  else {
    // Suppress enabling C if it is not supported.
    let m = if not(sys_enable_rvc()) then m else [m with C = v[C]];
    /* Suppress updates to misa.{f,d} if disabled at boot */
    if   not(sys_enable_fdext())
    then m
    else [m with F = v[F], D = v[D] & v[F]]
  }
}

mapping clause csr_name_map = 0x301  <-> "misa"
function clause is_CSR_defined(0x301) = true // misa
function clause read_CSR(0x301, _) = misa.bits
function clause write_CSR(0x301, value) = { misa = legalize_misa(misa, value); misa.bits }

// Are user and supervisor mode supported by the hardware?
// TODO: Don't hard-code these.
function sys_enable_user() -> bool = true
function sys_enable_supervisor() -> bool = true

// Are supervisor/user mode currently enabled? Although
// unlikely and not currently supported by the model,
// you are technically allowed to have writable misa[U/S].
function clause extensionEnabled(Ext_U) = misa[U] == 0b1
function clause extensionEnabled(Ext_S) = misa[S] == 0b1
// Note the model doesn't support hypervisor mode yet.
function clause extensionEnabled(Ext_H) = misa[H] == 0b1

// Svnapot depends on Sv39.
function clause extensionEnabled(Ext_Svnapot) = sys_enable_svnapot() & sys_enable_sv39()

/*
 * Illegal values legalized to least privileged mode supported.
 * Note: the only valid combinations of supported modes are M, M+U, M+S+U.
 */
function lowest_supported_privLevel() -> Privilege =
  if extensionEnabled(Ext_U) then User else Machine

function have_privLevel(priv : priv_level) -> bool =
  match priv {
    0b00 => extensionEnabled(Ext_U),
    0b01 => extensionEnabled(Ext_S),
    0b10 => false,
    0b11 => true,
  }

register mstatus : Mstatus = {
  // Initialise SXL and UXL.
  let mxl = architecture(if xlen == 32 then RV32 else RV64);
  [ Mk_Mstatus(zeros()) with
    // These fields do not exist on RV32 and are read-only zero
    // if the corresponding mode is not supported.
    SXL = if xlen != 32 & sys_enable_supervisor() then mxl else zeros(),
    UXL = if xlen != 32 & sys_enable_user() then mxl else zeros(),
  ]
}


function effectivePrivilege(t : AccessType(ext_access_type), m : Mstatus, priv : Privilege) -> Privilege =
  if   t != Execute() & m[MPRV] == 0b1
  then privLevel_of_bits(m[MPP])
  else priv

function get_mstatus_SXL(m : Mstatus) -> arch_xlen = {
  if   xlen == 32
  then architecture(RV32)
  else m[SXL]
}

function get_mstatus_UXL(m : Mstatus) -> arch_xlen = {
  if   xlen == 32
  then architecture(RV32)
  else m[UXL]
}

// "xPP fields are WARL fields that can hold only privilege mode x and any
// implemented privilege mode lower than x."
// The specific WARL implementation here is to set illegal values to the lowest
// supported mode.
function legalize_mpp(mpp : bits(2)) -> bits(2) =
  if have_privLevel(mpp) then mpp else privLevel_to_bits(lowest_supported_privLevel())

// "If privilege mode x is not implemented, then xPP must be read-only 0."
function legalize_spp(spp : bits(1)) -> bits(1) =
  if extensionEnabled(Ext_S) then spp else 0b0

function legalize_mstatus(o : Mstatus, v : bits(64)) -> Mstatus = {
  /*
   * Populate all defined fields using the bits of v, stripping anything
   * that does not have a matching bitfield entry. The SD bits are handled
   * explicitly later depending on xlen.
   */
  let v = Mk_Mstatus(v);

  let o = [o with
    // MDT = v[MDT],
    // MPELP = v[MPELP],
    // MPV = v[MPV],
    // GVA = v[GVA],
    /* We don't currently support changing MBE and SBE. */
    // MBE = v[MBE],
    // SBE = v[SBE],
    /* We don't support dynamic changes to SXL and UXL. */
    // SXL = if xlen == 64 then v[SXL] else o[SXL],
    // UXL = if xlen == 64 then v[UXL] else o[UXL],
    // SDT = v[SDT],
    // SPELP = v[SPELP],
    TSR = v[TSR],
    TW = v[TW],
    TVM = v[TVM],
    MXR = v[MXR],
    SUM = v[SUM],
    MPRV = if extensionEnabled(Ext_U) then v[MPRV] else 0b0,
    /* We don't have any extension context yet. */
    XS = extStatus_to_bits(Off),
  /* FS is WARL, and making FS writable can support the M-mode emulation of an FPU
   * to support code running in S/U-modes.  Spike does this, and for now, we match it,
   * but only if Zfinx isn't enabled.
   * FIXME: This should be made a platform parameter.
   */
    FS = if sys_enable_zfinx() then extStatus_to_bits(Off) else v[FS],
    MPP = legalize_mpp(v[MPP]),
    SPP = legalize_spp(v[SPP]),
    VS = v[VS],
    MPIE = v[MPIE],
    SPIE = v[SPIE],
    MIE = v[MIE],
    SIE = v[SIE],
  ];

  // Set dirty bit to OR of other status bits.
  let dirty = extStatus_of_bits(o[FS]) == Dirty |
              extStatus_of_bits(o[XS]) == Dirty |
              extStatus_of_bits(o[VS]) == Dirty;

  let o = [o with SD = bool_to_bits(dirty)];

  ext_legalize_mstatus(o, v)
}

mapping clause csr_name_map = 0x300  <-> "mstatus"

function clause is_CSR_defined(0x300) = true // mstatus
function clause is_CSR_defined(0x310) = xlen == 32 // mstatush

function clause read_CSR(0x300, _) = mstatus.bits[xlen - 1 .. 0]
function clause read_CSR((0x310, _) if xlen == 32) = mstatus.bits[63 .. 32]

function clause write_CSR((0x300, value) if xlen == 64) = { mstatus = legalize_mstatus(mstatus, value); mstatus.bits }
function clause write_CSR((0x300, value) if xlen == 32) = { mstatus = legalize_mstatus(mstatus, mstatus.bits[63 .. 32] @ value); mstatus.bits[31 .. 0] }
function clause write_CSR((0x310, value) if xlen == 32) = { mstatus = legalize_mstatus(mstatus, value @ mstatus.bits[31 .. 0]); mstatus.bits[63 .. 32] }

/* architecture and extension checks */

function cur_architecture() -> Architecture = {
  let a : arch_xlen =
    match cur_privilege() {
      Machine    => misa[MXL],
      Supervisor => get_mstatus_SXL(mstatus),
      User       => get_mstatus_UXL(mstatus)
    };
  architecture(a)
}

function in32BitMode() -> bool = {
  cur_architecture() == RV32
}

/* mseccfg */
register mseccfg : Seccfg = legalize_mseccfg(Mk_Seccfg(zeros()), zeros())

mapping clause csr_name_map = 0x747  <-> "mseccfg"
mapping clause csr_name_map = 0x757  <-> "mseccfgh"

function clause is_CSR_defined(0x747) = true // mseccfg
function clause is_CSR_defined(0x757) = xlen == 32 // mseccfgh

function clause read_CSR(0x747, _) = mseccfg.bits[xlen - 1 .. 0]
function clause read_CSR((0x757, _) if xlen == 32) = mseccfg.bits[63 .. 32]

val set_mseccfg : (bits(64)) -> unit

function clause write_CSR((0x747, value) if xlen == 32) = { set_mseccfg(mseccfg.bits[63 .. 32] @ value); mseccfg.bits[31 .. 0] }
function clause write_CSR((0x747, value) if xlen == 64) = { set_mseccfg(value); mseccfg.bits }
function clause write_CSR((0x757, value) if xlen == 32) = { set_mseccfg(value @ mseccfg.bits[31 .. 0]); mseccfg.bits[63 .. 32] }

// Initialised to legal values in case some bits are hard-coded to 1.
register menvcfg : MEnvcfg = legalize_menvcfg(Mk_MEnvcfg(zeros()), mseccfg, zeros())
register senvcfg : SEnvcfg = legalize_senvcfg(Mk_SEnvcfg(zeros()), menvcfg, zeros())

mapping clause csr_name_map = 0x30A  <-> "menvcfg"
mapping clause csr_name_map = 0x31A  <-> "menvcfgh"
mapping clause csr_name_map = 0x10A  <-> "senvcfg"

function clause is_CSR_defined(0x30A) = extensionEnabled(Ext_U) // menvcfg
function clause is_CSR_defined(0x31A) = extensionEnabled(Ext_U) & (xlen == 32) // menvcfgh
function clause is_CSR_defined(0x10A) = extensionEnabled(Ext_S) // senvcfg

function clause read_CSR(0x30A, _) = menvcfg.bits[xlen - 1 .. 0]
function clause read_CSR((0x31A, _) if xlen == 32) = menvcfg.bits[63 .. 32]
function clause read_CSR(0x10A, _) = senvcfg.bits[xlen - 1 .. 0]

val set_menvcfg : (bits(64)) -> unit
val set_senvcfg : (xlenbits) -> unit

function clause write_CSR((0x30A, value) if xlen == 32) = { set_menvcfg(menvcfg.bits[63 .. 32] @ value); menvcfg.bits[31 .. 0] }
function clause write_CSR((0x30A, value) if xlen == 64) = { set_menvcfg(value); menvcfg.bits }
function clause write_CSR((0x31A, value) if xlen == 32) = { set_menvcfg(value @ menvcfg.bits[31 .. 0]); menvcfg.bits[63 .. 32] }
function clause write_CSR(0x10A, value) = { set_senvcfg(value); senvcfg.bits }

// Return whether or not FIOM is currently active, based on the current
// privilege and the menvcfg/senvcfg settings. This means that I/O fences
// imply memory fence.
function is_fiom_active() -> bool = {
  match cur_privilege() {
    Machine => false,
    Supervisor => menvcfg[FIOM] == 0b1,
    User => (menvcfg[FIOM] | senvcfg[FIOM]) == 0b1,
  }
}

/* interrupt processing state */

bitfield Minterrupts : xlenbits = {
  // Local Counter OverFlow Interrupt
  LCOFI : 13,

  // Machine/Supervisor External Interrupt
  MEI : 11,
  SEI : 9,

  // Machine/Supervisor Timer Interrupt
  MTI : 7,
  STI : 5,

  // Machine/Supervisor Software Interrupt
  MSI : 3,
  SSI : 1,
}

// Non Maskable Interrupt. If this is set an NMI is taken.
register nmi_taken : bool
// When an NMI is taken this is copied to `mcause`.
register nmi_cause : exc_code
// NMI is pending. Sets dcsr.nmip
register nmi_pending : bool

val sys_writable_stip = pure "sys_writable_stip" : unit -> bool

function legalize_mip(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  // MEI, MTI and MSI are read-only in mip.
  let v = Mk_Minterrupts(v);
  [o with
    SEI = if extensionEnabled(Ext_S) then v[SEI] else 0b0,
    STI = if extensionEnabled(Ext_S) then (
      if not(sys_writable_stip()) | extensionEnabled(Ext_Sstc) & menvcfg[STCE] == 0b1 then o[STI] else v[STI]
    ) else 0b0,
    SSI = if extensionEnabled(Ext_S) then v[SSI] else 0b0,
    LCOFI = if extensionEnabled(Ext_Sscofpmf) then v[LCOFI] else 0b0,
  ]
}

function legalize_mie(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  let v = Mk_Minterrupts(v);
  [o with
    MEI = v[MEI],
    MTI = v[MTI],
    MSI = v[MSI],
    SEI = if extensionEnabled(Ext_S) then v[SEI] else 0b0,
    STI = if extensionEnabled(Ext_S) then v[STI] else 0b0,
    SSI = if extensionEnabled(Ext_S) then v[SSI] else 0b0,
    LCOFI = if extensionEnabled(Ext_Sscofpmf) then v[LCOFI] else 0b0,
  ]
}

function legalize_mideleg(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  Mk_Minterrupts(v & sys_mideleg_writable_bits()[xlen - 1 .. 0])
}

/* exception processing state */

bitfield Medeleg : bits(64) = {
  SAMO_Page_Fault   : 15,
  Load_Page_Fault   : 13,
  Fetch_Page_Fault  : 12,
  MEnvCall          : 11,
  SEnvCall          : 9,
  UEnvCall          : 8,
  SAMO_Access_Fault : 7,
  SAMO_Addr_Align   : 6,
  Load_Access_Fault : 5,
  Load_Addr_Align   : 4,
  Breakpoint        : 3,
  Illegal_Instr     : 2,
  Fetch_Access_Fault: 1,
  Fetch_Addr_Align  : 0
}

function legalize_medeleg(o : Medeleg, v : bits(64)) -> Medeleg = {
  let m = Mk_Medeleg(v & sys_medeleg_writable_bits());

  /* M-EnvCalls delegation is not supported */
  [m with MEnvCall = 0b0]
}

register mie     : Minterrupts /* Enabled */
register mip     : Minterrupts /* Pending */
register medeleg : Medeleg     /* Exception delegation to S-mode */
register mideleg : Minterrupts /* Interrupt delegation to S-mode */

mapping clause csr_name_map = 0x304  <-> "mie"
mapping clause csr_name_map = 0x344  <-> "mip"
mapping clause csr_name_map = 0x302  <-> "medeleg"
mapping clause csr_name_map = 0x312  <-> "medelegh"
mapping clause csr_name_map = 0x303  <-> "mideleg"

function clause is_CSR_defined(0x304) = true // mie
function clause is_CSR_defined(0x344) = true // mip
function clause is_CSR_defined(0x302) = extensionEnabled(Ext_S) // medeleg
function clause is_CSR_defined(0x312) = extensionEnabled(Ext_S) & xlen == 32 // medelegh
function clause is_CSR_defined(0x303) = extensionEnabled(Ext_S) // mideleg

function clause read_CSR(0x304, _) = mie.bits
function clause read_CSR(0x344, _) = mip.bits
function clause read_CSR(0x302, _) = medeleg.bits[xlen - 1 .. 0]
function clause read_CSR((0x312, _) if xlen == 32) = medeleg.bits[63 .. 32]
function clause read_CSR(0x303, _) = mideleg.bits

function clause write_CSR(0x304, value) = { mie = legalize_mie(mie, value); mie.bits }
function clause write_CSR(0x344, value) = { mip = legalize_mip(mip, value); mip.bits }
function clause write_CSR((0x302, value) if xlen == 64) = { medeleg = legalize_medeleg(medeleg, value); medeleg.bits }
function clause write_CSR((0x302, value) if xlen == 32) = { medeleg = legalize_medeleg(medeleg, medeleg.bits[63 .. 32] @ value); medeleg.bits[31 .. 0] }
function clause write_CSR((0x312, value) if xlen == 32) = { medeleg = legalize_medeleg(medeleg, value @ medeleg.bits[31 .. 0]); medeleg.bits[63 .. 32] }
function clause write_CSR(0x303, value) = { mideleg = legalize_mideleg(mideleg, value); mideleg.bits }

/* registers for trap handling */

bitfield Mtvec : xlenbits = {
  Base : xlen - 1 .. 2,
  Mode : 1 .. 0
}
register mtvec : Mtvec  /* Trap Vector */

function legalize_tvec(o : Mtvec, v : xlenbits) -> Mtvec = {
 let v = Mk_Mtvec(v);
 match trapVectorMode_bits(v[Mode]) {
   TV_Direct => v,
   TV_Vector => v,
   _         => [v with Mode = o[Mode]]
 }
}

bitfield Mcause : xlenbits = {
  IsInterrupt : xlen - 1,
  Cause       : xlen - 2 .. 0,
}
register mcause : Mcause
register scause : Mcause

function legalize_cause(v : xlenbits) -> Mcause = {
  let cause_bits = sys_xcause_bits();
  assert(cause_bits <= xlen - 1);

  let m = Mk_Mcause(v);
  [m with Cause = if cause_bits == 0 then zeros()
                  else zero_extend(m[Cause][cause_bits - 1 .. 0])]
}

function get_xcause(priv : Privilege) -> Mcause =
  match priv {
    Machine => mcause,
    Supervisor => scause,
    User => internal_error(__FILE__, __LINE__, "N extension not supported"),
  }

function set_xcause(priv : Privilege, value : xlenbits) -> unit = {
  let cause = legalize_cause(value);
  match priv {
    Machine => mcause = cause,
    Supervisor => scause = cause,
    User => internal_error(__FILE__, __LINE__, "N extension not supported"),
  }
}

mapping clause csr_name_map = 0x342  <-> "mcause"
function clause is_CSR_defined(0x342) = true // mcause
function clause read_CSR(0x342, _) = get_xcause(Machine).bits
function clause write_CSR(0x342, value) = { set_xcause(Machine, value); get_xcause(Machine).bits }

/* Interpreting the trap-vector address */
function tvec_addr(m : Mtvec, c : Mcause) -> option(xlenbits) = {
  let base : xlenbits = m[Base] @ 0b00;
  match trapVectorMode_bits(m[Mode]) {
    TV_Direct => Some(base),
    TV_Vector => if   c[IsInterrupt] == 0b1
                 then Some(base + (zero_extend(c[Cause]) << 2))
                 else Some(base),
    TV_Reserved => None(),
  }
}

/* Get base address of xtvec with all mode bits zeroed */
function tvec_base_addr(m : Mtvec) -> xlenbits = {
  match trapVectorMode_bits(m[Mode]) {
    TV_Direct => [m with Mode = zeros()].bits,
    TV_Vector => [m with Mode = zeros()].bits,
    TV_Reserved => internal_error(__FILE__, __LINE__, "Invalid xtvec mode"),
  }
}

/* Exception PC */

register mepc : xlenbits

/* The xepc legalization zeroes xepc[1:0] when misa.C is hardwired to 0.
 * When misa.C is writable, it zeroes only xepc[0].
 */
function legalize_xepc(v : xlenbits) -> xlenbits = {
  // allow writing xepc[1] only if misa.C is enabled or could be enabled.
  if   sys_enable_rvc()
  then [v with 0 = bitzero]
  else [v with 1..0 = zeros()]
}

// Align value to min supported PC alignment. This is used to
// legalize xepc reads.
function align_pc(addr : xlenbits) -> xlenbits = {
  if misa[C] == 0b1
  then [addr with 0 = bitzero]
  else [addr with 1..0 = zeros()]
}

/* auxiliary exception registers */

register mtval    : xlenbits
register mscratch : xlenbits

mapping clause csr_name_map = 0x343  <-> "mtval"
mapping clause csr_name_map = 0x340  <-> "mscratch"

function clause is_CSR_defined(0x343) = true // mtval
function clause is_CSR_defined(0x340) = true // mscratch

val get_mscratch : (unit) -> xlenbits
val set_mscratch : (xlenbits) -> unit

function clause read_CSR(0x343, _) = mtval
function clause read_CSR(0x340, _) = get_mscratch()

function clause write_CSR(0x343, value) = { mtval = convertInvalidAddr(value); mtval }
function clause write_CSR(0x340, value) = { set_mscratch(value); get_mscratch() }

/* counters */

bitfield Counteren : bits(32) = {
  HPM  : 31 .. 3,
  IR   : 2,
  TM   : 1,
  CY   : 0
}

// scounteren
function legalize_scounteren(c : Counteren, v : xlenbits) -> Counteren = {
  let supported_counters = sys_writable_hpm_counters()[31 .. 3] @ 0b111;
  Mk_Counteren(v[31 .. 0] & supported_counters)
}

register scounteren : Counteren
mapping clause csr_name_map = 0x106  <-> "scounteren"
function clause is_CSR_defined(0x106) = extensionEnabled(Ext_S) // scounteren
function clause read_CSR(0x106, _) = zero_extend(scounteren.bits)
function clause write_CSR(0x106, value) = { scounteren = legalize_scounteren(scounteren, value); zero_extend(scounteren.bits) }

// mcounteren
function legalize_mcounteren(c : Counteren, v : xlenbits) -> Counteren = {
  let supported_counters = sys_writable_hpm_counters()[31 .. 3] @ 0b111;
  Mk_Counteren(v[31 .. 0] & supported_counters)
}

register mcounteren : Counteren
mapping clause csr_name_map = 0x306  <-> "mcounteren"
function clause is_CSR_defined(0x306) = extensionEnabled(Ext_U) // mcounteren
function clause read_CSR(0x306, _) = zero_extend(mcounteren.bits)
function clause write_CSR(0x306, value) = { mcounteren = legalize_mcounteren(mcounteren, value); zero_extend(mcounteren.bits) }

// mcountinhibit
bitfield Counterin : bits(32) = {
  HPM  : 31 .. 3,
  IR : 2,
  CY : 0
}

register mcountinhibit : Counterin

function get_countinhibit() -> Counterin = Mk_Counterin(mcountinhibit.bits | sys_force_countinhibit_bits())

function legalize_mcountinhibit(c : Counterin, v : xlenbits) -> Counterin = {
  // Note the 0 in 0b101 is because the mtimer counter can't be paused.
  let supported_counters = sys_writable_hpm_counters()[31 .. 3] @ 0b101;
  Mk_Counterin(v[31 .. 0] & supported_counters)
}

mapping clause csr_name_map = 0x320  <-> "mcountinhibit"
function clause is_CSR_defined(0x320) = true // mcountinhibit
function clause read_CSR(0x320, _) = zero_extend(get_countinhibit().bits)
function clause write_CSR(0x320, value) = { mcountinhibit = legalize_mcountinhibit(mcountinhibit, value); zero_extend(get_countinhibit().bits) }

register mcycle : bits(64)
register mtime : bits(64)

/* minstret
 *
 * This model-internal register is the full 64 bit minstret counter,
 * regardless of xlen. For xlen=32, this will be split across minstret
 * and minstreth CSRs.
 * The spec says that minstret increments on instruction retires need to
 * occur before any explicit writes to instret.  However, in our
 * simulation loop, we need to execute an instruction to find out
 * whether it retired, and hence can only increment instret after
 * execution. To avoid doing this in the case minstret was explicitly
 * written to, we track whether it should increment in a separate
 * model-internal register. We keep track of any explicit CSR writes in
 * the registers below and apply them after incrementing.
 */
register minstret : bits(64)

/* Should minstret be incremented when the instruction is retired. */
register minstret_increment : bool

// If there's an explicit write to minstret(h) then it is stored here because
// it needs to be applied *after* the implicit increment due to instruction
// retirement.
register minstret_write : option(bits(xlen)) = None()
register minstreth_write : option(bits(32)) = None()

function update_minstret() -> unit = {
  // First increment minstret due to instruction retirement
  // if it was not disabled by mcountinhibit.IR.
  if minstret_increment then {
    minstret = minstret + 1;
  };

  // Then apply explicit writes to minstret (if any).
  match minstret_write {
    Some(v) => minstret = [minstret with (xlen - 1) .. 0 = v],
    None() => (),
  };
  match minstreth_write {
    Some(v) => minstret = [minstret with 63 .. 32 = v],
    None() => (),
  };
}

/* machine information registers */
register mvendorid : bits(32) = zeros()
register mimpid : xlenbits = zeros()
register marchid : xlenbits = zeros()
/* TODO: this should be readonly, and always 0 for now */
register mhartid : xlenbits = zeros()
register mconfigptr : xlenbits = zeros()

mapping clause csr_name_map = 0xF11  <-> "mvendorid"
mapping clause csr_name_map = 0xF12  <-> "marchid"
mapping clause csr_name_map = 0xF13  <-> "mimpid"
mapping clause csr_name_map = 0xF14  <-> "mhartid"
mapping clause csr_name_map = 0xF15  <-> "mconfigptr"

function clause is_CSR_defined(0xf11) = true // mvendorid
function clause is_CSR_defined(0xf12) = true // marchdid
function clause is_CSR_defined(0xf13) = true // mimpid
function clause is_CSR_defined(0xf14) = true // mhartid
function clause is_CSR_defined(0xf15) = true // mconfigptr

function clause read_CSR(0xF11, _) = zero_extend(mvendorid)
function clause read_CSR(0xF12, _) = marchid
function clause read_CSR(0xF13, _) = mimpid
function clause read_CSR(0xF14, _) = mhartid
function clause read_CSR(0xF15, _) = mconfigptr

/* S-mode registers */

/* sstatus reveals a subset of mstatus */
/* sstatus is a view of mstatus, so there is no register defined. */

function lower_mstatus(m : Mstatus) -> Sstatus = {
  let s = Mk_Sstatus(zeros());

  let s = [s with
    SD = m[SD],
    UXL = m[UXL],
    //SDT = m[SDT],
    //SPELP = m[SPELP],
    MXR = m[MXR],
    SUM = m[SUM],
    XS = m[XS],
    FS = m[FS],
    VS = m[VS],
    SPP = m[SPP],
    SPIE = m[SPIE],
    SIE = m[SIE],
  ];

  ext_lower_mstatus(m, s)
}

function lift_sstatus(m : Mstatus, s : Sstatus) -> Mstatus = {
  let dirty = extStatus_of_bits(s[FS]) == Dirty | extStatus_of_bits(s[XS]) == Dirty |
              extStatus_of_bits(s[VS]) == Dirty;

  let m = [m with
    SD = bool_to_bits(dirty),
    UXL = s[UXL],
    //SDT = s[SDT],
    //SPELP = s[SPELP],
    MXR = s[MXR],
    SUM = s[SUM],
    XS = s[XS],
    FS = s[FS],
    VS = s[VS],
    SPP = s[SPP],
    SPIE = s[SPIE],
    SIE = s[SIE],
  ];

  ext_lift_sstatus(m, s)
}

function legalize_sstatus(m : Mstatus, v : bits(64)) -> Mstatus = {
  legalize_mstatus(m, lift_sstatus(m, Mk_Sstatus(v)).bits)
}

function get_xstatus(priv : Privilege) -> bits(64) =
  match priv {
    Machine => mstatus.bits,
    Supervisor => lower_mstatus(mstatus).bits,
    User => internal_error(__FILE__, __LINE__, "N extension not supported"),
  }

function set_xstatus(priv : Privilege, xstatus : bits(64)) -> unit = {
  mstatus = match priv {
    Machine => legalize_mstatus(mstatus, xstatus),
    Supervisor => legalize_sstatus(mstatus, xstatus),
    User => internal_error(__FILE__, __LINE__, "N extension not supported"),
  };
}

mapping clause csr_name_map = 0x100  <-> "sstatus"
function clause is_CSR_defined(0x100) = extensionEnabled(Ext_S) // sstatus
function clause read_CSR(0x100, _) = lower_mstatus(mstatus).bits[xlen - 1 .. 0]
function clause write_CSR(0x100, value) = { mstatus = legalize_sstatus(mstatus, zero_extend(value)); mstatus.bits[xlen - 1 .. 0] }


bitfield Sinterrupts : xlenbits = {
  // Local Counter OverFlow Interrupt
  LCOFI : 13,

  // Supervisor External Interrupt
  SEI : 9,

  // Supervisor Timer Interrupt
  STI : 5,

  // Supervisor Software Interrupt
  SSI : 1,
}

// sip
/* Provides the sip read view of mip (m) as delegated by mideleg (d). */
function lower_mip(m : Minterrupts, d : Minterrupts) -> Sinterrupts = {
  [Mk_Sinterrupts(zeros()) with
    SEI = m[SEI] & d[SEI],
    STI = m[STI] & d[STI],
    SSI = m[SSI] & d[SSI],
    LCOFI = m[LCOFI] & d[LCOFI],
  ]
}

/* Provides the sie read view of mie (m) as delegated by mideleg (d). */
function lower_mie(m : Minterrupts, d : Minterrupts) -> Sinterrupts = {
  [Mk_Sinterrupts(zeros()) with
    SEI = m[SEI] & d[SEI],
    STI = m[STI] & d[STI],
    SSI = m[SSI] & d[SSI],
    LCOFI = m[LCOFI] & d[LCOFI],
  ]
}

/* Returns the new value of mip from the previous mip (o) and the written sip (s) as delegated by mideleg (d). */
function lift_sip(o : Minterrupts, d : Minterrupts, s : Sinterrupts) -> Minterrupts = {
  [o with
    SSI = if d[SSI] == 0b1 then s[SSI] else o[SSI],
    LCOFI = if d[LCOFI] == 0b1 then s[LCOFI] else o[LCOFI],
  ]
}

mapping clause csr_name_map = 0x144  <-> "sip"
function clause is_CSR_defined(0x144) = extensionEnabled(Ext_S) // sip
function clause read_CSR(0x144, _) = lower_mip(mip, mideleg).bits
function clause write_CSR(0x144, value) = { mip = lift_sip(mip, mideleg, Mk_Sinterrupts(value)); mip.bits }


// sie
/* Returns the new value of mie from the previous mie (o) and the written sie (s) as delegated by mideleg (d). */
function lift_sie(o : Minterrupts, d : Minterrupts, s : Sinterrupts) -> Minterrupts = {
  [o with
    SEI = if d[SEI] == 0b1 then s[SEI] else o[SEI],
    STI = if d[STI] == 0b1 then s[STI] else o[STI],
    SSI = if d[SSI] == 0b1 then s[SSI] else o[SSI],
    LCOFI = if d[LCOFI] == 0b1 then s[LCOFI] else o[LCOFI],
  ]
}

mapping clause csr_name_map = 0x104  <-> "sie"
function clause is_CSR_defined(0x104) = extensionEnabled(Ext_S) // sie
function clause read_CSR(0x104, _) = lower_mie(mie, mideleg).bits
function clause write_CSR(0x104, value) = { mie = lift_sie(mie, mideleg, Mk_Sinterrupts(value)); mie.bits }


/* other non-VM related supervisor state */
register stvec    : Mtvec
register sscratch : xlenbits
register sepc     : xlenbits
register stval    : xlenbits

mapping clause csr_name_map = 0x140  <-> "sscratch"
mapping clause csr_name_map = 0x142  <-> "scause"
mapping clause csr_name_map = 0x143  <-> "stval"

function clause is_CSR_defined(0x140) = extensionEnabled(Ext_S) // sscratch
function clause is_CSR_defined(0x142) = extensionEnabled(Ext_S) // scause
function clause is_CSR_defined(0x143) = extensionEnabled(Ext_S) // stval

val get_sscratch : (unit) -> xlenbits
val set_sscratch : (xlenbits) -> unit

function clause read_CSR(0x140, _) = get_sscratch()
function clause read_CSR(0x142, _) = get_xcause(Supervisor).bits
function clause read_CSR(0x143, _) = stval

function clause write_CSR(0x140, value) = { set_sscratch(value); get_sscratch() }
function clause write_CSR(0x142, value) = { set_xcause(Supervisor, value); get_xcause(Supervisor).bits }
function clause write_CSR(0x143, value) = { stval = convertInvalidAddr(value); stval }

/*
 * S-mode address translation and protection (satp) layout.
 * The actual satp register is defined in an architecture-specific file.
 */

bitfield Satp64 : bits(64) = {
  Mode : 63 .. 60,
  Asid : 59 .. 44,
  PPN  : 43 .. 0
}

function legalize_satp64(a : Architecture, o : bits(64), v : bits(64)) -> bits(64) = {
  let s = Mk_Satp64(v);
  let supported : bool = match satpMode_of_bits(a, s[Mode]) {
    None()      => false,
    Some(Bare)  => true,
    Some(Sv32)  => false, // Sv32 is not legal on RV64.
    Some(Sv39)  => sys_enable_sv39(),
    Some(Sv48)  => sys_enable_sv48(),
    Some(Sv57)  => sys_enable_sv57(),
  };

  let s = [
    s with
    // If full 16-bit ASID is not supported then the high bits will be read only zero.
    Asid = zero_extend(s[Asid][sys_asid_bits() - 1 .. 0]),
    // Bits above the physically addressable memory are read only zero.
    PPN = zero_extend(s[PPN][sys_pa_bits() - pagesize_bits - 1 .. 0]),
  ];

  // Read-only zero if virtual addressing is not supported, even for Bare writes.
  // (This is not required but is likely.)
  let supported = supported & (sys_enable_sv39() | sys_enable_sv48() | sys_enable_sv57());
  if supported then s.bits else o
}

bitfield Satp32 : bits(32) = {
  Mode : 31,
  Asid : 30 .. 22,
  PPN  : 21 .. 0
}

function legalize_satp32(a : Architecture, o : bits(32), v : bits(32)) -> bits(32) = {
  let s = Mk_Satp32(v);
  let supported : bool = match satpMode_of_bits(a, 0b000 @ s[Mode]) {
    None()      => false,
    Some(Bare)  => true,
    Some(Sv32)  => sys_enable_sv32(),
    _           => internal_error(__FILE__, __LINE__, "Unreachable satp32 mode"),
  };

  // The extra `min()`s are to handle Sv32 on RV64, which is not really properly
  // supported by this model anyway.

  assert(xlen == 32);

  let s = [
    s with
    // If full 16-bit ASID is not supported then the high bits will be read only zero.
    Asid = zero_extend(s[Asid][sys_asid_bits() - 1 .. 0]),
    // Bits above the physically addressable memory are read only zero.
    PPN = zero_extend(s[PPN][sys_pa_bits() - pagesize_bits - 1 .. 0]),
  ];

  // Read-only zero if virtual addressing is not supported, even for Bare writes.
  // (This is not required but is likely.)
  let supported = supported & sys_enable_sv32();
  if supported then s.bits else o
}

function legalize_satp(
  arch : Architecture,
  prev_value : xlenbits,
  written_value : xlenbits,
) -> xlenbits = {
  // TODO: This should actually switch on `arch` since satp is SXLEN not XLEN.
  if xlen == 32 then {
    legalize_satp32(arch, prev_value, written_value)
  } else if xlen == 64 then {
    legalize_satp64(arch, prev_value, written_value)
  } else {
    internal_error(__FILE__, __LINE__, "Unsupported xlen" ^ dec_str(xlen))
  }
}

/* disabled trigger/debug module */
register tselect : xlenbits

mapping clause csr_name_map = 0x7a0  <-> "tselect"
mapping clause csr_name_map = 0x7a1  <-> "tdata1"
mapping clause csr_name_map = 0x7a2  <-> "tdata2"
mapping clause csr_name_map = 0x7a3  <-> "tdata3"

function clause is_CSR_defined(0x7a0) = true
function clause read_CSR(0x7a0, _) = ~(tselect)  /* this indicates we don't have any trigger support */
function clause write_CSR(0x7a0, value) = { tselect = value; tselect }

/*
 * Entropy Source - Platform access to random bits.
 * NOTE: This would be better placed in riscv_platform.sail, but that file
 *       appears _after_ this one in the compile order meaning the valspec
 *       for this function is unavailable when it's first encountered in
 *       read_seed_csr. Hence it appears here.
 */
val get_16_random_bits = impure {
    interpreter: "Platform.get_16_random_bits",
    c: "plat_get_16_random_bits",
    lem: "plat_get_16_random_bits"
} : unit -> bits(16)

/* vector csrs */
register vstart : bits(16) /* use the largest possible length of vstart */
register vl     : xlenbits

function get_vlenb() -> xlenbits = {
  to_bits(xlen, (2 ^ (get_vlen_pow()) / 8))
}

bitfield Vtype  : xlenbits = {
  vill      : xlen - 1,
  reserved  : xlen - 2 .. 8,
  vma       : 7,
  vta       : 6,
  vsew      : 5 .. 3,
  vlmul     : 2 .. 0
}
register vtype : Vtype

/* the dynamic selected element width (SEW) */
/* this returns the power of 2 for SEW */
val get_sew_pow : unit -> {3, 4, 5, 6}
function get_sew_pow() = {
  let SEW_pow : {3, 4, 5, 6} = match vtype[vsew] {
    0b000 => 3,
    0b001 => 4,
    0b010 => 5,
    0b011 => 6,
    _     => {assert(false, "invalid vsew field in vtype"); 0}
  };
  SEW_pow
}
/* this returns the actual value of SEW */
val get_sew : unit -> {8, 16, 32, 64}
function get_sew() = {
  match get_sew_pow() {
    3 => 8,
    4 => 16,
    5 => 32,
    6 => 64,
    _ => {internal_error(__FILE__, __LINE__, "invalid SEW"); 8}
  }
}
/* this returns the value of SEW in bytes */
val get_sew_bytes : unit -> {1, 2, 4, 8}
function get_sew_bytes() = {
  match get_sew_pow() {
    3 => 1,
    4 => 2,
    5 => 4,
    6 => 8,
    _ => {internal_error(__FILE__, __LINE__, "invalid SEW"); 1}
  }
}

/* the vector register group multiplier (LMUL) */
/* this returns the power of 2 for LMUL */
val get_lmul_pow : unit -> {-3, -2, -1, 0, 1, 2, 3}
function get_lmul_pow() = {
  match vtype[vlmul] {
    0b101 => -3,
    0b110 => -2,
    0b111 => -1,
    0b000 => 0,
    0b001 => 1,
    0b010 => 2,
    0b011 => 3,
    _     => {assert(false, "invalid vlmul field in vtype"); 0}
  }
}

enum agtype = { UNDISTURBED, AGNOSTIC }

val decode_agtype : bits(1) -> agtype
function decode_agtype(ag) = {
  match ag {
    0b0 => UNDISTURBED,
    0b1 => AGNOSTIC
  }
}

val get_vtype_vma : unit -> agtype
function get_vtype_vma() = decode_agtype(vtype[vma])

val get_vtype_vta : unit -> agtype
function get_vtype_vta() = decode_agtype(vtype[vta])
