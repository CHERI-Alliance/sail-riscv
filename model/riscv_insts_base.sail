/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* ****************************************************************** */
/* This file specifies the instructions in the base integer set.      */

function clause extensionEnabled(Ext_C) = misa[C] == 0b1
function clause extensionEnabled(Ext_Zca) = extensionEnabled(Ext_C)

/* ****************************************************************** */
union clause ast = UTYPE : (bits(20), regidx, uop)

mapping encdec_uop : uop <-> bits(7) = {
  RISCV_LUI   <-> 0b0110111,
  RISCV_AUIPC <-> 0b0010111
}

mapping clause encdec = UTYPE(imm, rd, op)
  <-> imm @ encdec_reg(rd) @ encdec_uop(op)

function clause execute (UTYPE(imm, rd, op)) = {
  let off : xlenbits = sign_extend(imm @ 0x000);
  X(rd) = match op {
    RISCV_LUI   => off,
    RISCV_AUIPC => get_arch_pc() + off
  };
  RETIRE_SUCCESS
}

mapping utype_mnemonic : uop <-> string = {
  RISCV_LUI   <-> "lui",
  RISCV_AUIPC <-> "auipc"
}

mapping clause assembly = UTYPE(imm, rd, op)
  <-> utype_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_20(imm)

/* ****************************************************************** */
union clause ast = RISCV_JAL : (bits(21), regidx)

mapping clause encdec = RISCV_JAL(imm_19 @ imm_7_0 @ imm_8 @ imm_18_13 @ imm_12_9 @ 0b0, rd)
  <-> imm_19 : bits(1) @ imm_18_13 : bits(6) @ imm_12_9 : bits(4) @ imm_8 : bits(1) @ imm_7_0 : bits(8) @ encdec_reg(rd) @ 0b1101111

/*
ideally we want some syntax like

mapping clause encdec = RISCV_JAL(imm @ 0b0, rd) <-> imm[19] @ imm[9..0] @ imm[10] @ imm[18..11] @ encdec_reg(rd) @ 0b1101111

match bv {
  imm[19] @ imm[9..0] @ imm[10] @ imm[18..11] -> imm @ 0b0
}

but this is difficult
*/

function clause execute (RISCV_JAL(imm, rd)) = {
  let target = PC + sign_extend(imm);
  /* Extensions get the first checks on the prospective target address. */
  match ext_control_check_pc(target) {
    Ext_ControlAddr_Error(e) => {
      ext_handle_control_check_error(e);
      RETIRE_FAIL
    },
    Ext_ControlAddr_OK(target) => {
      /* Perform standard alignment check */
      let target_bits = virtaddr_bits(target);
      if bit_to_bool(target_bits[1]) & not(extensionEnabled(Ext_Zca)) then {
        handle_mem_exception(target, E_Fetch_Addr_Align());
        RETIRE_FAIL
      } else {
        X(rd) = get_next_pc();
        set_next_pc(target_bits);
        RETIRE_SUCCESS
      }
    }
  }
}

/* TODO: handle 2-byte-alignment in mappings */

mapping clause assembly = RISCV_JAL(imm, rd)
  <-> "jal" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_21(imm)

/* ****************************************************************** */
union clause ast = RISCV_JALR : (bits(12), regidx, regidx)

mapping clause encdec = RISCV_JALR(imm, rs1, rd)
  <-> imm @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b1100111

mapping clause assembly = RISCV_JALR(imm, rs1, rd)
  <-> "jalr" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_12(imm) ^ "(" ^ reg_name(rs1) ^ ")"

/* see riscv_jalr_seq.sail or riscv_jalr_rmem.sail for the execute clause. */

/* ****************************************************************** */
union clause ast = BTYPE : (bits(13), regidx, regidx, bop)

mapping encdec_bop : bop <-> bits(3) = {
  RISCV_BEQ  <-> 0b000,
  RISCV_BNE  <-> 0b001,
  RISCV_BLT  <-> 0b100,
  RISCV_BGE  <-> 0b101,
  RISCV_BLTU <-> 0b110,
  RISCV_BGEU <-> 0b111
}

mapping clause encdec = BTYPE(imm7_6 @ imm5_0 @ imm7_5_0 @ imm5_4_1 @ 0b0, rs2, rs1, op)
  <-> imm7_6 : bits(1) @ imm7_5_0 : bits(6) @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_bop(op) @ imm5_4_1 : bits(4) @ imm5_0 : bits(1) @ 0b1100011

