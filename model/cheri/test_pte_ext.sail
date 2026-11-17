// Some of these tests were written with AI assistance. Please see the commit log for details.

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
    check_pte_access_success(allAllowedUserPTEs, Read(Data), "normal int read");
    check_pte_access_success(allAllowedUserPTEs, Write(Data), "normal int write");
    check_pte_access_success(allAllowedUserPTEs, ReadWrite(Data, Data), "normal int amo");
    check_pte_access_success(allAllowedUserPTEs, Read(Tagged), "normal cap read");
    check_pte_access_success(allAllowedUserPTEs, Write(Tagged), "normal cap write");
    check_pte_access_success(allAllowedUserPTEs, ReadWrite(Tagged, Tagged), "normal cap amo");

    // Construct inputs that should trigger a load capability fault, i.e. emulate being in the middle of a revocation sweep
    let revokingYRGExtPTE = [maxExtPTE with rvy = [maxSYRG with YRG=0b0].bits];
    let revokingUserPTEs = {allAllowedUserPTEs with ext = Some(revokingYRGExtPTE)};
    let noYWExtPTE = [maxExtPTE with rvy = [maxSYRG with YW=0b0].bits];
    let bothFaultExtPTE = [maxExtPTE with rvy = [maxSYRG with YW=0b0, YRG=0b0].bits];
    let ext_ptw_cheri_st = {init_ext_ptw with cheri_page_fault = Some(CheriPage_St)};

    // Step 6 (U=1 with SUM=0) outranks Step 7 (CheriPage_St when YW=0)
    check_pte_access({allAllowedUserPTEs with priv = Supervisor, do_sum = false, ext = Some(noYWExtPTE)}, Write(Tagged), false, init_ext_ptw, "S-mode U=1 SUM=0 outranks CheriPage_St");
    check_pte_access({allAllowedUserPTEs with priv = Supervisor, do_sum = true, ext = Some(noYWExtPTE)}, Write(Tagged), false, ext_ptw_cheri_st, "S-mode U=1 SUM=1 raises CheriPage_St");

    // Integer reads succeed
    check_pte_access_success(revokingUserPTEs, Read(Data), "revoking int read");
    // Revoking capability loads and AMOs pass translation and defer CheriPage_Ld
    // until after the memory read so higher-priority faults win.
    let ext_ptw_cap_trap = {init_ext_ptw with cap_load_behaviour = CapLoadTrap};
    check_pte_access(revokingUserPTEs, Read(Tagged), true, ext_ptw_cap_trap, "revoking cap read");
    check_pte_access(revokingUserPTEs, ReadWrite(Tagged, Tagged), true, ext_ptw_cap_trap, "revoking cap amo");
    assert(cap_load_should_trap(ext_ptw_cap_trap, true));
    assert(cap_load_should_trap(ext_ptw_cap_trap, false) == not(sys_cheri_pte_crg_exception_check_tag()));
    // Standard page fault (W=0) and CheriPage_St (YW=0) fail during translation,
    // outranking CheriPage_Ld.
    check_pte_access({revokingUserPTEs with pte = [maxPTE with W = 0b0]}, ReadWrite(Tagged, Tagged), false, ext_ptw_cap_trap, "W=0 outranks CheriPage_Ld on cap amo");
    check_pte_access({revokingUserPTEs with ext = Some(bothFaultExtPTE)}, ReadWrite(Tagged, Tagged), false, {ext_ptw_cap_trap with cheri_page_fault = Some(CheriPage_St)}, "CheriPage_St outranks CheriPage_Ld on cap amo");
}

function test_pte_ext() -> unit = {
  test_cheri_pte_checks_yrge();
}
