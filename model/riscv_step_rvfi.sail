/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Step hooks for rvfi. */

function ext_fetch_hook(f : FetchResult) -> FetchResult = f

function ext_pre_step_hook()  -> unit = ()

function ext_post_step_hook() -> unit = {
  /* record the next pc */
  rvfi_pc_data[rvfi_pc_wdata] = zero_extend(get_arch_pc())
}

// Print an instruction we are executing. For CHERI we print the mode too.
function ext_print_instr forall 'n, 'n in {16, 32} . (
  step_no : int, ast : ast, opcode : bits('n)
) -> unit = {
  if get_config_print_instr()
  then {
    let cheri_mode : string = match effective_cheri_mode() {
      CapPtrMode => "CapPtrMode",
      IntPtrMode  => "Integer",
    };
    print_instr(
      "[" ^ dec_str(step_no) ^ "] [" ^ to_str(cur_privilege()) ^ "," ^ cheri_mode ^ "]: " ^
      BitStr(PC) ^ " (" ^ BitStr(opcode) ^ ") " ^ to_str(ast)
    );
  };
}

function ext_reset() -> unit = ext_rvfi_reset()
function ext_reset_misa() -> unit = ()