function clause execute (BTYPE(imm, rs2, rs1, op)) = {
  let taken : bool = match op {
    RISCV_BEQ  => X(rs1) == X(rs2),
    RISCV_BNE  => X(rs1) != X(rs2),
    RISCV_BLT  => X(rs1) <_s X(rs2),
    RISCV_BGE  => X(rs1) >=_s X(rs2),
    RISCV_BLTU => X(rs1) <_u X(rs2),
    RISCV_BGEU => X(rs1) >=_u X(rs2)
  };
  if taken then {
    let target = PC + sign_extend(imm);
    /* Extensions get the first checks on the prospective target address. */
    match ext_control_check_pc(target) {
      Ext_ControlAddr_Error(e) => {
        ext_handle_control_check_error(e);
        RETIRE_FAIL
      },
      Ext_ControlAddr_OK(target) => {
        let target_bits = virtaddr_bits(target);
        if bit_to_bool(target_bits[1]) & not(extensionEnabled(Ext_Zca)) then {
          handle_mem_exception(target, E_Fetch_Addr_Align());
          RETIRE_FAIL
        } else {
          set_next_pc(target_bits);
          RETIRE_SUCCESS
        }
      }
    }
  } else RETIRE_SUCCESS
}

mapping btype_mnemonic : bop <-> string = {
  RISCV_BEQ  <-> "beq",
  RISCV_BNE  <-> "bne",
  RISCV_BLT  <-> "blt",
  RISCV_BGE  <-> "bge",
  RISCV_BLTU <-> "bltu",
  RISCV_BGEU <-> "bgeu"
}

mapping clause assembly = BTYPE(imm, rs2, rs1, op)
  <-> btype_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_13(imm)

/* ****************************************************************** */
union clause ast = ITYPE : (bits(12), regidx, regidx, iop)

mapping encdec_iop : iop <-> bits(3) = {
  RISCV_ADDI  <-> 0b000,
  RISCV_SLTI  <-> 0b010,
  RISCV_SLTIU <-> 0b011,
  RISCV_ANDI  <-> 0b111,
  RISCV_ORI   <-> 0b110,
  RISCV_XORI  <-> 0b100
}

mapping clause encdec = ITYPE(imm, rs1, rd, op)
  <-> imm @ encdec_reg(rs1) @ encdec_iop(op) @ encdec_reg(rd) @ 0b0010011

function clause execute (ITYPE (imm, rs1, rd, op)) = {
  let immext : xlenbits = sign_extend(imm);
  X(rd) = match op {
    RISCV_ADDI  => X(rs1) + immext,
    RISCV_SLTI  => zero_extend(bool_to_bits(X(rs1) <_s immext)),
    RISCV_SLTIU => zero_extend(bool_to_bits(X(rs1) <_u immext)),
    RISCV_ANDI  => X(rs1) & immext,
    RISCV_ORI   => X(rs1) | immext,
    RISCV_XORI  => X(rs1) ^ immext
  };
  RETIRE_SUCCESS
}

mapping itype_mnemonic : iop <-> string = {
  RISCV_ADDI  <-> "addi",
  RISCV_SLTI  <-> "slti",
  RISCV_SLTIU <-> "sltiu",
  RISCV_XORI  <-> "xori",
  RISCV_ORI   <-> "ori",
  RISCV_ANDI  <-> "andi"
}

mapping clause assembly = ITYPE(imm, rs1, rd, op)
  <-> itype_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_12(imm)

/* ****************************************************************** */
union clause ast = SHIFTIOP : (bits(6), regidx, regidx, sop)

mapping encdec_sop : sop <-> bits(3) = {
  RISCV_SLLI <-> 0b001,
  RISCV_SRLI <-> 0b101,
  RISCV_SRAI <-> 0b101
}

mapping clause encdec = SHIFTIOP(shamt, rs1, rd, RISCV_SLLI) if xlen == 64 | shamt[5] == bitzero <-> 0b000000 @ shamt @ encdec_reg(rs1) @ 0b001 @ encdec_reg(rd) @ 0b0010011 if xlen == 64 | shamt[5] == bitzero
mapping clause encdec = SHIFTIOP(shamt, rs1, rd, RISCV_SRLI) if xlen == 64 | shamt[5] == bitzero <-> 0b000000 @ shamt @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0010011 if xlen == 64 | shamt[5] == bitzero
mapping clause encdec = SHIFTIOP(shamt, rs1, rd, RISCV_SRAI) if xlen == 64 | shamt[5] == bitzero <-> 0b010000 @ shamt @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0010011 if xlen == 64 | shamt[5] == bitzero

