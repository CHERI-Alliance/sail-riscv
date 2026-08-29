/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

function ext_reset_cheri() -> unit = {
  PCC = infinite_cap;
  nextPCC = infinite_cap;
  ddc = infinite_cap;

  // The address bits may have been initialised by the non-CHERI reset to a non-zero value.
  stvecc = {infinite_cap with address = stvec.bits};
  stdc = {stdc with tag = false, address = zeros()} ;
  sscratchc = {sscratchc with tag = false, address = sscratch} ;
  sepcc = infinite_cap;
  mtidc = {mtidc with tag = false};
  stidc = {stidc with tag = false};
  utidc = {utidc with tag = false};

  mtvecc = {infinite_cap with address = mtvec.bits};
  mtdc = {mtdc with tag = false, address = zeros()} ;
  mscratchc = {mscratchc with tag = false, address = mscratch} ;
  mepcc = infinite_cap;

  // dpcc = {dpcc with tag = false} ;
  // dscratch0c = {dscratch0c with tag = false};
  // dscratch1c = {dscratch1c with tag = false};
  // dddc = {dddc with tag = false};
  // dinfc = infinite_cap;

  foreach (i from 1 to 31) {
    let r = Regno(i);
    wX_full(r, {rX_full(r) with tag = false});
  };
}

function ext_reset() -> unit = if get_config_rvfi() then ext_rvfi_reset() else ext_reset_cheri()

function ext_reset_misa() -> unit = ()

function ext_fetch_hook(f : FetchResult) -> FetchResult = f

function ext_fetch_mem_read_hi(paddr : physaddr, pbmt : PBMT) -> MemoryOpResult(half) = mem_read(InstructionFetch(), pbmt, paddr, 2, false, false, false)
function ext_fetch_mem_read_lo(paddr : physaddr, pbmt : PBMT) -> MemoryOpResult(half) = mem_read(InstructionFetch(), pbmt, paddr, 2, false, false, false)

function ext_pre_step_hook()  -> unit = ()
function ext_post_step_hook() -> unit = ()

// Print an instruction we are executing. For CHERI we print the mode too.
function ext_print_instr forall 'n, 'n in {16, 32} . (
  step_no : int, instruction : instruction, opcode : bits('n)
) -> unit = {
  if get_config_print_instr()
  then {
    let cheri_mode : string = match effective_cheri_mode() {
      CapPtrMode => "CapPtrMode",
      IntPtrMode  => "Integer",
    };
    print_instr(
      "[" ^ dec_str(step_no) ^ "] [" ^ to_str(cur_privilege()) ^ "," ^ cheri_mode ^ "]: " ^
      BitStr(PC) ^ " (" ^ BitStr(opcode) ^ ") " ^ to_str(instruction)
    );
  };
}
