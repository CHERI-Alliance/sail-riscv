/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Platform-specific definitions, and basic MMIO devices. */

/* Current constraints on this implementation are:
   - it cannot access memory directly, but instead provides definitions for the physical memory model
   - it can access system register state, needed to manipulate interrupt bits
   - it relies on externs to get platform address information and doesn't hardcode them
*/

val elf_tohost = pure {
  interpreter: "Elf_loader.elf_tohost",
  c: "elf_tohost"
} :  unit -> int

val elf_entry = pure {
  interpreter: "Elf_loader.elf_entry",
  c: "elf_entry"
} : unit -> int

// Cache block size is 2^cache_block_size_exp. Max is `max_mem_access` (4096)
// because this model performs `cbo.zero` with a single write, and the behaviour
// with cache blocks larger than a page is not clearly defined.
val plat_cache_block_size_exp = pure {c: "plat_cache_block_size_exp", interpreter: "Platform.cache_block_size_exp", lem: "plat_cache_block_size_exp"} : unit -> range(0, 12)

/* PMA loading */

// Restrict indexes to a reasonable range so they use mach_bits instead of GMP.
type pmaidx = range(0, 1024)

val plat_pma_count = pure {c: "plat_pma_count"} : unit -> pmaidx
val plat_pma_address = pure {c: "plat_pma_address"} : pmaidx -> physaddrbits
val plat_pma_size = pure {c: "plat_pma_size"} : pmaidx -> physaddrbits
val plat_pma_cacheable = pure {c: "plat_pma_cacheable"} : pmaidx -> bool
val plat_pma_coherent = pure {c: "plat_pma_coherent"} : pmaidx -> bool
val plat_pma_executable = pure {c: "plat_pma_executable"} : pmaidx -> bool
val plat_pma_readable = pure {c: "plat_pma_readable"} : pmaidx -> bool
val plat_pma_writable = pure {c: "plat_pma_writable"} : pmaidx -> bool
val plat_pma_readIdempotent = pure {c: "plat_pma_readIdempotent"} : pmaidx -> bool
val plat_pma_writeIdempotent = pure {c: "plat_pma_writeIdempotent"} : pmaidx -> bool
val plat_pma_relaxed = pure {c: "plat_pma_relaxed"} : pmaidx -> bool
val plat_pma_misalignmentCausesAccessFault = pure {c: "plat_pma_misalignmentCausesAccessFault"} : pmaidx -> bool
val plat_pma_misalignmentCausesAlignmentFault = pure {c: "plat_pma_misalignmentCausesAlignmentFault"} : pmaidx -> bool
val plat_pma_atomicSupport_int = pure {c: "plat_pma_atomicSupport_int" } : pmaidx -> range(0, 3)
val plat_pma_reservability_int = pure {c: "plat_pma_reservability_int" } : pmaidx -> range(0, 2)
val plat_pma_taggable = pure {c: "plat_pma_taggable"} : pmaidx -> bool
val plat_pma_taggableAccessFaults = pure {c: "plat_pma_taggableAccessFaults"} : pmaidx -> bool
val plat_pma_supportsCboZero = pure {c: "plat_pma_supportsCboZero"} : pmaidx -> bool

// Mapping to integers so we can pass them through FFI easier.
mapping atomicSupport_int : AtomicSupport <-> range(0, 3) = {
  AMONone       <-> 0,
  AMOSwap       <-> 1,
  AMOLogical    <-> 2,
  AMOArithmetic <-> 3,
}

mapping reservability_int : Reservability <-> range(0, 2) = {
  RsrvNone        <-> 0,
  RsrvNonEventual <-> 1,
  RsrvEventual    <-> 2,
}

val plat_pma_atomicSupport : pmaidx -> AtomicSupport
function plat_pma_atomicSupport(i) = atomicSupport_int(plat_pma_atomicSupport_int(i))

val plat_pma_reservability : pmaidx -> Reservability
function plat_pma_reservability(i) = reservability_int(plat_pma_reservability_int(i))

