/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/
function clause extensionEnabled(Ext_Zicntr) = true

/* unprivileged counters/timers */
mapping clause csr_name_map = 0xC00  <-> "cycle"
mapping clause csr_name_map = 0xC01  <-> "time"
mapping clause csr_name_map = 0xC02  <-> "instret"
mapping clause csr_name_map = 0xC80  <-> "cycleh"
mapping clause csr_name_map = 0xC81  <-> "timeh"
mapping clause csr_name_map = 0xC82  <-> "instreth"

function clause is_CSR_defined(0xC00) = extensionEnabled(Ext_Zicntr) // cycle
function clause is_CSR_defined(0xC01) = extensionEnabled(Ext_Zicntr) // time
function clause is_CSR_defined(0xC02) = extensionEnabled(Ext_Zicntr) // instret
function clause is_CSR_defined(0xC80) = extensionEnabled(Ext_Zicntr) & (xlen == 32) // cycleh
function clause is_CSR_defined(0xC81) = extensionEnabled(Ext_Zicntr) & (xlen == 32) // timeh
function clause is_CSR_defined(0xC82) = extensionEnabled(Ext_Zicntr) & (xlen == 32) // instreth

function clause read_CSR(0xC00, _) = mcycle[(xlen - 1) .. 0]
function clause read_CSR(0xC01, _) = mtime[(xlen - 1) .. 0]
function clause read_CSR(0xC02, _) = minstret[(xlen - 1) .. 0]
function clause read_CSR((0xC80, _) if xlen == 32) = mcycle[63 .. 32]
function clause read_CSR((0xC81, _) if xlen == 32) = mtime[63 .. 32]
function clause read_CSR((0xC82, _) if xlen == 32) = minstret[63 .. 32]


/* machine counters/timers */
mapping clause csr_name_map = 0xB00  <-> "mcycle"
mapping clause csr_name_map = 0xB02  <-> "minstret"
mapping clause csr_name_map = 0xB80  <-> "mcycleh"
mapping clause csr_name_map = 0xB82  <-> "minstreth"

function clause is_CSR_defined(0xB00) = extensionEnabled(Ext_Zicntr) // mcycle
function clause is_CSR_defined(0xB02) = extensionEnabled(Ext_Zicntr) // minstret
function clause is_CSR_defined(0xB80) = extensionEnabled(Ext_Zicntr) & xlen == 32 // mcycleh
function clause is_CSR_defined(0xB82) = extensionEnabled(Ext_Zicntr) & xlen == 32 // minstreth

function clause read_CSR(0xB00, _) = mcycle[(xlen - 1) .. 0]
function clause read_CSR(0xB02, _) = minstret[(xlen - 1) .. 0]
function clause read_CSR((0xB80, _) if xlen == 32)= mcycle[63 .. 32]
function clause read_CSR((0xB82, _) if xlen == 32) = minstret[63 .. 32]

function clause write_CSR(0xB00, value) = { mcycle[(xlen - 1) .. 0] = value; value }
function clause write_CSR(0xB02, value) = { minstret_write = Some(value); value }
function clause write_CSR((0xB80, value) if xlen == 32) = { mcycle[63 .. 32] = value; value }
function clause write_CSR((0xB82, value) if xlen == 32) = { minstreth_write = Some(value); value }