function clause execute (SHIFTIOP(shamt, rs1, rd, op)) = {
  // The decoder guard ensures that shamt[5] = 0 for RV32.
  X(rd) = match op {
    RISCV_SLLI => X(rs1) << shamt,
    RISCV_SRLI => X(rs1) >> shamt,
    RISCV_SRAI => shift_bits_right_arith(X(rs1), shamt),
  };
  RETIRE_SUCCESS
}

mapping shiftiop_mnemonic : sop <-> string = {
  RISCV_SLLI <-> "slli",
  RISCV_SRLI <-> "srli",
  RISCV_SRAI <-> "srai"
}

mapping clause assembly = SHIFTIOP(shamt, rs1, rd, op)
  <-> shiftiop_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_6(shamt)

/* ****************************************************************** */
union clause ast = RTYPE : (regidx, regidx, regidx, rop)

mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_ADD)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SLT)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b010 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SLTU) <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b011 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_AND)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b111 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_OR)   <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b110 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_XOR)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b100 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SLL)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b001 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SRL)  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SUB)  <-> 0b0100000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0110011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_SRA)  <-> 0b0100000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0110011

function clause execute (RTYPE(rs2, rs1, rd, op)) = {
  X(rd) = match op {
    RISCV_ADD  => X(rs1) + X(rs2),
    RISCV_SLT  => zero_extend(bool_to_bits(X(rs1) <_s X(rs2))),
    RISCV_SLTU => zero_extend(bool_to_bits(X(rs1) <_u X(rs2))),
    RISCV_AND  => X(rs1) & X(rs2),
    RISCV_OR   => X(rs1) | X(rs2),
    RISCV_XOR  => X(rs1) ^ X(rs2),
    RISCV_SLL  => X(rs1) << X(rs2)[log2_xlen - 1 .. 0],
    RISCV_SRL  => X(rs1) >> X(rs2)[log2_xlen - 1 .. 0],
    RISCV_SUB  => X(rs1) - X(rs2),
    RISCV_SRA  => shift_bits_right_arith(X(rs1), X(rs2)[log2_xlen - 1 .. 0]),
  };
  RETIRE_SUCCESS
}

mapping rtype_mnemonic : rop <-> string = {
  RISCV_ADD  <-> "add",
  RISCV_SLT  <-> "slt",
  RISCV_SLTU <-> "sltu",
  RISCV_AND  <-> "and",
  RISCV_OR   <-> "or",
  RISCV_XOR  <-> "xor",
  RISCV_SLL  <-> "sll",
  RISCV_SRL  <-> "srl",
  RISCV_SUB  <-> "sub",
  RISCV_SRA  <-> "sra"
}

mapping clause assembly = RTYPE(rs2, rs1, rd, op)
  <-> rtype_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)

/* ****************************************************************** */
union clause ast = LOAD : (bits(12), regidx, regidx, bool, word_width, bool, bool)

/* unsigned loads are only present for widths strictly less than xlen,
   signed loads also present for widths equal to xlen */
mapping clause encdec = LOAD(imm, rs1, rd, is_unsigned, size, false, false)                        if (size_bytes(size) < xlen_bytes) | (not(is_unsigned) & size_bytes(size) <= xlen_bytes)
  <-> imm @ encdec_reg(rs1) @ bool_bits(is_unsigned) @ size_enc(size) @ encdec_reg(rd) @ 0b0000011 if (size_bytes(size) < xlen_bytes) | (not(is_unsigned) & size_bytes(size) <= xlen_bytes)

