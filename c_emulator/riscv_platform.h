#pragma once
#include "sail.h"

#ifdef __cplusplus
extern "C" {
#endif

// Provides entropy for the scalar cryptography extension.
mach_bits plat_get_16_random_bits(unit);

unit load_reservation(sbits);
bool match_reservation(sbits);
unit cancel_reservation(unit);
bool valid_reservation(unit);

unit plat_term_write(mach_bits);

mach_bits plat_htif_tohost(unit);
bool plat_enable_htif(unit);

bool sys_enable_experimental_extensions(unit);

unit memea(mach_bits, sail_int);

mach_bits plat_nmi_handler(unit u);
sbits plat_pma_address(mach_bits i);
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
sbits plat_pma_size(mach_bits i);
bool plat_pma_supportsCboZero(mach_bits i);
bool plat_pma_taggable(mach_bits i);
bool plat_pma_taggableAccessFaults(mach_bits i);
bool plat_pma_writable(mach_bits i);
bool plat_pma_writeIdempotent(mach_bits i);
mach_bits sys_asid_bits(unit u);
bool sys_enable_pbmt(unit u);
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
