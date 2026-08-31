/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

type log2_cap_size : Int = if xlen == 32 then log2_cap_size_32 else log2_cap_size_64
let  log2_cap_size = sizeof(log2_cap_size)

type cap_sd_perms_width : Int = if xlen == 32 then cap_sd_perms_width_32 else cap_sd_perms_width_64
let  cap_sd_perms_width = sizeof(cap_sd_perms_width)

type cap_reserved_1_width : Int = if xlen == 32 then cap_reserved_1_width_32 else cap_reserved_1_width_64
let  cap_reserved_1_width = sizeof(cap_reserved_1_width)

type cap_reserved_0_width : Int = if xlen == 32 then cap_reserved_0_width_32 else cap_reserved_0_width_64
let  cap_reserved_0_width = sizeof(cap_reserved_0_width)

type cap_mantissa_width : Int = if xlen == 32 then cap_mantissa_width_32 else cap_mantissa_width_64
let  cap_mantissa_width = sizeof(cap_mantissa_width)

type cap_E_width : Int  = if xlen == 32 then cap_E_width_32 else cap_E_width_64
let  cap_E_width = sizeof(cap_E_width)

type cap_AP_M_width : Int = if xlen == 32 then cap_AP_M_width_32 else cap_AP_M_width_64
let  cap_AP_M_width = sizeof(cap_AP_M_width)

let cap_use_L8 : bool = if xlen == 32 then cap_use_L8_32 else cap_use_L8_64

struct EncMetadata = {
  SDP : bits(cap_sd_perms_width),
  AP_M : bits(cap_AP_M_width),
  GL : bits(1),
  CT : bits(1),
  EF : bits(1),
  Tm : bits(if xlen == 32 then 6 else 9),
  Bm : bits(if xlen == 32 then 8 else 11),
  TE : bits(if xlen == 32 then 2 else 3),
  BE : bits(if xlen == 32 then 2 else 3),
  reserved_1 : bits(cap_reserved_1_width),
  reserved_0 : bits(cap_reserved_0_width),
  L8 : bits(if xlen == 32 then 1 else 0)
}

val dec_EncMetadata : bits(xlen) -> EncMetadata
function dec_EncMetadata(meta_bits) = {
  if xlen == 32 then {
    let m32 = Mk_EncMetadata_32(slice(meta_bits, 0, 32));
    struct {
      SDP = m32[SDP],
      AP_M = m32[AP_M],
      GL = m32[GL],
      CT = m32[CT],
      EF = m32[EF],
      Tm = m32[Tm],
      Bm = m32[Bm],
      TE = m32[TE],
      BE = m32[BE],
      reserved_1 = m32[reserved_1],
      reserved_0 = m32[reserved_0],
      L8 = m32[L8]
    }
  } else {
    let m64 = Mk_EncMetadata_64(slice(meta_bits, 0, 64));
    struct {
      SDP = m64[SDP],
      AP_M = m64[AP_M],
      GL = m64[GL],
      CT = m64[CT],
      EF = m64[EF],
      Tm = m64[Tm],
      Bm = m64[Bm],
      TE = m64[TE],
      BE = m64[BE],
      reserved_1 = m64[reserved_1],
      reserved_0 = m64[reserved_0],
      L8 = zeros()
    }
  }
}

val enc_EncMetadata : EncMetadata -> bits(xlen)
function enc_EncMetadata(meta) = {
  if xlen == 32 then {
    let m32 = [
      Mk_EncMetadata_32(zeros()) with
      SDP = meta.SDP,
      AP_M = meta.AP_M,
      GL = meta.GL,
      CT = meta.CT,
      EF = meta.EF,
      Tm = meta.Tm,
      Bm = meta.Bm,
      TE = meta.TE,
      BE = meta.BE,
      reserved_1 = meta.reserved_1,
      reserved_0 = meta.reserved_0,
      L8 = meta.L8
    ];
    m32.bits
  } else {
    let m64 = [
      Mk_EncMetadata_64(zeros()) with
      SDP = meta.SDP,
      AP_M = meta.AP_M,
      GL = meta.GL,
      CT = meta.CT,
      EF = meta.EF,
      Tm = meta.Tm,
      Bm = meta.Bm,
      TE = meta.TE,
      BE = meta.BE,
      reserved_1 = meta.reserved_1,
      reserved_0 = meta.reserved_0
    ];
    m64.bits
  }
}

// Unified permission encoding/decoding functions
val ap_m_decode : bits(cap_AP_M_width) -> (ArchPerms, ExecutionMode)
function ap_m_decode(ap_m) = {
  if xlen == 32 then {
    let ap_m32 : bits(cap_AP_M_width_32) = ap_m;
    ap_m_encdec_32(ap_m32)
  } else {
    let ap_m64 : bits(cap_AP_M_width_64) = ap_m;
    ap_m_encdec_64(ap_m64)
  }
}

val ap_m_encode : ((ArchPerms, ExecutionMode)) -> bits(cap_AP_M_width)
function ap_m_encode((perms, mode)) = {
  if xlen == 32 then {
    ap_m_encdec_32(perms, mode)
  } else {
    ap_m_encdec_64(perms, mode)
  }
}

val ap_m_valid_bits : bits(cap_AP_M_width) -> bool
function ap_m_valid_bits(ap_m) = {
  if xlen == 32 then {
    let ap_m5 : bits(5) = ap_m;
    ap_m_encdec_32_forwards_matches(ap_m5)
  } else {
    let ap_m9 : bits(9) = ap_m;
    ap_m_encdec_64_forwards_matches(ap_m9)
  }
}

let null_ap_m : bits(cap_AP_M_width) = if xlen == 32 then 0b00000 else 0b000000000
let root_ap_m : bits(cap_AP_M_width) = if xlen == 32 then 0b01001 else 0b111111111

// Perform the XLEN-specific ACPERMS legalization.
function legalizePermsAndMode(perms : ArchPerms, mode : ExecutionMode) -> (ArchPerms, ExecutionMode) = {
  if xlen == 32 then {
    legalizePermsAndMode_32(perms, mode)
  } else {
    legalizePermsAndMode_64(perms, mode)
  }
}

// Needed because there's no L8 in the RV64 version.
function getMetadataL8(meta : EncMetadata) -> bits(1) = {
  if xlen == 32 then meta.L8 else 0b0
}

function setMetadataL8(meta : EncMetadata, L8 : bits(1)) -> EncMetadata = {
  if xlen == 32 then {
    {meta with L8 = L8}
  } else {
    meta
  }
}

// Get the internal exponent. This is only meaningful if EF is "internal".
function getMetadataInternalExponent(meta : EncMetadata) -> bits(cap_E_width) = {
  if xlen == 32 then {
    meta.L8 @ meta.TE @ meta.BE
  } else {
    meta.TE @ meta.BE
  }
}
