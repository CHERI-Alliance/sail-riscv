/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// Return value from `execute()` function.
union ExecutionResult = {
  // Successfully retired.
  Retire_Success                 : unit,

  // An instruction such as WFI, WRS.{STO,NTO}
  // entered a wait state, which may or may not
  // retire depending on the configuration.
  Enter_Wait                     : WaitReason,

  // Did not retire for a standard reason.
  Illegal_Instruction            : unit,
  Trap                           : (Privilege, ctl_result, xlenbits),
  Memory_Exception               : (virtaddr, ExceptionType),
  Translate_Exception            : (virtaddr, ExceptionType, ext_ptw),
  CHERI_Exception                : (CapCheckType, virtaddr),

  // Did not retire for custom reason.
  Ext_CSR_Check_Failure          : ext_csr_exc_type,
  Ext_DataAddr_Check_Failure     : ext_data_addr_error,
}

// To ease the introduction of `ExecutionResult`, this global
// definition is temporarily used instead of the previous
// RETIRE_SUCCESS enum value so that we don't have to immediately
// update all the places RETIRE_SUCCESS was used.

let RETIRE_SUCCESS : ExecutionResult = Retire_Success()
