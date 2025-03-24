// Exponent of the page size. 2^12 = 4096 bytes.
type page_size_exp : Int = 12
let  page_size_exp = sizeof(page_size_exp)
type page_size : Int = 2 ^ page_size_exp
let  page_size = sizeof(page_size)

type translation = (physaddr, PBMT, ext_ptw)

// Exception when accessing an address, together with the offending virtual address.
type VMemException = (virtaddr, ExceptionType, ext_ptw)

// An address, plus an optional second address. This is used for address
// translation of accesses that may span page boundaries. It's not possible
// to span more than one page boundary so we only need a max of two addresses.
type translation2 = (translation, option(translation))

// For an access that may be split across a page boundary, returns the width
// of each half. If it isn't split the second value will be 0.
val splitAccessWidths : forall 'n 'w, 'n >= page_size_exp & 0 <= 'w <= max_mem_access . (bits('n), int('w)) ->
  {'w0 'w1, 'w0 >= 0 & 'w1 >= 0 & 'w0 + 'w1 == 'w . (int('w0), int('w1))}

function splitAccessWidths(addr, width) = {
  let offset_in_page = unsigned(addr[page_size_exp - 1 .. 0]);
  let width0 = page_size - offset_in_page;
  let width0 : range(0, 'w) = if width0 <= width then width0 else width;
  let width1 = width - width0;
  (width0, width1)
}

// Translate virtual to physical address(es) for a multi-byte memory access.
// Because the access may be across a page boundary this may result in multiple
// physical addresses. If that is the case, the second physical address will
// point to the start of a page.
function translateRange(
  vaddr : virtaddr,
  width : range(0, max_mem_access),
  typ : AccessType(ext_access_type),
) -> result(translation2, VMemException) = {
  // Widths of each access.
  let (width0, width1) = splitAccessWidths(virtaddr_bits(vaddr), width);
  assert(width0 + width1 == width);

  // Translate the first address, return failure if it fails.
  let tr0 : translation = match translateAddr(vaddr, typ) {
    TR_Address(paddr, pbmt, ext_ptw) => (paddr, pbmt, ext_ptw),
    TR_Failure(exc, ext_ptw) => return Err(vaddr, exc, ext_ptw),
  };

  // If the second access exists then we need to translate its address.
  let tr1 = if width1 != 0 then {
    // Second address to translate is at the start of the next page (wrapped).
    let vaddr1 = virtaddr(virtaddr_bits(vaddr) + width0);
    let tr1 : translation = match translateAddr(vaddr1, typ) {
      TR_Address(paddr, pbmt, ext_ptw) => (paddr, pbmt, ext_ptw),
      TR_Failure(exc, ext_ptw) => return Err(vaddr1, exc, ext_ptw),
    };
    Some(tr1)
  } else {
    None()
  };
  Ok(tr0, tr1)
}

// TODO: The return type for reads currently only includes ext_ptw for failure.
// It should technically include it for success too because CHERI does things
// on successful capability reads (clearing the tag or trapping). However
// it doesn't actually matter for CHERI since all capability reads must be
// aligned and don't go via this code.

// Read memory but potentially using two accesses if `paddrs` contains two
// entries. The results are then combined back into a single value. This is
// needed when reading across a page boundary.
function vmem_read_priv_meta forall 'n, 0 < 'n < max_mem_access . (
  typ : AccessType(ext_access_type),
  priv : Privilege,
  vaddr : virtaddr,
  width : int('n),
  aq : bool,
  rel : bool,
  res : bool,
  meta : bool,
) -> result((bits(8 * 'n), mem_meta), VMemException) = {
  match translateRange(vaddr, width, typ) {
    Err(e) => Err(e),
    Ok(tr) => {
      match tr {
        ((paddr0, pbmt0, ext_ptw), None()) => match checked_mem_read(typ, priv, pbmt0, paddr0, width, aq, rel, res, meta) {
          Ok(v, meta) => Ok(v, meta),
          Err(e) => Err(vaddr, e, ext_ptw),
        },
        ((paddr0, pbmt0, ext_ptw0), Some((paddr1, pbmt1, ext_ptw1))) => {
          let (width0 as int('w0), width1 as int('w1)) = splitAccessWidths(physaddr_bits(paddr0), width);
          assert(width0 > 0 & width1 > 0);

          let (val0, meta0) : (bits(8 * 'w0), mem_meta) = match checked_mem_read(typ, priv, pbmt0, paddr0, width0, aq, rel, res, meta) {
            Ok(v, meta) => (v, meta),
            Err(e) => return Err(vaddr, e, ext_ptw0),
          };
          let (val1, meta1) : (bits(8 * 'w1), mem_meta) = match checked_mem_read(typ, priv, pbmt1, paddr1, width1, aq, rel, res, meta) {
            Ok(v, meta) => (v, meta),
            Err(e) => return Err(virtaddr(virtaddr_bits(vaddr) + width0), e, ext_ptw1),
          };
          // TODO: How should we combine meta0 and meta1?
          Ok((val1 @ val0, meta0))
        },
      }
    },
  };

}

struct _WriteIntermediateState('n) = {
  vaddr : virtaddr,
  tr : translation2,
  width : int('n),
  typ : AccessType(ext_access_type),
  aq : bool,
  rl : bool,
  con : bool,
}

function vmem_write_translate forall 'n, 0 < 'n <= max_mem_access . (
  vaddr : virtaddr,
  width : int('n),
  typ : AccessType(ext_access_type),
  aq : bool,
  rl : bool,
  con : bool,
) -> result(_WriteIntermediateState('n), VMemException) = {
  // Translate both addresses.
  match translateRange(vaddr, width, typ) {
    Err(e) => Err(e),
    Ok(tr) => {
      match tr {
        ((paddr0, _, ext_ptw0), None()) => match mem_write_ea(paddr0, width, aq, rl, con) {
          Ok() => Ok(struct { vaddr, tr, width, typ, aq, rl, con }),
          Err(e) => Err(vaddr, e, ext_ptw0),
        },
        ((paddr0, _, ext_ptw0), Some((paddr1, _, ext_ptw1))) => {
          let (width0, width1) = splitAccessWidths(physaddr_bits(paddr0), width);
          assert(width0 > 0 & width1 > 0);

          match mem_write_ea(paddr0, width0, aq, rl, con) {
            Ok() => (),
            Err(e) => return Err(vaddr, e, ext_ptw0),
          };
          match mem_write_ea(paddr1, width1, aq, rl, con) {
            Ok() => (),
            Err(e) => return Err(virtaddr(virtaddr_bits(vaddr) + width0), e, ext_ptw1),
          };
          Ok(struct { vaddr, tr, width, typ, aq, rl, con })
        },
      }
    },
  }
}

function vmem_write_value_priv_meta forall 'n, 0 < 'n <= max_mem_access . (
  state : _WriteIntermediateState('n),
  value : bits(8 * 'n),
  priv : Privilege,
  meta : mem_meta,
) -> result(bool, VMemException) = {
  let (vaddr, tr, width, typ, aq, rl, con) = (state.vaddr, state.tr, state.width, state.typ, state.aq, state.rl, state.con);

  match tr {
    ((paddr0, pbmt0, ext_ptw0), None()) => match checked_mem_write(pbmt0, paddr0, width, value, typ, priv, aq, rl, con, meta) {
      Ok(ok) => Ok(ok),
      Err(e) => Err(vaddr, e, ext_ptw0),
    },
    ((paddr0, pbmt0, ext_ptw0), Some((paddr1, pbmt1, ext_ptw1))) => {
      let (width0, width1) = splitAccessWidths(physaddr_bits(paddr0), width);
      assert(width0 > 0 & width1 > 0);

      let res0 : bool = match checked_mem_write(pbmt0, paddr0, width0, value[8 * width0 - 1 .. 0], typ, priv, aq, rl, con, meta) {
        Ok(ok) => ok,
        Err(e) => return Err(vaddr, e, ext_ptw0),
      };
      let res1 : bool = match checked_mem_write(pbmt1, paddr1, width1, value[8 * width - 1 .. 8 * width0], typ, priv, aq, rl, con, meta) {
        Ok(ok) => ok,
        Err(e) => return Err(vaddr, e, ext_ptw1),
      };
      // TODO: The semantics of this return value are unclear, and currently always true.
      Ok(res1 & res0)
    },
  }
}


// Convenience functions wrapping the above functions to match those in riscv_mem.sail.

// Don't read or return meta.
function vmem_read_priv forall 'n, 0 < 'n < max_mem_access . (
  typ : AccessType(ext_access_type),
  priv : Privilege,
  vaddr : virtaddr,
  width : int('n),
  aq : bool,
  rel : bool,
  res : bool,
) -> result(bits(8 * 'n), VMemException) =
  match vmem_read_priv_meta(typ, priv, vaddr, width, aq, rel, res, false) {
    Ok(v, _) => Ok(v),
    Err(vaddr, e, ext_ptw) => Err(vaddr, e, ext_ptw),
  }

// Use default privilege.
function vmem_read_meta forall 'n, 0 < 'n < max_mem_access . (
  typ : AccessType(ext_access_type),
  vaddr : virtaddr,
  width : int('n),
  aq : bool,
  rel : bool,
  res : bool,
  meta : bool,
) -> result((bits(8 * 'n), mem_meta), VMemException) =
  vmem_read_priv_meta(typ, effectivePrivilege(typ, mstatus, cur_privilege()), vaddr, width, aq, rel, res, meta)

// Don't read or return meta and use default privilege.
function vmem_read forall 'n, 0 < 'n < max_mem_access . (
  typ : AccessType(ext_access_type),
  vaddr : virtaddr,
  width : int('n),
  aq : bool,
  rel : bool,
  res : bool,
) -> result(bits(8 * 'n), VMemException) =
  vmem_read_priv(typ, effectivePrivilege(typ, mstatus, cur_privilege()), vaddr, width, aq, rel, res)

// Write default metadata.
function vmem_write_value_priv forall 'n, 0 < 'n <= max_mem_access . (
  state : _WriteIntermediateState('n),
  value : bits(8 * 'n),
  priv : Privilege,
) -> result(bool, VMemException) =
  vmem_write_value_priv_meta(state, value, priv, default_meta)

// Use default privilege.
function vmem_write_value_meta forall 'n, 0 < 'n <= max_mem_access . (
  state : _WriteIntermediateState('n),
  value : bits(8 * 'n),
  meta : mem_meta,
) -> result(bool, VMemException) =
  vmem_write_value_priv_meta(state, value, effectivePrivilege(state.typ, mstatus, cur_privilege()), meta)

// Write default metadata and use default privilege.
function vmem_write_value forall 'n, 0 < 'n <= max_mem_access . (
  state : _WriteIntermediateState('n),
  value : bits(8 * 'n),
) -> result(bool, VMemException) =
  vmem_write_value_meta(state, value, default_meta)
