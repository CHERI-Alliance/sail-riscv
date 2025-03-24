// Is PBMT currently available to supervisor mode.
function clause extensionEnabled(Ext_Svpbmt) = menvcfg[PBMTE] == 0b1

// Possible PMA override modes from Page Based Memory Types.
enum PBMT = {
  // Use standard PMAs. PBMT doesn't override anything. This is also the
  // result if PMBTs aren't supported.
  PMA,
  // Non-cacheable. Forces these PMAs:
  //
  // * Non-cacheable
  // * Idempotent
  // * Weakly ordered (RVWMO)
  // * Main memory
  //
  // Note that if the standard PMA is I/O this counts as main memory *and*
  // I/O for `fence`.
  NC,
  // I/O. Force these PMAs:
  //
  // * Non-cacheable
  // * Non-idempotent
  // * Strongly ordered (I/O ordering)
  // * I/O
  //
  // Note that if the standard PMA is I/O this counts as main memory *and*
  // I/O for `fence`.
  IO,
}

mapping pbmt_enc : PBMT <-> bits(2) = {
  PMA <-> 0b00,
  NC  <-> 0b01,
  IO  <-> 0b10,
  // 0b11 is reserved.
}

// Take the fixed PMAs and the PMBT settings and resolve the overall PMAs.
function resolve_pma_pbmt(pma : PMA, pbmt : PBMT) -> PMA =
  match pbmt {
    PMA  => pma,
    NC   => { pma with cacheable = false, readIdempotent = true, writeIdempotent = true },
    IO   => { pma with cacheable = false, readIdempotent = false, writeIdempotent = false },
  }

mapping pbmt_str : PBMT <-> string = {
  PMA <-> "PMA",
  NC <-> "NC",
  IO <-> "IO",
}

overload to_str = { pbmt_str }
