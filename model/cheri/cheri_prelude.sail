/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* CHERI specific helpers */

val MEMr_tag = impure "read_tag_bool"  : bits(64) -> bool
val MEMw_tag = impure "write_tag_bool" : (bits(64) , bool) -> unit