val init_pma_regions : unit -> unit
function init_pma_regions() = {
  // Clear regions so this is idempotent.
  pma_regions = [||];

  // Iterate backwards because pma_regions is a singly linked list that we
  // prepend to.
  foreach (i from (plat_pma_count() - 1) downto 0) {
    let attr : PMA = struct {
      cacheable                        = plat_pma_cacheable(i),
      coherent                         = plat_pma_coherent(i),
      executable                       = plat_pma_executable(i),
      readable                         = plat_pma_readable(i),
      writable                         = plat_pma_writable(i),
      readIdempotent                   = plat_pma_readIdempotent(i),
      writeIdempotent                  = plat_pma_writeIdempotent(i),
      relaxed                          = plat_pma_relaxed(i),
      misalignmentCausesAccessFault    = plat_pma_misalignmentCausesAccessFault(i),
      misalignmentCausesAlignmentFault = plat_pma_misalignmentCausesAlignmentFault(i),
      atomicSupport                    = plat_pma_atomicSupport(i),
      reservability                    = plat_pma_reservability(i),
      taggable                         = plat_pma_taggable(i),
      taggableAccessFaults             = plat_pma_taggableAccessFaults(i),
      supportsCboZero                  = plat_pma_supportsCboZero(i),
    };

    assert(not(attr.misalignmentCausesAccessFault & attr.misalignmentCausesAlignmentFault));

    let region : PMA_Region = struct {
      base       = physaddr(plat_pma_address(i)),
      size       = plat_pma_size(i),
      attributes = attr,
    };
    pma_regions = region :: pma_regions;
  };
}

/* whether the MMU should update dirty bits in PTEs */
val plat_enable_dirty_update = pure {interpreter: "Platform.enable_dirty_update",
                                     c: "plat_enable_dirty_update",
                                     lem: "plat_enable_dirty_update"} : unit -> bool

/* whether the platform supports misaligned accesses without trapping to M-mode. if false,
 * misaligned loads/stores are trapped to Machine mode.
 */
val plat_enable_misaligned_access = pure {interpreter: "Platform.enable_misaligned_access",
                                          c: "plat_enable_misaligned_access",
                                          lem: "plat_enable_misaligned_access"} : unit -> bool

/* whether mtval stores the bits of a faulting instruction on illegal instruction exceptions */
val plat_mtval_has_illegal_inst_bits = pure {interpreter: "Platform.mtval_has_illegal_inst_bits",
                                             c: "plat_mtval_has_illegal_inst_bits",
                                             lem: "plat_mtval_has_illegal_inst_bits"} : unit -> bool

/* ROM holding reset vector and device-tree DTB */
val plat_rom_base   = pure {interpreter: "Platform.rom_base", c: "plat_rom_base", lem: "plat_rom_base"} : unit -> physaddrbits
val plat_rom_size   = pure {interpreter: "Platform.rom_size", c: "plat_rom_size", lem: "plat_rom_size"} : unit -> physaddrbits

/* Location of clock-interface, which should match with the spec in the DTB */
val plat_clint_base = pure {interpreter: "Platform.clint_base", c: "plat_clint_base", lem: "plat_clint_base"} : unit -> physaddrbits
val plat_clint_size = pure {interpreter: "Platform.clint_size", c: "plat_clint_size", lem: "plat_clint_size"} : unit -> physaddrbits

/* Location of clic memory mapped registers */
val plat_clic_base = pure {interpreter: "Platform.clic_base", c: "plat_clic_base", lem: "plat_clic_base"} : unit -> physaddrbits
val plat_clic_size = pure {interpreter: "Platform.clic_size", c: "plat_clic_size", lem: "plat_clic_size"} : unit -> physaddrbits
val plat_clic_disable_mmio = pure {interpreter: "Platform.plat_clic_disable_mmio", c: "plat_clic_disable_mmio", lem: "plat_clic_disable_mmio"} : unit -> bool

