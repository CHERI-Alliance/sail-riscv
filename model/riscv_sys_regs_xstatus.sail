bitfield Mstatus : bits(64) = {
  SD     : xlen - 1,

  //MDT  : 42,
  //MPELP: 41,

  //MPV  : 39,
  //GVA  : 38,

  MBE  : 37,
  SBE  : 36,

  SXL  : 35 .. 34,
  UXL  : 33 .. 32,

  //SDT  : 24,
  //SPELP: 23,
  TSR  : 22,
  TW   : 21,
  TVM  : 20,
  MXR  : 19,
  SUM  : 18,
  MPRV : 17,

  XS   : 16 .. 15,
  FS   : 14 .. 13,

  MPP  : 12 .. 11,
  VS   : 10 .. 9,
  SPP  : 8,

  MPIE : 7,
  SPIE : 5,

  MIE  : 3,
  SIE  : 1,
}

bitfield Sstatus : bits(64) = {
  SD    : xlen - 1,

  UXL   : 33 .. 32,
//  SDT   : 24,
//  SPELP : 23,
  MXR   : 19,
  SUM   : 18,
  XS    : 16 .. 15,
  FS    : 14 .. 13,
  VS    : 10 .. 9,
  SPP   : 8,
  SPIE  : 5,
  SIE   : 1,
}

function ext_legalize_mstatus(m : Mstatus, v : Mstatus) -> Mstatus = m

function ext_lower_mstatus(m : Mstatus, s : Sstatus) -> Sstatus = s

function ext_lift_sstatus(m : Mstatus, s : Sstatus) -> Mstatus = m
