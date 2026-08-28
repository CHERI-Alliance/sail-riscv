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

bool sys_enable_rvy(unit)
{
  return rv_enable_rvy;
}

// Provides entropy for the scalar cryptography extension.
mach_bits plat_get_16_random_bits(unit)
{
  return rv_16_random_bits();
}

// Note: Store-Conditionals are allowed to spuriously fail. If you want
// that to happen you can spuriously set `reservation_valid = false`
// either directly in `load_reservation()` or by callling
// `cancel_reservation()`.

unit load_reservation(sbits addr)
{
  reservation = addr.bits;
  reservation_valid = true;
  RESERVATION_DBG("reservation <- %0" PRIx64 "\n", reservation);
  return UNIT;
}

static mach_bits check_mask()
{
  return (zxlen == 32) ? 0x00000000FFFFFFFF : -1;
}

bool match_reservation(sbits addr)
{
  mach_bits mask = check_mask();
  bool ret = reservation_valid && (reservation & mask) == (addr.bits & mask);
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

bool valid_reservation(unit)
{
  return reservation_valid;
}

unit plat_term_write(mach_bits s)
{
  char c = s & 0xff;
  plat_term_write_impl(c);
  return UNIT;
}

bool plat_enable_htif(unit)
{
  return rv_enable_htif;
}

mach_bits plat_htif_tohost(unit)
{
  return rv_htif_tohost;
}

bool sys_enable_experimental_extensions(unit)
{
  return rv_enable_experimental_extensions;
}

unit memea(mach_bits, sail_int)
{
  return UNIT;
}

mach_bits plat_nmi_handler(unit u)
{
  return 0;
}

sbits plat_pma_address(mach_bits i)
{
  sbits result;
  result.len = zphysaddrbits_len;
  result.bits = 0;
  return result;
}

mach_bits plat_pma_atomicSupport_int(mach_bits i)
{
  return 3; // AMOArithmetic (full atomic memory operation support)
}

bool plat_pma_cacheable(mach_bits i)
{
  return true;
}

bool plat_pma_coherent(mach_bits i)
{
  return true;
}

mach_bits plat_pma_count(unit u)
{
  return 1;
}

bool plat_pma_executable(mach_bits i)
{
  return true;
}

bool plat_pma_misalignmentCausesAccessFault(mach_bits i)
{
  return false;
}

bool plat_pma_misalignmentCausesAlignmentFault(mach_bits i)
{
  return false;
}

bool plat_pma_readable(mach_bits i)
{
  return true;
}

bool plat_pma_readIdempotent(mach_bits i)
{
  return true;
}

bool plat_pma_relaxed(mach_bits i)
{
  return true;
}

mach_bits plat_pma_reservability_int(mach_bits i)
{
  return 2; // RsrvEventual (eventual success guarantee for LR/SC)
}

sbits plat_pma_size(mach_bits i)
{
  sbits result;
  result.len = zphysaddrbits_len;
  result.bits = 0xF0000000;
  return result;
}

bool plat_pma_supportsCboZero(mach_bits i)
{
  return true;
}

bool plat_pma_taggable(mach_bits i)
{
  return true;
}

bool plat_pma_taggableAccessFaults(mach_bits i)
{
  return false;
}

bool plat_pma_writable(mach_bits i)
{
  return true;
}

bool plat_pma_writeIdempotent(mach_bits i)
{
  return true;
}

mach_bits sys_asid_bits(unit u)
{
  return 4;
}

bool sys_enable_pbmt(unit u)
{
  return true;
}

mach_bits sys_force_countinhibit_bits(unit u)
{
  return 0;
}

mach_bits sys_hpmevent_writable_bits(unit u)
{
  return 0xFFFFFFFF;
}

mach_bits sys_medeleg_writable_bits(unit u)
{
  return 0xFFFFFFFF;
}

mach_bits sys_mideleg_writable_bits(unit u)
{
  return 0xFFFFFFFF;
}

bool sys_misa_x(unit u)
{
  return true;
}

mach_bits sys_pa_bits(unit u)
{
  return (zxlen == 32) ? 34 : 56;
}

mach_bits sys_pmp_writable(unit u)
{
  return 0xFFFFFFFF;
}

bool sys_writable_stip(unit u)
{
  return 0xFFFFFFFF;
}

mach_bits sys_xcause_bits(unit u)
{
  return zxlen - 1;
}
