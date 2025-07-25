/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// Is the Sstc stimecmp extension supported.
val sys_enable_sstc = pure "sys_enable_sstc" : unit -> bool

function clause extensionEnabled(Ext_Sstc) = sys_enable_sstc()

register stimecmp : bits(64)

/* Sstc - supervisor time compare */
mapping clause csr_name_map = 0x14D  <-> "stimecmp"
mapping clause csr_name_map = 0x15D  <-> "stimecmph"

function clause is_CSR_defined(0x14D) = extensionEnabled(Ext_S) & extensionEnabled(Ext_Sstc)
function clause is_CSR_defined(0x15D) = extensionEnabled(Ext_S) & extensionEnabled(Ext_Sstc) & xlen == 32

function clause read_CSR((0x14D, _)) = stimecmp[xlen - 1 .. 0]
function clause read_CSR((0x15D, _) if xlen == 32) = stimecmp[63 .. 32]

function clause write_CSR(0x14D, value) = { stimecmp[(xlen - 1) .. 0] = value; stimecmp[xlen - 1 ..0] }
function clause write_CSR((0x15D, value) if xlen == 32) = { stimecmp[63 ..32] = value; stimecmp[63 .. 32] }
