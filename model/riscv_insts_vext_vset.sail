/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* ******************************************************************************* */
/* This file implements part of the vector extension.                              */
/* Chapter 6: Configuration-Setting Instructions                                   */
/* ******************************************************************************* */

mapping sew_flag : string <-> bits(3) = {
  "e8"    <-> 0b000,
  "e16"   <-> 0b001,
  "e32"   <-> 0b010,
  "e64"   <-> 0b011,

  "e128"   <-> 0b100,
  "e256"   <-> 0b101,
  "e512"   <-> 0b110,
  "e1024"   <-> 0b111,
}

mapping maybe_lmul_flag : string <-> bits(3) = {
  ""              <-> 0b000, /* m1 by default */
  sep() ^ "mf8"   <-> 0b101,
  sep() ^ "mf4"   <-> 0b110,
  sep() ^ "mf2"   <-> 0b111,
  sep() ^ "m1"    <-> 0b000,
  sep() ^ "m2"    <-> 0b001,
  sep() ^ "m4"    <-> 0b010,
  sep() ^ "m8"    <-> 0b011,

  sep() ^ "mf16"    <-> 0b100,
}

mapping maybe_ta_flag : string <-> bits(1) = {
  ""           <-> 0b0, /* tu by default */
  sep() ^ "ta" <-> 0b1,
  sep() ^ "tu" <-> 0b0
}

mapping maybe_ma_flag : string <-> bits(1) = {
  ""           <-> 0b0, /* mu by default */
  sep() ^ "ma" <-> 0b1,
  sep() ^ "mu" <-> 0b0
}

function get_avl(rd : regidx, rs1 : regidx) -> option(nat) = {
  if (rs1 != 0b00000) then { /* normal stripmining */
    let rs1_val = X(rs1);
    Some(unsigned(rs1_val));
  } else if (rd != 0b00000) then { /* set vl to VLMAX */
    Some(unsigned(ones(xlen)));
  } else { /* keep existing vl */
    None()
  }
}

function writeback_vset(vtype_new: xlenbits, vl_new : xlenbits) -> unit = {
  vtype.bits = vtype_new;
  vl = vl_new;

  if get_config_print_reg() then
    print_reg("CSR vtype <- " ^ BitStr(vtype.bits));
  if get_config_print_reg() then
    print_reg("CSR vl <- " ^ BitStr(vl));
  write_vstart(0);
  if get_config_print_reg() then
    print_reg("CSR vstart <- " ^ BitStr(vstart));
  dirty_v_context();
}

function writeback_vill() -> unit = writeback_vset(0b1 @ zeros(xlen - 1), zeros())

function process_vset(vtype_bits_new : xlenbits, AVL : option(nat), rd : regidx) -> Retired = {
  let vtype_new : Vtype = struct { bits = vtype_bits_new };

  let ELEN_pow      = get_elen_pow();
  let VLEN_pow      = get_vlen_pow();

  let LMUL_pow_new = signed(vtype_new[vlmul]);
  let SEW_pow_new  = unsigned(vtype_new[vsew]) + 3;
  let SEW_new = 2 ^ SEW_pow_new;

  let avl : nat = match AVL {
    None() => {
      let LMUL_pow  = get_lmul_pow();
      let SEW_pow   = get_sew_pow();
      if not(valid_vtype()) | (LMUL_pow_new - SEW_pow_new != LMUL_pow - SEW_pow) then {
        /* `vsetvl[i] x0, x0, ...` is only allowed when SEW/LMUL is unchanged */
        writeback_vill();
        return RETIRE_SUCCESS
      };

      unsigned(vl)
    },
    Some(avl) => avl
  };

  if  vtype_new[vill] == 0b1 |
      vtype_new[reserved] != zeros() |
      not(valid_eew_emul(SEW_new, LMUL_pow_new)) |
      SEW_pow_new > LMUL_pow_new + ELEN_pow
  then {
    /* Note: Implementations can set vill or trap if the vtype setting is not supported.
     * TODO: configuration support for both solutions
     */
    writeback_vill();
    return RETIRE_SUCCESS
  };

  let VLMAX = 2 ^ (VLEN_pow + LMUL_pow_new - SEW_pow_new);

  /* set vl according to VLMAX and AVL */
  let vl_new = if avl <= VLMAX then to_bits(xlen, avl)
        else if avl < 2 * VLMAX then to_bits(xlen, VLMAX)
        else to_bits(xlen, VLMAX);
  /* Note: ceil(AVL / 2) <= vl <= VLMAX when VLMAX < AVL < (2 * VLMAX)
    * TODO: configuration support for either using ceil(AVL / 2) or VLMAX
    */
  X(rd) = vl_new;

  writeback_vset(vtype_new.bits, vl_new);
  RETIRE_SUCCESS
}

/* ****************************** vsetvl ******************************* */
union clause ast = VSETVL_TYPE : (regidx, regidx, regidx)

mapping clause encdec = VSETVL_TYPE(rs2, rs1, rd) if extensionEnabled(Ext_V)
  <-> 0b1000000 @ rs2 @ rs1 @ 0b111 @ rd @ 0b1010111 if extensionEnabled(Ext_V)

function clause execute VSETVL_TYPE(rs2, rs1, rd) = process_vset(X(rs2), get_avl(rd, rs1), rd)

mapping clause assembly = VSETVL_TYPE(rs2, rs1, rd)
  <-> "vsetvl" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)

/* ****************************** vsetvli ******************************* */
union clause ast = VSETVLI_TYPE : (bits(1), bits(1), bits(3), bits(3), regidx, regidx)

mapping clause encdec = VSETVLI_TYPE(ma, ta, sew, lmul, rs1, rd) if extensionEnabled(Ext_V)
  <-> 0b0000 @ ma @ ta @ sew @ lmul @ rs1 @ 0b111 @ rd @ 0b1010111 if extensionEnabled(Ext_V)

function clause execute VSETVLI_TYPE(ma, ta, sew, lmul, rs1, rd) =
  process_vset(0b0 @ zeros(xlen - 9) @ ma @ ta @ sew @ lmul, get_avl(rd, rs1), rd)

mapping clause assembly = VSETVLI_TYPE(ma, ta, sew, lmul, rs1, rd)
  <-> "vsetvli" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ sew_flag(sew) ^ maybe_lmul_flag(lmul) ^ maybe_ta_flag(ta) ^ maybe_ma_flag(ma)

/* ********************************* vsetivli ************************************ */
union clause ast = VSETIVLI_TYPE : ( bits(1), bits(1), bits(3), bits(3), regidx, regidx)

mapping clause encdec = VSETIVLI_TYPE(ma, ta, sew, lmul, uimm, rd) if extensionEnabled(Ext_V)
  <-> 0b1100 @ ma @ ta @ sew @ lmul @ uimm @ 0b111 @ rd @ 0b1010111 if extensionEnabled(Ext_V)

function clause execute VSETIVLI_TYPE(ma, ta, sew, lmul, uimm, rd) =
  process_vset(0b0 @ zeros(xlen - 9) @ ma @ ta @ sew @ lmul, Some(unsigned(uimm)), rd)

mapping clause assembly = VSETIVLI_TYPE(ma, ta, sew, lmul, uimm, rd)
  <-> "vsetivli" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_5(uimm) ^ sep() ^ sew_flag(sew) ^ maybe_lmul_flag(lmul) ^ maybe_ta_flag(ta) ^ maybe_ma_flag(ma)
