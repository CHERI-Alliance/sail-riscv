/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* CHERI interface to physical memory.  We use the metadata facility for tags. */

val mem_read_cap : (physaddr, PBMT, bool, bool, bool) -> MemoryOpResult(Capability)
function mem_read_cap (addr, pbmt, aq, rl, res) = {
  let result : MemoryOpResult((CapBits, bool)) = mem_read_meta(Read(Data), pbmt, addr, cap_size, aq, rl, res, true);
  match result {
    Ok(v, tag) => Ok(bitsToCap(tag, v)),
    Err(e)     => Err(e) : MemoryOpResult(Capability)
  }
}

val mem_write_ea_cap : (physaddr, bool, bool, bool) -> MemoryOpResult(unit)
function mem_write_ea_cap(addr, aq, rl, con) = {
  if   ~(is_aligned_addr(addr, cap_size))
  then Err(E_SAMO_Addr_Align())
  else Ok(write_ram_ea(Write_plain, addr, cap_size)) // FIXME: is Write_plain correct?
}

val mem_write_cap : (physaddr, PBMT, Capability, bool, bool, bool) -> MemoryOpResult(bool)
function mem_write_cap (addr, pbmt, cap, aq, rl, con) = {
  let cap_bits = capToMetadataBits(cap).bits @ cap.address;
  /* Assume that conversion to bits and back does not change the capability.
     TODO: State closed-form normalised-ness criterion that implies this,
     and prove it as an invariant of capabilities in the system. */
  assert(bitsToCap(cap.tag, cap_bits) == cap);
  mem_write_value_meta(pbmt, addr, cap_size, cap_bits, if cap.tag then Tagged else Data, cap.tag, aq, rl, con)
}