function within_clint forall 'n, 0 < 'n <= max_mem_access . (physaddr(addr) : physaddr, width : int('n)) -> bool = {
  /* To avoid overflow issues when physical memory extends to the end
   * of the addressable range, we need to perform address bound checks
   * on unsigned unbounded integers.
   */
  let addr_int       = unsigned(addr);
  let clint_base_int = unsigned(plat_clint_base ());
  let clint_size_int = unsigned(plat_clint_size ());
    clint_base_int <= addr_int
  & (addr_int + sizeof('n)) <= (clint_base_int + clint_size_int)
}


/* CLINT (Core Local Interruptor), based on Spike. */

val plat_insns_per_tick = pure {interpreter: "Platform.insns_per_tick", c: "plat_insns_per_tick", lem: "plat_insns_per_tick"} : unit -> int

// Each hart has a memory-mapped mtimecmp register. Typically these are
// exposed as an array in CLINT. The CLINT implementation here is currently
// hard-coded to use the mtimecmp for hart 0.
register mtimecmp : bits(64)

// Unlike mtimecmp, stimecmp is a real CSR; not memory mapped.
// register stimecmp : bits(64)

/* CLINT memory-mapped IO */

/* relative address map:
 *
 * 0000 msip hart 0         -- memory-mapped software interrupt
 * 0004 msip hart 1
 * 4000 mtimecmp hart 0 lo  -- memory-mapped timer thresholds
 * 4004 mtimecmp hart 0 hi
 * 4008 mtimecmp hart 1 lo
 * 400c mtimecmp hart 1 hi
 * bff8 mtime lo            -- memory-mapped clocktimer value
 * bffc mtime hi
 */

let MSIP_BASE        : physaddrbits = zero_extend(0x00000)
let MTIMECMP_BASE    : physaddrbits = zero_extend(0x04000)
let MTIMECMP_BASE_HI : physaddrbits = zero_extend(0x04004)
let MTIME_BASE       : physaddrbits = zero_extend(0x0bff8)
let MTIME_BASE_HI    : physaddrbits = zero_extend(0x0bffc)

val clint_load : forall 'n, 'n > 0. (AccessType(ext_access_type), physaddr, int('n)) -> MemoryOpResult(bits(8 * 'n))
function clint_load(t, physaddr(addr), width) = {
  let addr = addr - plat_clint_base ();
  /* FIXME: For now, only allow exact aligned access. */
  if addr == MSIP_BASE & ('n == 8 | 'n == 4)
  then {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mip[MSI]));
    Ok(zero_extend(sizeof(8 * 'n), mip[MSI]))
  }
  else if addr == MTIMECMP_BASE & ('n == 4)
  then {
    if   get_config_print_platform()
    then print_platform("clint<4>[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtimecmp[31..0]));
    /* FIXME: Redundant zero_extend currently required by Lem backend */
    Ok(zero_extend(32, mtimecmp[31..0]))
  }
  else if addr == MTIMECMP_BASE & ('n == 8)
  then {
    if   get_config_print_platform()
    then print_platform("clint<8>[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtimecmp));
    /* FIXME: Redundant zero_extend currently required by Lem backend */
    Ok(zero_extend(64, mtimecmp))
  }
  else if addr == MTIMECMP_BASE_HI & ('n == 4)
  then {
    if   get_config_print_platform()
    then print_platform("clint-hi<4>[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtimecmp[63..32]));
    /* FIXME: Redundant zero_extend currently required by Lem backend */
    Ok(zero_extend(32, mtimecmp[63..32]))
  }
  else if addr == MTIME_BASE & ('n == 4)
  then {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtime));
    Ok(zero_extend(32, mtime[31..0]))
  }
  else if addr == MTIME_BASE & ('n == 8)
  then {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtime));
    Ok(zero_extend(64, mtime))
  }
  else if addr == MTIME_BASE_HI & ('n == 4)
  then {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] -> " ^ BitStr(mtime));
    Ok(zero_extend(32, mtime[63..32]))
  }
  else {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] -> <not-mapped>");
    match t {
      Execute()  => Err(E_Fetch_Access_Fault()),
      Read(Data) => Err(E_Load_Access_Fault()),
      _          => Err(E_SAMO_Access_Fault())
    }
  }
}

function clint_dispatch() -> unit = {
  mip[MTI] = bool_to_bits(mtimecmp <=_u mtime);
  if extensionEnabled(Ext_Sstc) then {
    mip[STI] = bool_to_bits(stimecmp <=_u mtime);
  };
  if get_config_print_platform()
  then print_platform("clint mtime " ^ BitStr(mtime) ^ " (mip.MTI <- " ^ BitStr(mip[MTI]) ^
    (if extensionEnabled(Ext_Sstc) then ", mip.STI <- " ^ BitStr(mip[STI]) else "") ^ ")");
}

val clint_store: forall 'n, 'n > 0. (physaddr, int('n), bits(8 * 'n)) -> MemoryOpResult(bool)
function clint_store(physaddr(addr), width, data) = {
  let addr = addr - plat_clint_base ();
  if addr == MSIP_BASE & ('n == 8 | 'n == 4) then {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mip.MSI <- " ^ BitStr(data[0]) ^ ")");
    mip[MSI] = [data[0]];
    clint_dispatch();
    Ok(true)
  } else if addr == MTIMECMP_BASE & 'n == 8 then {
    if   get_config_print_platform()
    then print_platform("clint<8>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtimecmp)");
    mtimecmp = zero_extend(64, data); /* FIXME: Redundant zero_extend currently required by Lem backend */
    clint_dispatch();
    Ok(true)
  } else if addr == MTIMECMP_BASE & 'n == 4 then {
    if   get_config_print_platform()
    then print_platform("clint<4>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtimecmp)");
    mtimecmp = vector_update_subrange(mtimecmp, 31, 0, zero_extend(32, data));  /* FIXME: Redundant zero_extend currently required by Lem backend */
    clint_dispatch();
    Ok(true)
  } else if addr == MTIMECMP_BASE_HI & 'n == 4 then {
    if   get_config_print_platform()
    then print_platform("clint<4>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtimecmp)");
    mtimecmp = vector_update_subrange(mtimecmp, 63, 32, zero_extend(32, data)); /* FIXME: Redundant zero_extend currently required by Lem backend */
    clint_dispatch();
    Ok(true)
  } else if addr == MTIME_BASE & 'n == 8 then {
    if   get_config_print_platform()
    then print_platform("clint<8>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtime)");
    mtime = data;
    clint_dispatch();
    Ok(true)
  } else if addr == MTIME_BASE & 'n == 4 then {
    if   get_config_print_platform()
    then print_platform("clint<4>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtime)");
    mtime[31 .. 0] = data;
    clint_dispatch();
    Ok(true)
  } else if addr == MTIME_BASE_HI & 'n == 4 then {
    if   get_config_print_platform()
    then print_platform("clint<4>[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (mtime)");
    mtime[63 .. 32] = data;
    clint_dispatch();
    Ok(true)
  } else {
    if   get_config_print_platform()
    then print_platform("clint[" ^ BitStr(addr) ^ "] <- " ^ BitStr(data) ^ " (<unmapped>)");
    Err(E_SAMO_Access_Fault())
  }
}

