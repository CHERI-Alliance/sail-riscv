function legalize_mseccfg(o : Seccfg, v : bits(64)) -> Seccfg = {
  let v = Mk_Seccfg(v);
  [
    o with
    SSEED = if extensionEnabled(Ext_Zkr) then v[SSEED] else 0b0,
    USEED = if extensionEnabled(Ext_Zkr) then v[USEED] else 0b0,
  ]
}
