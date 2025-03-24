// Assumption behind implementation: PMAs cannot change between a
// reserved load and store. This assumes PMAs never change during
// execution, but this might not hold for hot pluggable devices.

enum AtomicSupport = { AMONone, AMOSwap, AMOLogical, AMOArithmetic }
enum Reservability = { RsrvNone, RsrvNonEventual, RsrvEventual }

mapping atomic_support_name : AtomicSupport <-> string = {
  AMONone       <-> "AMONone",
  AMOSwap       <-> "AMOSwap",
  AMOLogical    <-> "AMOLogical",
  AMOArithmetic <-> "AMOArithmetic",
}

mapping reservability_name : Reservability <-> string = {
  RsrvNone        <-> "RsrvNone",
  RsrvNonEventual <-> "RsrvNonEventual",
  RsrvEventual    <-> "RsrvEventual",
}

struct PMA = {
  cacheable                        : bool,
  coherent                         : bool,
  // If false then attempting to access this PMA during instruction fetch
  // will cause a fetch access fault.
  executable                       : bool,
  // If false when reading/writing for data access then this will cause
  // an access fault.
  readable                         : bool,
  writable                         : bool,
  readIdempotent                   : bool,
  writeIdempotent                  : bool,
  // Flags whether a non-idempotent memory region supports AXI-5 bufferable access.
  // (this has no architectural effect)
  relaxed                          : bool,
  // If true then misaligned accesses to this region cause an access fault.
  misalignmentCausesAccessFault    : bool,
  // If true then misaligned accesses to this region cause an alignment fault.
  // Setting both to true will cause a runtime exception.
  misalignmentCausesAlignmentFault : bool,
  atomicSupport                    : AtomicSupport,
  reservability                    : Reservability,
  // If this is not set then capability stores/loads from this memory will
  // always store & load with the tag set to 0.
  taggable                         : bool,
  // If this is set for a memory where taggable is false then stores of
  // tagged capabilities to that memory cause an access fault. Otherwise
  // they silently discard the tag.
  taggableAccessFaults        : bool,
  // Flags whether this memory supports CBO.zero. Note that main memory regions must
  // have this set.
  supportsCboZero                  : bool,
}

struct PMA_Region = {
  base       : physaddr,
  size       : physaddrbits,
  attributes : PMA,
}

// Get the first PMA that matches a given address range.
function matching_pma(pmas : list(PMA_Region), physaddr(addr) : physaddr, width : mem_access_width) -> option(PMA_Region) = {
  match pmas {
    [||] => None(),
    pma :: rest => {
      if range_subset(addr, addr + width, physaddr_bits(pma.base), physaddr_bits(pma.base) + pma.size)
      then Some(pma)
      else matching_pma(rest, physaddr(addr), width)
    },
  }
}

// Printing to a string.
function pma_attributes_to_str(attr : PMA) -> string =
  (if attr.cacheable then " cacheable" else "") ^
  (if attr.coherent then " coherent" else "") ^
  (if attr.executable then " executable" else "") ^
  (if attr.readable then " readable" else "") ^
  (if attr.writable then " writable" else "") ^
  (if attr.readIdempotent then " read-idempotent" else "") ^
  (if attr.writeIdempotent then " write-idempotent" else "") ^
  (if attr.relaxed then " relaxed" else "") ^
  (if attr.misalignmentCausesAccessFault then " misalignmentCausesAccessFault" else "") ^
  (if attr.misalignmentCausesAlignmentFault then " misalignmentCausesAlignmentFault" else "") ^
  " " ^ atomic_support_name(attr.atomicSupport) ^
  " " ^ reservability_name(attr.reservability) ^
  (if attr.taggable then " taggable" else "") ^
  (if attr.taggableAccessFaults then " taggableAccessFaults" else "") ^
  (if attr.supportsCboZero then " supportsCboZero" else "")

function pma_region_to_str(region : PMA_Region) -> string =
  "base: " ^ bits_str(physaddr_bits(region.base)) ^ " size: " ^ bits_str(region.size)
    ^ pma_attributes_to_str(region.attributes)

overload to_str = {pma_attributes_to_str, pma_region_to_str, atomic_support_name, reservability_name}

// The list of PMAs. The behaviour is undefined if these overlap.
register pma_regions : list(PMA_Region) = [||]


function accessFaultFromAccessType (accTy : AccessType(ext_access_type)) -> ExceptionType =
  match accTy {
    Execute()  => E_Fetch_Access_Fault(),
    Read(Data) => E_Load_Access_Fault(),
    _          => E_SAMO_Access_Fault()
  }

function alignmentFaultFromAccessType(accTy : AccessType(ext_access_type)) -> ExceptionType =
  match accTy {
    Execute()  => E_Fetch_Addr_Align(),
    Read(Data) => E_Load_Addr_Align(),
    _          => E_SAMO_Addr_Align()
  }

// Return true if the memory is taggable. We don't need to worry about checking
// the whole range since unaligned tagged reads/writes never happen.
function is_taggable(paddr : physaddr, width : mem_access_width) -> bool =
  match matching_pma(pma_regions, paddr, width) {
    None() => internal_error(__FILE__, __LINE__, "memory read/write in memory without PMAs; this should be impossible"),
    Some(struct { attributes, _ }) => attributes.taggable,
  }
