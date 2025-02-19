/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* **************************************************************** */
/* Floating point register file and accessors for F, D extensions   */
/* Floating point CSR and accessors                                 */
/* **************************************************************** */

// Canonical NaNs when an invalid boxed value is unboxed.
val canonical_NaN : forall 'n, 'n in {16, 32, 64} . (implicit('n)) -> bits('n)
function canonical_NaN(_retbits) =
  match 'n {
    //    sign  exponent   significand
    16 => 0b0 @ ones(5)  @ 0b1 @ zeros(9),
    32 => 0b0 @ ones(8)  @ 0b1 @ zeros(22),
    64 => 0b0 @ ones(11) @ 0b1 @ zeros(51),
  }

// When an n-bit float is stored in a larger m-bit register it is "boxed"
// by prepending 1s, which make it appear as a qNaN.
val nan_box : forall 'n 'm, 'n <= 'm . (implicit('m), bits('n)) -> bits('m)
function nan_box(_retbits, x) = ones('m - 'n) @ x

// When an n-bit float is stored ina smaller m-bit register it is "unboxed"
// - only if it is a valid boxed NaN. Otherwise a canonical NaN value is stored.
// Unfortunately this is more complicated than it could be. See https://github.com/rems-project/sail/issues/471
val nan_unbox : forall 'n 'm, 'm in {16, 32, 64} & 'n >= 'm . (implicit('m), bits('n)) -> bits('m)
function nan_unbox(_retbits, x) = if 'n == 'm then x else (
  if x['n - 1 .. 'm] == ones() then x['m - 1 .. 0] else canonical_NaN()
)

/* **************************************************************** */
/* Floating point register file                                     */

register f0  : fregtype
register f1  : fregtype
register f2  : fregtype
register f3  : fregtype
register f4  : fregtype
register f5  : fregtype
register f6  : fregtype
register f7  : fregtype
register f8  : fregtype
register f9  : fregtype
register f10 : fregtype
register f11 : fregtype
register f12 : fregtype
register f13 : fregtype
register f14 : fregtype
register f15 : fregtype
register f16 : fregtype
register f17 : fregtype
register f18 : fregtype
register f19 : fregtype
register f20 : fregtype
register f21 : fregtype
register f22 : fregtype
register f23 : fregtype
register f24 : fregtype
register f25 : fregtype
register f26 : fregtype
register f27 : fregtype
register f28 : fregtype
register f29 : fregtype
register f30 : fregtype
register f31 : fregtype

function dirty_fd_context() -> unit = {
  assert(sys_enable_fdext());
  mstatus[FS] = extStatus_to_bits(Dirty);
  mstatus[SD] = 0b1;
}

function dirty_fd_context_if_present() -> unit = {
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if sys_enable_fdext() then dirty_fd_context()
}

function rF (r : regno) -> flenbits = {
  assert(sys_enable_fdext());
  let v : fregtype =
    match r {
      0 => f0,
      1 => f1,
      2 => f2,
      3 => f3,
      4 => f4,
      5 => f5,
      6 => f6,
      7 => f7,
      8 => f8,
      9 => f9,
      10 => f10,
      11 => f11,
      12 => f12,
      13 => f13,
      14 => f14,
      15 => f15,
      16 => f16,
      17 => f17,
      18 => f18,
      19 => f19,
      20 => f20,
      21 => f21,
      22 => f22,
      23 => f23,
      24 => f24,
      25 => f25,
      26 => f26,
      27 => f27,
      28 => f28,
      29 => f29,
      30 => f30,
      31 => f31,
      _  => {assert(false, "invalid floating point register number"); zero_freg}
    };
  fregval_from_freg(v)
}

function wF (r : regno, in_v : flenbits) -> unit = {
  assert(sys_enable_fdext());
  let v = fregval_into_freg(in_v);
  match r {
    0  => f0 = v,
    1  => f1 = v,
    2  => f2 = v,
    3  => f3 = v,
    4  => f4 = v,
    5  => f5 = v,
    6  => f6 = v,
    7  => f7 = v,
    8  => f8 = v,
    9  => f9 = v,
    10 => f10 = v,
    11 => f11 = v,
    12 => f12 = v,
    13 => f13 = v,
    14 => f14 = v,
    15 => f15 = v,
    16 => f16 = v,
    17 => f17 = v,
    18 => f18 = v,
    19 => f19 = v,
    20 => f20 = v,
    21 => f21 = v,
    22 => f22 = v,
    23 => f23 = v,
    24 => f24 = v,
    25 => f25 = v,
    26 => f26 = v,
    27 => f27 = v,
    28 => f28 = v,
    29 => f29 = v,
    30 => f30 = v,
    31 => f31 = v,
    _  => assert(false, "invalid floating point register number")
  };

  dirty_fd_context();

  if   get_config_print_reg()
  then
      /* TODO: will only print bits; should we print in floating point format? */
      print_reg("f" ^ dec_str(r) ^ " <- " ^ FRegStr(v));
}

function rF_bits(i: regidx) -> flenbits = rF(unsigned(i))

function wF_bits(i: regidx, data: flenbits) -> unit = {
  wF(unsigned(i)) = data
}

overload F = {rF_bits, wF_bits, rF, wF}

val rF_H : regidx -> bits(16)
function rF_H(i) = {
  assert(flen >= 16);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  nan_unbox(F(i))
}

val wF_H : (regidx, bits(16)) -> unit
function wF_H(i, data) = {
  assert(flen >= 16);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  F(i) = nan_box(data)
}

val rF_S : regidx -> bits(32)
function rF_S(i) = {
  assert(flen >= 32);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  nan_unbox(F(i))
}

val wF_S : (regidx, bits(32)) -> unit
function wF_S(i, data) = {
  assert(flen >= 32);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  F(i) = nan_box(data)
}

val rF_D : regidx -> bits(64)
function rF_D(i) = {
  assert(flen >= 64);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  F(i)
}

val wF_D : (regidx, bits(64)) -> unit
function wF_D(i, data) = {
  assert(flen >= 64);
  assert(sys_enable_fdext() & not(sys_enable_zfinx()));
  F(i) = data
}

overload F_H = { rF_H, wF_H }
overload F_S = { rF_S, wF_S }
overload F_D = { rF_D, wF_D }

val rF_or_X_H : regidx -> bits(16)
function rF_or_X_H(i) = {
  assert(flen >= 16);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_H(i)
  else X(i)[15..0]
}

val rF_or_X_S : regidx -> bits(32)
function rF_or_X_S(i) = {
  assert(flen >= 32);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_S(i)
  else X(i)[31..0]
}

val rF_or_X_D : regidx -> bits(64)
function rF_or_X_D(i) = {
  assert(flen >= 64);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_D(i)
  else if xlen >= 64
  then X(i)[63..0]
  else {
    assert(i[0] == bitzero);
    if i == zeros() then zeros() else X(i + 1) @ X(i)
  }
}

val wF_or_X_H : (regidx, bits(16)) -> unit
function wF_or_X_H(i, data) = {
  assert(flen >= 16);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_H(i) = data
  else X(i) = sign_extend(data)
}

val wF_or_X_S : (regidx, bits(32)) -> unit
function wF_or_X_S(i, data) = {
  assert(flen >= 32);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_S(i) = data
  else X(i) = sign_extend(data)
}

val wF_or_X_D : (regidx, bits(64)) -> unit
function wF_or_X_D(i, data) = {
  assert (flen >= 64);
  assert(sys_enable_fdext() != sys_enable_zfinx());
  if   sys_enable_fdext()
  then F_D(i) = data
  else if xlen >= 64
  then X(i) = sign_extend(data)
  else {
    assert (i[0] == bitzero);
    if i != zeros() then {
      X(i)     = data[31..0];
      X(i + 1) = data[63..32];
    }
  }
}

overload F_or_X_H = { rF_or_X_H, wF_or_X_H }
overload F_or_X_S = { rF_or_X_S, wF_or_X_S }
overload F_or_X_D = { rF_or_X_D, wF_or_X_D }

/* mappings for assembly */

val freg_name : regidx <-> string
mapping freg_name = {
    0b00000 <-> "ft0",
    0b00001 <-> "ft1",
    0b00010 <-> "ft2",
    0b00011 <-> "ft3",
    0b00100 <-> "ft4",
    0b00101 <-> "ft5",
    0b00110 <-> "ft6",
    0b00111 <-> "ft7",
    0b01000 <-> "fs0",
    0b01001 <-> "fs1",
    0b01010 <-> "fa0",
    0b01011 <-> "fa1",
    0b01100 <-> "fa2",
    0b01101 <-> "fa3",
    0b01110 <-> "fa4",
    0b01111 <-> "fa5",
    0b10000 <-> "fa6",
    0b10001 <-> "fa7",
    0b10010 <-> "fs2",
    0b10011 <-> "fs3",
    0b10100 <-> "fs4",
    0b10101 <-> "fs5",
    0b10110 <-> "fs6",
    0b10111 <-> "fs7",
    0b11000 <-> "fs8",
    0b11001 <-> "fs9",
    0b11010 <-> "fs10",
    0b11011 <-> "fs11",
    0b11100 <-> "ft8",
    0b11101 <-> "ft9",
    0b11110 <-> "ft10",
    0b11111 <-> "ft11"
}

val freg_or_reg_name : regidx <-> string
mapping freg_or_reg_name = {
  reg if sys_enable_fdext() <-> freg_name(reg) if sys_enable_fdext(),
  reg if sys_enable_zfinx() <-> reg_name(reg)  if sys_enable_zfinx()
}

/* **************************************************************** */
/* Floating Point CSR                                               */
/*     fflags    address 0x001    same as fcrs [4..0]               */
/*     frm       address 0x002    same as fcrs [7..5]               */
/*     fcsr      address 0x003                                      */


bitfield Fcsr : bits(32) = {
  FRM    : 7 .. 5,
  FFLAGS : 4 .. 0,
}

register fcsr : Fcsr

val write_fcsr : (bits(3), bits(5)) -> unit
function write_fcsr (frm, fflags) = {
  fcsr[FRM]    = frm;      /* Note: frm can be an illegal value, 101, 110, 111 */
  fcsr[FFLAGS] = fflags;
  dirty_fd_context_if_present();
}

/* OR flags into the fflags register. */
val accrue_fflags : (bits(5)) -> unit
function accrue_fflags(flags) = {
  let f = fcsr[FFLAGS] | flags;
  if  fcsr[FFLAGS] != f
  then {
    fcsr[FFLAGS] = f;
    dirty_fd_context_if_present();
  }
}
