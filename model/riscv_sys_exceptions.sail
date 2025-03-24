/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* default exception model */

type ext_exception = unit

/* Is XRET from given mode permitted by extension? */
function ext_check_xret_priv (p : Privilege) : Privilege -> bool = true
/* Called if above check fails */
function ext_fail_xret_priv () : unit -> unit = ()

function ext_ptw_exception_info(ext_ptw : ext_ptw) -> ext_exception = ()

function handle_trap_extension(p : Privilege, pc : xlenbits, u : option(unit)) -> unit = ()
function handle_nmi_extension(pc : xlenbits, handler_pc : xlenbits) -> unit = ()

/* used for traps and ECALL */
function prepare_trap_vector(p : Privilege, cause : Mcause) -> xlenbits = {
  let tvec : Mtvec = match p {
                       Machine    => Mk_Mtvec(get_mtvec()),
                       Supervisor => Mk_Mtvec(get_stvec()),
                       User       => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
                     };
  match tvec_addr(tvec, cause) {
    Some(epc) => epc,
    None()    => internal_error(__FILE__, __LINE__, "Invalid tvec mode")
  }
}


mapping clause csr_name_map = 0x105  <-> "stvec"
mapping clause csr_name_map = 0x141  <-> "sepc"
mapping clause csr_name_map = 0x305  <-> "mtvec"
mapping clause csr_name_map = 0x341  <-> "mepc"

function clause is_CSR_defined(0x105) = extensionEnabled(Ext_S) // stvec
function clause is_CSR_defined(0x141) = extensionEnabled(Ext_S) // sepc
function clause is_CSR_defined(0x305) = true // mtvec
function clause is_CSR_defined(0x341) = true // mepc

function clause read_CSR(0x105, _) = get_stvec()
function clause read_CSR(0x141, _) = get_sepc()
function clause read_CSR(0x305, _) = get_mtvec()
function clause read_CSR(0x341, _) = get_mepc()

function clause write_CSR(0x105, value) = { set_stvec(value); get_stvec() }
function clause write_CSR(0x141, value) = { set_sepc(value); get_sepc() }
function clause write_CSR(0x305, value) = { set_mtvec(value); get_mtvec() }
function clause write_CSR(0x341, value) = { set_mepc(value); get_mepc() }
