/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* ****************************************************************** */
/* This file specifies the instructions in the 'Zicsr' extension.     */
/* ****************************************************************** */
union clause ast = CSR  : (csreg, regidx, regidx, bool, csrop)

mapping encdec_csrop : csrop <-> bits(2) = {
  CSRRW <-> 0b01,
  CSRRS <-> 0b10,
  CSRRC <-> 0b11
}

mapping clause encdec = CSR(csr, rs1, rd, is_imm, op)
  <-> csr @ encdec_reg(rs1) @ bool_bits(is_imm) @ encdec_csrop(op) @ encdec_reg(rd) @ 0b1110011

val handle_csr_op : (
  csreg,
  regidx,
  regidx,
  bool,
  csrop,
  bool,
  bool,
) -> Retired

function clause execute CSR(csr, rs1, rd, is_imm, op) = {
  // CSRRW[I] always writes. CSRRS[I] and CSRRC[I] write if the
  // source register (or immediate) is not x0 (or 0).
  let isWrite = op == CSRRW | regidx_bits(rs1) != zeros();
  // CSRRS[I] and CSRRC[I] always read. CSRRW[I] reads if the destination
  // register is not x0.
  let isRead = op != CSRRW | regidx_bits(rd) != zeros();

  if not(check_CSR(csr, cur_privilege(), isWrite))
  then { handle_illegal(); RETIRE_FAIL }
  else {
    match ext_check_CSR(csr, cur_privilege(), isWrite, op, is_imm) {
      Some(err) => {ext_check_CSR_fail(err); RETIRE_FAIL},
      None() => handle_csr_op(csr, rs1, rd, is_imm, op, isWrite, isRead),
    }
  }
}

function default_handle_csr_op(
  csr : csreg,
  rs1 : regidx,
  rd : regidx,
  is_imm : bool,
  op : csrop,
  isWrite : bool,
  isRead : bool,
) -> Retired = {
  let is_CSRRW_write = isWrite & (op == CSRRW) & not(is_imm);
  let write_val : xlenbits = if is_imm then zero_extend(regidx_bits(rs1)) else X(rs1);
  // Reading CSRs can have side effects and is not done in certain cases.
  let csr_val = if isRead then read_CSR(csr, write_val) else zeros();
  if isWrite then {
    let new_val : xlenbits = match op {
      CSRRW => write_val,
      CSRRS => csr_val | write_val,
      CSRRC => csr_val & ~(write_val)
    };
    let _ = write_CSR(csr, new_val);
  };
  X(rd) = csr_val;
  RETIRE_SUCCESS
}

mapping csr_mnemonic : csrop <-> string = {
  CSRRW <-> "csrrw",
  CSRRS <-> "csrrs",
  CSRRC <-> "csrrc"
}

mapping clause assembly = CSR(csr, Regidx(rs1_bits), rd, true, op)
  <-> csr_mnemonic(op) ^ "i" ^ spc() ^ reg_name(rd)  ^ sep() ^ csr_name_map(csr) ^ sep() ^ hex_bits_5(rs1_bits)
mapping clause assembly = CSR(csr, rs1, rd, false, op)
  <-> csr_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ csr_name_map(csr) ^ sep() ^ reg_name(rs1)
