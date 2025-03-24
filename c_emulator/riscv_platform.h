#pragma once
#include "sail.h"

#ifdef __cplusplus
extern "C" {
#endif

bool sys_enable_rvc(unit);
bool sys_enable_fdext(unit);
bool sys_enable_svinval(unit);
bool sys_enable_zcb(unit);
bool sys_enable_zfinx(unit);
bool sys_enable_writable_misa(unit);
bool sys_enable_writable_fiom(unit);
bool sys_enable_vext(unit);
bool sys_enable_bext(unit);
bool sys_enable_zicbom(unit);
bool sys_enable_zicboz(unit);
bool sys_enable_sstc(unit);

uint64_t sys_pmp_count(unit);
uint64_t sys_pmp_grain(unit);

bool sys_vext_vl_use_ceil(unit);
uint64_t sys_vector_vlen_exp(unit);
uint64_t sys_vector_elen_exp(unit);

bool plat_enable_dirty_update(unit);
bool plat_enable_misaligned_access(unit);
bool plat_mtval_has_illegal_inst_bits(unit);
mach_bits sys_writable_hpm_counters(unit);

mach_bits plat_ram_base(unit);
mach_bits plat_ram_size(unit);
bool within_phys_mem(mach_bits, sail_int);

mach_bits plat_rom_base(unit);
mach_bits plat_rom_size(unit);

mach_bits plat_cache_block_size_exp(unit);

// Provides entropy for the scalar cryptography extension.
mach_bits plat_get_16_random_bits(unit);

mach_bits plat_clint_base(unit);
mach_bits plat_clint_size(unit);

bool speculate_conditional(unit);
unit load_reservation(mach_bits);
bool match_reservation(mach_bits);
unit cancel_reservation(unit);

void plat_insns_per_tick(sail_int *rop, unit);

unit plat_term_write(mach_bits);
mach_bits plat_htif_tohost(unit);

unit memea(mach_bits, sail_int);

mach_bits plat_nmi_handler(unit u);
mach_bits plat_pma_address(mach_bits i);
mach_bits plat_pma_atomicSupport_int(mach_bits i);
bool plat_pma_cacheable(mach_bits i);
bool plat_pma_coherent(mach_bits i);
mach_bits plat_pma_count(unit u);
bool plat_pma_executable(mach_bits i);
bool plat_pma_misalignmentCausesAccessFault(mach_bits i);
bool plat_pma_misalignmentCausesAlignmentFault(mach_bits i);
bool plat_pma_readable(mach_bits i);
bool plat_pma_readIdempotent(mach_bits i);
bool plat_pma_relaxed(mach_bits i);
mach_bits plat_pma_reservability_int(mach_bits i);
mach_bits plat_pma_size(mach_bits i);
bool plat_pma_supportsCboZero(mach_bits i);
bool plat_pma_taggable(mach_bits i);
bool plat_pma_taggableAccessFaults(mach_bits i);
bool plat_pma_writable(mach_bits i);
bool plat_pma_writeIdempotent(mach_bits i);
mach_bits sys_asid_bits(unit u);
bool sys_enable_pbmt(unit u);
bool sys_enable_sscofpmf(unit u);
bool sys_enable_sv32(unit u);
bool sys_enable_sv39(unit u);
bool sys_enable_sv48(unit u);
bool sys_enable_sv57(unit u);
bool sys_enable_svnapot(unit u);
bool sys_enable_zba(unit u);
bool sys_enable_zbb(unit u);
bool sys_enable_zbc(unit u);
bool sys_enable_zbkb(unit u);
bool sys_enable_zbkc(unit u);
bool sys_enable_zbs(unit u);
bool sys_enable_zfh(unit u);
bool sys_enable_zfhmin(unit u);
bool sys_enable_zihpm(unit u);
bool sys_enable_zkr(unit u);
mach_bits sys_force_countinhibit_bits(unit u);
mach_bits sys_hpmevent_writable_bits(unit u);
mach_bits sys_medeleg_writable_bits(unit u);
mach_bits sys_mideleg_writable_bits(unit u);
bool sys_misa_x(unit u);
mach_bits sys_pa_bits(unit u);
mach_bits sys_pmp_writable(unit u);
bool sys_writable_stip(unit u);
mach_bits sys_xcause_bits(unit u);

#ifdef __cplusplus
} // extern "C"
#endif
