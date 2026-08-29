/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* accessors for capability representation */

/* reads a given capability register, or the null capability if the argument is zero. */
function rC(r : regno) -> regtype = rX_full(r)

/* writes a register with a capability value */
function wC (Regno(r) : regno, v : regtype) -> unit = {
  wX_full(Regno(r), v);
  if r != 0 then xreg_write_callback(Regidx(to_bits(r)), v.address)
}

function rC_bits(Regidx(i): regidx) -> regtype = rC(Regno(unsigned(i)))

function wC_bits(Regidx(i): regidx, v: regtype) -> unit = {
  wC(Regno(unsigned(i))) = v
}

overload C = {rC_bits, wC_bits, rC, wC}

/*!
 * This function is called after above when running rvfi and allows the model
 * to be initialised differently. For RVFI we initialise cap regs to default
 * instead of null.
 */
val ext_rvfi_reset : unit -> unit
function ext_rvfi_reset () = {
  foreach (i from 1 to 31) wX_full(Regno(i), infinite_cap);
}

/* mappings for assembly */

mapping cap_reg_name : regidx <-> string = {
    Regidx(0b00000) <-> "cnull",
    r               <-> "c" ^ reg_name(r)
}

mapping cap_creg_name : cregidx <-> string = {
  r <-> "c" ^ creg_name(r)
}

// Implementations are allowed to choose whether to clear the tag
// when invalid address legalisation does not modify the address
let sys_cheri_accurate_tag_clearing = false

// Modify a capability when storing in a register that cannot store all invalid
// addresses. The address may need to be changed, and if that happens the
// tag may be cleared.
function convertInvalidAddrCap(cap : Capability) -> Capability = {
  // Convert invalid addresses that can't be stored to invalid addresses that can.
  let reducedAddr = convertInvalidAddr(cap.address);
  let addrModified = reducedAddr != cap.address;
  let retainTag =
    // Always clear the tag if the address was modified for a sealed cap;
    not(addrModified & capIsSealed(cap)) &
    // Otherwise...
    (
      // Tag always retained for infinite bounds,
      capBoundsInfinite(cap) |
      // and valid addresses,
      validAddr(cap.address) |
      // and *optionally* invalid addresses that were not modified
      // by the invalid address conversion.
      sys_cheri_accurate_tag_clearing & not(addrModified)
    );
  let cap = {cap with address=reducedAddr};

  clearTagIf(cap, not(retainTag))
}

// Add illegal address conversion for capabilities to the overload.
overload convertInvalidAddr = {convertInvalidAddrCap}

function setCapCSRAddr(c : Capability, addr : CapAddrBits) -> Capability = {
  let c = setCapAddrChecked(c, addr);
  // For CSRs that do not hold all invalid addresses,
  // clear the tag if the address is invalid without infinite bounds
  clearTagIf(c, not(validAddr(c.address) | capBoundsInfinite(c)))
}
