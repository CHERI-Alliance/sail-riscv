// This file contains functions for accessing some CSRs. They
// are in a separate file because they are overridden by CHERI.

/******************************* xTVEC[C] *******************************/

function get_mtvec() -> xlenbits = mtvec.bits
function get_stvec() -> xlenbits = read_stvec_utvec(stvec.bits)

function set_mtvec(value : xlenbits) -> unit = {
  mtvec = legalize_tvec(mtvec, convertInvalidAddr(value));
}

function set_stvec(value : xlenbits) -> unit = {
  stvec = legalize_tvec(stvec, convertInvalidAddr(value));
}

/******************************* xSCRATCH[C] *******************************/

function get_mscratch() -> xlenbits = mscratch

function set_mscratch(value : xlenbits) -> unit = {
  mscratch = value;
}

function get_sscratch() -> xlenbits = sscratch

function set_sscratch(value : xlenbits) -> unit = {
  sscratch = value;
}

/******************************* xEPC[C] *******************************/

function get_mepc() -> xlenbits = align_pc(mepc)

function set_mepc(value : xlenbits) -> unit = {
  mepc = legalize_xepc(convertInvalidAddr(value));
}

function get_sepc() -> xlenbits = align_pc(sepc)

function set_sepc(value : xlenbits) -> unit = {
  sepc = legalize_xepc(convertInvalidAddr(value));
}

/******************************* xenvcfg *******************************/

function set_menvcfg(v : bits(64)) -> unit = {
  menvcfg = legalize_menvcfg(menvcfg, mseccfg, v);
}

function set_senvcfg(v : xlenbits) -> unit = {
  senvcfg = legalize_senvcfg(senvcfg, menvcfg, v);
}

/******************************* mseccfg *******************************/

function set_mseccfg(v : bits(64)) -> unit = {
  mseccfg = legalize_mseccfg(mseccfg, v);
}

/******************************* xTVT[C] *******************************/

function get_mtvt() -> xlenbits = mtvt
function get_stvt() -> xlenbits = stvt

function set_mtvt(value : xlenbits) -> unit = {
  mtvt = legalize_tvt(mtvt, convertInvalidAddr(value))
}

function set_stvt(value : xlenbits) -> unit = {
  stvt = legalize_tvt(stvt, convertInvalidAddr(value));
}
