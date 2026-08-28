// TODO: factor out code common to legalize_menvcfg and legalize_senvcfg.

// Is PBMT supported?
val sys_enable_pbmt = pure "sys_enable_pbmt" : unit -> bool

function legalize_menvcfg(o : MEnvcfg, v : bits(64)) -> MEnvcfg = {
  let v = Mk_MEnvcfg(v);
  [o with
    FIOM = if sys_enable_writable_fiom then v[FIOM] else 0b0,
    STCE = if currentlyEnabled(Ext_Sstc) then v[STCE] else 0b0,
    CBZE = if currentlyEnabled(Ext_Zicboz) then v[CBZE] else 0b0,
    CBCFE = if currentlyEnabled(Ext_Zicbom) then v[CBCFE] else 0b0,
    CBIE = if currentlyEnabled(Ext_Zicbom) then (if v[CBIE] != 0b10 then v[CBIE] else 0b00) else 0b00,
    PBMTE = if sys_enable_pbmt() then v[PBMTE] else 0b0,
    Y = v[Y],
    // Other extensions are not implemented yet so all other fields are read only zero.
  ]
}

function legalize_senvcfg(o : SEnvcfg, v : xlenbits) -> SEnvcfg = {
  let v = Mk_SEnvcfg(v);
  [o with
    FIOM = if sys_enable_writable_fiom then v[FIOM] else 0b0,
    CBZE = if currentlyEnabled(Ext_Zicboz) then v[CBZE] else 0b0,
    CBCFE = if currentlyEnabled(Ext_Zicbom) then v[CBCFE] else 0b0,
    CBIE = if currentlyEnabled(Ext_Zicbom) then (if v[CBIE] != 0b10 then v[CBIE] else 0b00) else 0b00,
    Y = v[Y],
    // Other extensions are not implemented yet so all other fields are read only zero.
  ]
}
