#include "sail.h"
#include "rts.h"
#include "riscv_prelude.h"
#include "riscv_platform.h"
#include "riscv_platform_impl.h"
#include "riscv_sail.h"

#ifdef DEBUG_RESERVATION
#include <stdio.h>
#include <inttypes.h>
#define RESERVATION_DBG(args...) fprintf(stderr, args)
#else
#define RESERVATION_DBG(args...)
#endif

/* This file contains the definitions of the C externs of Sail model. */

static mach_bits reservation = 0;
static bool reservation_valid = false;

bool sys_enable_rvc(unit)
{
  return rv_enable_rvc;
}

bool sys_enable_fdext(unit)
{
  return rv_enable_fdext;
}

bool sys_enable_svinval(unit)
{
  return rv_enable_svinval;
}

bool sys_enable_zcb(unit)
{
  return rv_enable_zcb;
}

bool sys_enable_zfinx(unit)
{
  return rv_enable_zfinx;
}

bool sys_enable_writable_fiom(unit)
{
  return rv_enable_writable_fiom;
}

bool sys_enable_vext(unit)
{
  return rv_enable_vext;
}

bool sys_enable_bext(unit)
{
  return rv_enable_bext;
}

bool sys_enable_zicbom(unit)
{
  return rv_enable_zicbom;
}

bool sys_enable_zicboz(unit)
{
  return rv_enable_zicboz;
}

bool sys_enable_sstc(unit)
{
  return rv_enable_sstc;
}

uint64_t sys_pmp_count(unit)
{
  return rv_pmp_count;
}

uint64_t sys_pmp_grain(unit)
{
  return rv_pmp_grain;
}

uint64_t sys_vector_vlen_exp(unit)
{
  return rv_vector_vlen_exp;
}

uint64_t sys_vector_elen_exp(unit)
{
  return rv_vector_elen_exp;
}

bool sys_enable_writable_misa(unit)
{
  return rv_enable_writable_misa;
}

mach_bits sys_writable_hpm_counters(unit)
{
  return rv_writable_hpm_counters;
}

bool sys_vext_vl_use_ceil(unit)
{
  return rv_vext_vl_use_ceil;
}

bool plat_enable_dirty_update(unit)
{
  return rv_enable_dirty_update;
}

bool plat_enable_misaligned_access(unit)
{
  return rv_enable_misaligned;
}

bool plat_mtval_has_illegal_inst_bits(unit)
{
  return rv_mtval_has_illegal_inst_bits;
}

mach_bits plat_ram_base(unit)
{
  return rv_ram_base;
}

mach_bits plat_ram_size(unit)
{
  return rv_ram_size;
}

mach_bits plat_rom_base(unit)
{
  return rv_rom_base;
}

mach_bits plat_rom_size(unit)
{
  return rv_rom_size;
}

mach_bits plat_cache_block_size_exp(unit)
{
  return rv_cache_block_size_exp;
}

// Provides entropy for the scalar cryptography extension.
mach_bits plat_get_16_random_bits(unit)
{
  return rv_16_random_bits();
}

mach_bits plat_clint_base(unit)
{
  return rv_clint_base;
}

mach_bits plat_clint_size(unit)
{
  return rv_clint_size;
}

unit load_reservation(mach_bits addr)
{
  reservation = addr;
  reservation_valid = true;
  RESERVATION_DBG("reservation <- %0" PRIx64 "\n", reservation);
  return UNIT;
}

bool speculate_conditional(unit)
{
  return true;
}

static mach_bits check_mask()
{
  return (zxlen_val == 32) ? 0x00000000FFFFFFFF : -1;
}

bool match_reservation(mach_bits addr)
{
  mach_bits mask = check_mask();
  bool ret = reservation_valid && (reservation & mask) == (addr & mask);
  RESERVATION_DBG("reservation(%c): %0" PRIx64 ", key=%0" PRIx64 ": %s\n",
                  reservation_valid ? 'v' : 'i', reservation, addr,
                  ret ? "ok" : "fail");
  return ret;
}