val extend_value : forall 'n, 0 < 'n <= xlen. (bool, bits('n)) -> xlenbits
function extend_value(is_unsigned, value) = if is_unsigned then zero_extend(value) else sign_extend(value)

function is_aligned(vaddr : xlenbits, width : word_width) -> bool =
  match width {
    BYTE   => true,
    HALF   => vaddr[0..0] == zeros(),
    WORD   => vaddr[1..0] == zeros(),
    DOUBLE => vaddr[2..0] == zeros(),
  }

// Return true if the address is misaligned and we don't support misaligned access.
function check_misaligned(vaddr : virtaddr, width : word_width) -> bool =
  not(plat_enable_misaligned_access()) & not(is_aligned(virtaddr_bits(vaddr), width))

function clause execute (LOAD(imm, rs1, rd, is_unsigned, width, aq, rl)) = {
  let offset : xlenbits = sign_extend(imm);
  let width_bytes = size_bytes(width);

  // This is checked during decoding.
  assert(width_bytes <= xlen_bytes);

  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
  match ext_data_get_addr(rs1, offset, Read(Data), width_bytes) {
    Ext_DataAddr_Error(e)  => { ext_handle_data_check_error(e); RETIRE_FAIL },
    Ext_DataAddr_OK(vaddr) => {
      if   check_misaligned(vaddr, width)
      then { handle_mem_exception(vaddr, E_Load_Addr_Align()); RETIRE_FAIL }
      else match vmem_read(Read(Data), vaddr, width_bytes, aq, rl, false) {
        Ok(result)    => { X(rd) = extend_value(is_unsigned, result); RETIRE_SUCCESS },
        Err(vaddr, e, _) => { handle_mem_exception(vaddr, e); RETIRE_FAIL }
      }
    },
  }
}

val maybe_aq : bool <-> string
mapping maybe_aq = {
  true  <-> ".aq",
  false <-> ""
}

val maybe_rl : bool <-> string
mapping maybe_rl = {
  true  <-> ".rl",
  false <-> ""
}

val maybe_u : bool <-> string
mapping maybe_u = {
  true  <-> "u",
  false <-> ""
}

mapping clause assembly = LOAD(imm, rs1, rd, is_unsigned, size, aq, rl)
  <-> "l" ^ size_mnemonic(size) ^ maybe_u(is_unsigned) ^ maybe_aq(aq) ^ maybe_rl(rl) ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_12(imm) ^ "(" ^ reg_name(rs1) ^ ")"

/* ****************************************************************** */
union clause ast = STORE : (bits(12), regidx, regidx, word_width, bool, bool)

mapping clause encdec = STORE(imm7 @ imm5, rs2, rs1, size, false, false)                                     if size_bytes(size) <= xlen_bytes
  <-> imm7 : bits(7) @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b0 @ size_enc(size) @ imm5 : bits(5) @ 0b0100011 if size_bytes(size) <= xlen_bytes

/* NOTE: Currently, we only EA if address translation is successful.
   This may need revisiting. */
function clause execute (STORE(imm, rs2, rs1, width, aq, rl)) = {
  let offset : xlenbits = sign_extend(imm);
  let width_bytes = size_bytes(width);

  // This is checked during decoding.
  assert(width_bytes <= xlen_bytes);

  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
  match ext_data_get_addr(rs1, offset, Write(Data), width_bytes) {
    Ext_DataAddr_Error(e)  => { ext_handle_data_check_error(e); RETIRE_FAIL },
    Ext_DataAddr_OK(vaddr) => {
      if   check_misaligned(vaddr, width)
      then { handle_mem_exception(vaddr, E_SAMO_Addr_Align()); RETIRE_FAIL }
      else match vmem_write_translate(vaddr, width_bytes, Write(Data), aq, rl, false) {
        Err(vaddr, e, _) => { handle_mem_exception(vaddr, e); RETIRE_FAIL },
        Ok(state)     => {
          let rs2_val = X(rs2);
          match vmem_write_value(state, rs2_val[width_bytes * 8 - 1 .. 0]) {
            Ok(true)  => RETIRE_SUCCESS,
            Ok(false) => internal_error(__FILE__, __LINE__, "store got false from mem_write_value"),
            Err(vaddr, e, _) => { handle_mem_exception(vaddr, e); RETIRE_FAIL }
          }
        }
      }
    }
  }
}

mapping clause assembly = STORE(imm, rs2, rs1, size, aq, rl)
  <-> "s" ^ size_mnemonic(size) ^ maybe_aq(aq) ^ maybe_rl(rl) ^ spc() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_12(imm) ^ opt_spc() ^ "(" ^ opt_spc() ^ reg_name(rs1) ^ opt_spc() ^ ")"

/* ****************************************************************** */
union clause ast = ADDIW : (bits(12), regidx, regidx)

mapping clause encdec = ADDIW(imm, rs1, rd)
      if xlen == 64
  <-> imm @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0011011
      if xlen == 64

function clause execute (ADDIW(imm, rs1, rd)) = {
  let result = X(rs1) + sign_extend(imm);
  X(rd) = sign_extend(result[31..0]);
  RETIRE_SUCCESS
}

mapping clause assembly = ADDIW(imm, rs1, rd)
      if xlen == 64
  <-> "addiw" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_12(imm)
      if xlen == 64

/* ****************************************************************** */
union clause ast = RTYPEW : (regidx, regidx, regidx, ropw)

mapping clause encdec = RTYPEW(rs2, rs1, rd, RISCV_ADDW)
      if xlen == 64
  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0111011
      if xlen == 64
mapping clause encdec = RTYPEW(rs2, rs1, rd, RISCV_SUBW)
      if xlen == 64
  <-> 0b0100000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b0111011
      if xlen == 64
mapping clause encdec = RTYPEW(rs2, rs1, rd, RISCV_SLLW)
      if xlen == 64
  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b001 @ encdec_reg(rd) @ 0b0111011
      if xlen == 64
mapping clause encdec = RTYPEW(rs2, rs1, rd, RISCV_SRLW)
      if xlen == 64
  <-> 0b0000000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0111011
      if xlen == 64
mapping clause encdec = RTYPEW(rs2, rs1, rd, RISCV_SRAW)
      if xlen == 64
  <-> 0b0100000 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0111011
      if xlen == 64

function clause execute (RTYPEW(rs2, rs1, rd, op)) = {
  let rs1_val = X(rs1)[31..0];
  let rs2_val = X(rs2)[31..0];
  let result : bits(32) = match op {
    RISCV_ADDW => rs1_val + rs2_val,
    RISCV_SUBW => rs1_val - rs2_val,
    RISCV_SLLW => rs1_val << rs2_val[4..0],
    RISCV_SRLW => rs1_val >> rs2_val[4..0],
    RISCV_SRAW => shift_bits_right_arith(rs1_val, rs2_val[4..0]),
  };
  X(rd) = sign_extend(result);
  RETIRE_SUCCESS
}

mapping rtypew_mnemonic : ropw <-> string = {
  RISCV_ADDW <-> "addw",
  RISCV_SUBW <-> "subw",
  RISCV_SLLW <-> "sllw",
  RISCV_SRLW <-> "srlw",
  RISCV_SRAW <-> "sraw"
}

mapping clause assembly = RTYPEW(rs2, rs1, rd, op)
      if xlen == 64
  <-> rtypew_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)
      if xlen == 64

/* ****************************************************************** */
union clause ast = SHIFTIWOP : (bits(5), regidx, regidx, sopw)

mapping clause encdec = SHIFTIWOP(shamt, rs1, rd, RISCV_SLLIW)
      if xlen == 64
  <-> 0b0000000 @ shamt @ encdec_reg(rs1) @ 0b001 @ encdec_reg(rd) @ 0b0011011
      if xlen == 64
mapping clause encdec = SHIFTIWOP(shamt, rs1, rd, RISCV_SRLIW)
      if xlen == 64
  <-> 0b0000000 @ shamt @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0011011
      if xlen == 64
mapping clause encdec = SHIFTIWOP(shamt, rs1, rd, RISCV_SRAIW)
      if xlen == 64
  <-> 0b0100000 @ shamt @ encdec_reg(rs1) @ 0b101 @ encdec_reg(rd) @ 0b0011011
      if xlen == 64

function clause execute (SHIFTIWOP(shamt, rs1, rd, op)) = {
  let rs1_val = X(rs1)[31..0];
  let result : bits(32) = match op {
    RISCV_SLLIW => rs1_val << shamt,
    RISCV_SRLIW => rs1_val >> shamt,
    RISCV_SRAIW => shift_bits_right_arith(rs1_val, shamt),
  };
  X(rd) = sign_extend(result);
  RETIRE_SUCCESS
}

mapping shiftiwop_mnemonic : sopw <-> string = {
  RISCV_SLLIW <-> "slliw",
  RISCV_SRLIW <-> "srliw",
  RISCV_SRAIW <-> "sraiw"
}

mapping clause assembly = SHIFTIWOP(shamt, rs1, rd, op)
      if xlen == 64
  <-> shiftiwop_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_5(shamt)
      if xlen == 64

/* ****************************************************************** */
union clause ast = FENCE : (bits(4), bits(4))

mapping clause encdec = FENCE(pred, succ)
  <-> 0b0000 @ pred @ succ @ 0b00000 @ 0b000 @ 0b00000 @ 0b0001111

function effective_fence_set(set : bits(4), fiom : bool) -> bits(4) = {
  // The bits are IORW. If FIOM is set then I implies R and O implies W.
  if fiom then {
    set[3 .. 2] @ (set[1 .. 0] | set[3 .. 2])
  } else set
}

function clause execute (FENCE(pred, succ)) = {
  // If the FIOM bit in menvcfg/senvcfg is set then the I/O bits can imply R/W.
  let fiom = is_fiom_active();
  let pred = effective_fence_set(pred, fiom);
  let succ = effective_fence_set(succ, fiom);

  match (pred, succ) {
    (_ : bits(2) @ 0b11, _ : bits(2) @ 0b11) => sail_barrier(Barrier_RISCV_rw_rw),
    (_ : bits(2) @ 0b10, _ : bits(2) @ 0b11) => sail_barrier(Barrier_RISCV_r_rw),
    (_ : bits(2) @ 0b10, _ : bits(2) @ 0b10) => sail_barrier(Barrier_RISCV_r_r),
    (_ : bits(2) @ 0b11, _ : bits(2) @ 0b01) => sail_barrier(Barrier_RISCV_rw_w),
    (_ : bits(2) @ 0b01, _ : bits(2) @ 0b01) => sail_barrier(Barrier_RISCV_w_w),
    (_ : bits(2) @ 0b01, _ : bits(2) @ 0b11) => sail_barrier(Barrier_RISCV_w_rw),
    (_ : bits(2) @ 0b11, _ : bits(2) @ 0b10) => sail_barrier(Barrier_RISCV_rw_r),
    (_ : bits(2) @ 0b10, _ : bits(2) @ 0b01) => sail_barrier(Barrier_RISCV_r_w),
    (_ : bits(2) @ 0b01, _ : bits(2) @ 0b10) => sail_barrier(Barrier_RISCV_w_r),

    (_ : bits(4)       , _ : bits(2) @ 0b00) => (),
    (_ : bits(2) @ 0b00, _ : bits(4)       ) => (),

    _ => { print("FIXME: unsupported fence");
           () }
  };
  RETIRE_SUCCESS
}

mapping bit_maybe_r : bits(1) <-> string = {
  0b1 <-> "r",
  0b0 <-> ""
}

mapping bit_maybe_w : bits(1) <-> string = {
  0b1 <-> "w",
  0b0 <-> ""
}

mapping bit_maybe_i : bits(1) <-> string = {
  0b1 <-> "i",
  0b0 <-> ""
}

mapping bit_maybe_o : bits(1) <-> string = {
  0b1 <-> "o",
  0b0 <-> ""
}

mapping fence_bits : bits(4) <-> string = {
  i : bits(1) @ o : bits(1) @ r : bits(1) @ w : bits(1) <-> bit_maybe_i(i) ^ bit_maybe_o(o) ^ bit_maybe_r(r) ^ bit_maybe_w(w)
}

mapping clause assembly = FENCE(pred, succ)
  <-> "fence" ^ spc() ^ fence_bits(pred) ^ sep() ^ fence_bits(succ)

/* ****************************************************************** */
union clause ast = FENCE_TSO : (bits(4), bits(4))

mapping clause encdec = FENCE_TSO(pred, succ)
  <-> 0b1000 @ pred @ succ @ 0b00000 @ 0b000 @ 0b00000 @ 0b0001111

function clause execute (FENCE_TSO(pred, succ)) = {
  match (pred, succ) {
    (_ : bits(2) @ 0b11, _ : bits(2) @ 0b11) => sail_barrier(Barrier_RISCV_tso),
    (_ : bits(2) @ 0b00, _ : bits(2) @ 0b00) => (),

    _ => { print("FIXME: unsupported fence");
           () }
  };
  RETIRE_SUCCESS
}

mapping clause assembly = FENCE_TSO(pred, succ)
  <-> "fence.tso" ^ spc() ^ fence_bits(pred) ^ sep() ^ fence_bits(succ)

/* ****************************************************************** */
union clause ast = ECALL : unit

mapping clause encdec = ECALL()
  <-> 0b000000000000 @ 0b00000 @ 0b000 @ 0b00000 @ 0b1110011

function clause execute ECALL() = {
  let t : sync_exception =
    struct { trap = match (cur_privilege()) {
                      User       => E_U_EnvCall(),
                      Supervisor => E_S_EnvCall(),
                      Machine    => E_M_EnvCall()
                    },
             excinfo = (None() : option(xlenbits)),
             ext     = None() };
  set_next_pc(exception_handler(cur_privilege(), CTL_TRAP(t), PC));
  RETIRE_FAIL
}

mapping clause assembly = ECALL() <-> "ecall"

/* ****************************************************************** */
union clause ast = MRET : unit

mapping clause encdec = MRET()
  <-> 0b0011000 @ 0b00010 @ 0b00000 @ 0b000 @ 0b00000 @ 0b1110011

function clause execute MRET() = {
  if   cur_privilege() != Machine
  then { handle_illegal(); RETIRE_FAIL }
  else if not(ext_check_xret_priv (Machine))
  then { ext_fail_xret_priv(); RETIRE_FAIL }
  else {
    set_next_pc(exception_handler(cur_privilege(), CTL_MRET(), PC));
    RETIRE_SUCCESS
  }
}

mapping clause assembly = MRET() <-> "mret"

/* ****************************************************************** */
union clause ast = SRET : unit

mapping clause encdec = SRET()
  <-> 0b0001000 @ 0b00010 @ 0b00000 @ 0b000 @ 0b00000 @ 0b1110011

function clause execute SRET() = {
  let sret_illegal : bool = match cur_privilege() {
    User       => true,
    Supervisor => not(extensionEnabled(Ext_S)) | mstatus[TSR] == 0b1,
    Machine    => not(extensionEnabled(Ext_S))
  };
  if   sret_illegal
  then { handle_illegal(); RETIRE_FAIL }
  else if not(ext_check_xret_priv (Supervisor))
  then { ext_fail_xret_priv(); RETIRE_FAIL }
  else {
    set_next_pc(exception_handler(cur_privilege(), CTL_SRET(), PC));
    RETIRE_SUCCESS
  }
}

mapping clause assembly = SRET() <-> "sret"

/* ****************************************************************** */
union clause ast = EBREAK : unit

mapping clause encdec = EBREAK()
  <-> 0b000000000001 @ 0b00000 @ 0b000 @ 0b00000 @ 0b1110011

function clause execute EBREAK() = {
  handle_mem_exception(virtaddr(PC), E_Breakpoint());
  RETIRE_FAIL
}

mapping clause assembly = EBREAK() <-> "ebreak"

/* ****************************************************************** */
union clause ast = WFI : unit

mapping clause encdec = WFI()
  <-> 0b000100000101 @ 0b00000 @ 0b000 @ 0b00000 @ 0b1110011

function clause execute WFI() =
  match cur_privilege() {
    Machine    => { platform_wfi(); RETIRE_SUCCESS },
    Supervisor => if   mstatus[TW] == 0b1
                  then { handle_illegal(); RETIRE_FAIL }
                  else { platform_wfi(); RETIRE_SUCCESS },
    User       => { handle_illegal(); RETIRE_FAIL }
  }

mapping clause assembly = WFI() <-> "wfi"

/* ****************************************************************** */
union clause ast = SFENCE_VMA : (regidx, regidx)

mapping clause encdec = SFENCE_VMA(rs1, rs2)
  <-> 0b0001001 @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b000 @ 0b00000 @ 0b1110011

function clause execute SFENCE_VMA(rs1, rs2) = {
  let addr = if rs1 != zreg then Some(X(rs1)) else None();
  // Note, the Sail model does not currently support Sv32 & SXLEN=32 on RV64.
  // In that case this asidlen would be incorrect because the maximum asidlen
  // is 9 but we always set it to 16 for RV64.
  let asid = if rs2 != zreg then Some((X(rs2) & zero_extend(ones(sys_asid_bits())))[asidlen - 1 .. 0]) else None();
  match cur_privilege() {
    User       => { handle_illegal(); RETIRE_FAIL },
    Supervisor => match mstatus[TVM] {
                    0b1 => { handle_illegal(); RETIRE_FAIL },
                    0b0 => { flush_TLB(asid, addr); RETIRE_SUCCESS },
                  },
    Machine    => { flush_TLB(asid, addr); RETIRE_SUCCESS }
  }
}

mapping clause assembly = SFENCE_VMA(rs1, rs2)
  <-> "sfence.vma" ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2)
