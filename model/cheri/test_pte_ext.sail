// TODO this works around an apparent Sail compiler bug where tuple comparison of bools tries to evaluate the value of the bool within the type system
function test_perm_check_match((ret_ok : bool, ret_ext_ptw : ext_ptw), (exp_ok : bool, exp_ext_ptw : ext_ptw), test_name : string) -> unit =
    {assert(ret_ok == exp_ok & ret_ext_ptw == exp_ext_ptw, test_name)}

// Bundle less commonly changed inputs to pte_permission_ok so we can concisely make lots of calls with similar arguments
struct xlate_inputs = {
    priv    : Privilege,
    mxr     : bool,
    do_sum  : bool,
    pte     : PTE_Flags,
    ext     : option(PTE_Ext), // None() for Sv32.
    ext_ptw : ext_ptw,
}

// Pass the arguments from the input struct into pte_permission_ok, and assert the output is as expected
function check_pte_access(inputs : xlate_inputs, ac : AccessType(ext_access_type), exp_ok : bool, exp_ext_ptw : ext_ptw, test_name : string) -> unit = {
    test_perm_check_match(pte_permission_ok(ac, inputs.priv, inputs.mxr, inputs.do_sum, inputs.pte, inputs.ext, inputs.ext_ptw), (exp_ok, exp_ext_ptw), test_name)
}

function check_pte_access_success(inputs : xlate_inputs, ac : AccessType(ext_access_type), test_name : string) -> unit = {
    check_pte_access(inputs, ac, true, init_ext_ptw, test_name)
}

// Overall function to test cheri PTE checks in cases where YRGE is enabled
function test_cheri_pte_checks_yrge() -> unit = {
    let maxPTE = struct {bits=ones()} : PTE_Flags;
    let maxSYRG = struct {bits = ones()} : PTE_RVY_SVYRG;
    let maxExtPTE = [struct {bits=zeros()} : PTE_Ext with rvy = maxSYRG.bits];
    let allAllowedUserPTEs : xlate_inputs = struct {priv = User, mxr = false, do_sum = false, pte = maxPTE, ext = Some(maxExtPTE), ext_ptw = init_ext_ptw};
    mstatus[YRGE] = 0b1;
    mstatus[UYRG] = 0b1;

    // Check basic reads succeed
    //test_perm_check_match(pte_permission_ok(Read(Data), User, false, false, maxPTE, Some(maxExtPTE), init_ext_ptw), (true, init_ext_ptw));
    //test_perm_check_match(pte_permission_ok(Read(Tagged), User, false, false, maxPTE, Some(maxExtPTE), init_ext_ptw), (true, init_ext_ptw));

    check_pte_access_success(allAllowedUserPTEs, Read(Data), "normal int read");
    check_pte_access_success(allAllowedUserPTEs, Write(Data), "normal int write");
    check_pte_access_success(allAllowedUserPTEs, ReadWrite(Data, Data), "normal int amo");
    check_pte_access_success(allAllowedUserPTEs, Read(Tagged), "normal cap read");
    check_pte_access_success(allAllowedUserPTEs, Write(Tagged), "normal cap write");
    check_pte_access_success(allAllowedUserPTEs, ReadWrite(Tagged, Tagged), "normal cap amo");

    // Construct inputs that should trigger a load capability fault, i.e. emulate being in the middle of a revocation sweep
    let revokingYRGExtPTE = [maxExtPTE with rvy = [maxSYRG with YRG=0b0].bits];
    let revokingUserPTEs = {allAllowedUserPTEs with ext = Some(revokingYRGExtPTE)};

    // Integer reads succeed
    check_pte_access_success(revokingUserPTEs, Read(Data), "revoking int read");
    // Split based on whether we support tag-dependent traps
    if sys_cheri_pte_crg_exception_check_tag() then {
      let ext_ptw_trap_on_tag = {init_ext_ptw with tagged_load_behaviour = TaggedLoadTrap};
      // Capability reads fail
      check_pte_access(revokingUserPTEs, Read(Tagged), true, ext_ptw_trap_on_tag , "revoking cap read (tagdep)");
      // Capability atomics fail
      check_pte_access(revokingUserPTEs, ReadWrite(Tagged, Tagged), true, ext_ptw_trap_on_tag, "revoking cap amo (tagdep)");
    } else {
      let ext_ptw_cheri_ld = {init_ext_ptw with cheri_page_fault = Some(CheriPage_Ld)};
      // Capability reads fail
      check_pte_access(revokingUserPTEs, Read(Tagged), false, ext_ptw_cheri_ld, "revoking cap read (conservative)");
      // Capability atomics fail
      check_pte_access(revokingUserPTEs, ReadWrite(Tagged, Tagged), false, ext_ptw_cheri_ld, "revoking cap amo (conservative)");
    }
}

function test_pte_ext() -> unit = {
  test_cheri_pte_checks_yrge();
}