unit cancel_reservation(unit)
{
  RESERVATION_DBG("reservation <- none\n");
  reservation_valid = false;
  return UNIT;
}

unit plat_term_write(mach_bits s)
{
  char c = s & 0xff;
  plat_term_write_impl(c);
  return UNIT;
}

void plat_insns_per_tick(sail_int *, unit) { }

mach_bits plat_htif_tohost(unit)
{
  return rv_htif_tohost;
}

unit memea(mach_bits, sail_int)
{
  return UNIT;
}


mach_bits plat_nmi_handler(unit u) {
  return 0;
}

mach_bits plat_pma_address(mach_bits i) {
  return 0;
}

mach_bits plat_pma_atomicSupport_int(mach_bits i) {
  return 0;
}

bool plat_pma_cacheable(mach_bits i) {
  return true;
}

bool plat_pma_coherent(mach_bits i) {
  return true;
}

mach_bits plat_pma_count(unit u) {
  return 1;
}

bool plat_pma_executable(mach_bits i) {
  return true;
}

bool plat_pma_misalignmentCausesAccessFault(mach_bits i) {
  return false;
}

bool plat_pma_misalignmentCausesAlignmentFault(mach_bits i) {
  return false;
}

bool plat_pma_readable(mach_bits i) {
  return true;
}

bool plat_pma_readIdempotent(mach_bits i) {
  return true;
}

bool plat_pma_relaxed(mach_bits i) {
  return true;
}

mach_bits plat_pma_reservability_int(mach_bits i) {
  return 0;
}

mach_bits plat_pma_size(mach_bits i) {
  return 0xF0000000;
}

bool plat_pma_supportsCboZero(mach_bits i) {
  return true;
}

bool plat_pma_taggable(mach_bits i) {
  return true;
}

bool plat_pma_taggableAccessFaults(mach_bits i) {
  return false;
}

bool plat_pma_writable(mach_bits i) {
  return true;
}

bool plat_pma_writeIdempotent(mach_bits i) {
  return true;
}

mach_bits sys_asid_bits(unit u) {
  return 4;
}

bool sys_enable_pbmt(unit u) {
  return true;
}

bool sys_enable_sscofpmf(unit u) {
  return true;
}

bool sys_enable_sv32(unit u) {
  return true;
}

bool sys_enable_sv39(unit u) {
  return true;
}

bool sys_enable_sv48(unit u) {
  return true;
}

bool sys_enable_sv57(unit u) {
  return true;
}

bool sys_enable_svnapot(unit u) {
  return true;
}

bool sys_enable_zba(unit u) {
  return true;
}

bool sys_enable_zbb(unit u) {
  return true;
}

bool sys_enable_zbc(unit u) {
  return true;
}

bool sys_enable_zbkb(unit u) {
  return true;
}

bool sys_enable_zbkc(unit u) {
  return true;
}

bool sys_enable_zbs(unit u) {
  return true;
}

bool sys_enable_zfh(unit u) {
  return true;
}

bool sys_enable_zfhmin(unit u) {
  return true;
}

bool sys_enable_zihpm(unit u) {
  return true;
}

bool sys_enable_zkr(unit u) {
  return true;
}

mach_bits sys_force_countinhibit_bits(unit u) {
  return 0;
}

mach_bits sys_hpmevent_writable_bits(unit u) {
  return 0xFFFFFFFF;
}

mach_bits sys_medeleg_writable_bits(unit u) {
  return 0xFFFFFFFF;
}

mach_bits sys_mideleg_writable_bits(unit u) {
  return 0xFFFFFFFF;
}

bool sys_misa_x(unit u) {
  return true;
}

mach_bits sys_pa_bits(unit u) {
  return 39;
}

mach_bits sys_pmp_writable(unit u) {
  return 0xFFFFFFFF;
}

bool sys_writable_stip(unit u) {
  return 0xFFFFFFFF;
}

mach_bits sys_xcause_bits(unit u) {
  return 0xFFFFFFFF;
}