function tick_clock(cycles_increment : bits(64)) -> unit = {
  if   should_inc_mcycle(cur_privilege())
  then mcycle = mcycle + cycles_increment;

  mtime  = mtime  + 1;
  clint_dispatch()
}

/* Basic terminal character I/O. */

val plat_term_write = impure {c: "plat_term_write", lem: "plat_term_write"} : bits(8) -> unit
val plat_term_read  = impure {c: "plat_term_read", lem: "plat_term_read"}  : unit -> bits(8)

/* Top-level MMIO dispatch */
function within_mmio_readable forall 'n, 0 < 'n <= max_mem_access . (addr : physaddr, width : int('n)) -> bool = {
  within_clint(addr, width)
}

function within_mmio_writable forall 'n, 0 < 'n <= max_mem_access . (addr : physaddr, width : int('n)) -> bool = {
  within_clint(addr, width)
}

function mmio_read forall 'n, 0 < 'n <= max_mem_access . (t : AccessType(ext_access_type), paddr : physaddr, width : int('n)) -> MemoryOpResult(bits(8 * 'n)) =
  if   within_clint(paddr, width)
  then clint_load(t, paddr, width)
  else match t {
    Execute()  => Err(E_Fetch_Access_Fault()),
    Read(Data) => Err(E_Load_Access_Fault()),
    _          => Err(E_SAMO_Access_Fault())
  }

function mmio_write forall 'n, 0 <'n <= max_mem_access . (paddr : physaddr, width : int('n), data: bits(8 * 'n)) -> MemoryOpResult(bool) =
  if   within_clint(paddr, width)
  then clint_store(paddr, width, data)
  else Err(E_SAMO_Access_Fault())

/* Platform initialization and ticking. */

function init_platform() -> unit = {
  init_pma_regions();
}

function tick_platform() -> unit = ()

/* Platform-specific handling of instruction faults */

function handle_illegal() -> unit = {
  let info = if plat_mtval_has_illegal_inst_bits ()
             then Some(instbits)
             else None();
  let t : sync_exception = struct { trap    = E_Illegal_Instr(),
                                    excinfo = info,
                                    ext     = None() };
  set_next_pc(exception_handler(cur_privilege(), CTL_TRAP(t), PC))
}

/* Platform-specific wait-for-interrupt */
function platform_wfi() -> unit = ()
