/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* The default implementation of hooks for the step() and main() functions. */

function ext_fetch_hook(f : FetchResult) -> FetchResult = track_fetch_hook(f)
function ext_vector_fetch_hook(f : VectorTableFetchResult) -> VectorTableFetchResult = track_vector_fetch_hook(f)

function ext_fetch_mem_read_hi(paddr : physaddr, pbmt : PBMT) -> MemoryOpResult(half) = track_fetch_mem_read_hook(paddr, pbmt, true)
function ext_fetch_mem_read_lo(paddr : physaddr, pbmt : PBMT) -> MemoryOpResult(half) = track_fetch_mem_read_hook(paddr, pbmt, false)

function ext_pre_step_hook()  -> unit = track_pre_step_hook()
function ext_post_step_hook() -> unit = track_post_step_hook()

// Print an instruction we are executing. This can be overridden for CHERI.
function ext_print_instr forall 'n, 'n in {16, 32} . (
  step_no : int, ast : ast, opcode : bits('n)
) -> unit = {
  if get_config_print_instr()
  then print_instr(
    "[" ^ dec_str(step_no) ^ "] [" ^ to_str(cur_privilege()) ^ "]: " ^
    BitStr(PC) ^ " (" ^ BitStr(opcode) ^ ") " ^ to_str(ast)
  );
}

function ext_reset() -> unit = ()
function ext_reset_misa() -> unit = ()
