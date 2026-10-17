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
This allows an extension to block access to csrno.
It should return true if the access is allowed.
*/
val ext_check_CSR : (csreg, bool) -> bool
function ext_check_CSR (_csrno, _isWrite) = true
