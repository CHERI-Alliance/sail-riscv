/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* This file contains register handling functions that can be
 * overridden by extensions.
 */

/*!
This allows an extension to block access to csrno,
at Privilege level priv. It should return true if the access is allowed.
*/
val ext_check_CSR : (csreg, Privilege, bool, csrop, bool) -> option(ext_csr_exc_type)
function ext_check_CSR (csrno, p, isWrite, op, is_imm) = None()

/*!
THIS is called if ext_check_CSR returns false. It should
cause an appropriate RISCV exception.
 */
val ext_check_CSR_fail : (ext_csr_exc_type) -> unit
function ext_check_CSR_fail (fail_type) = ()
