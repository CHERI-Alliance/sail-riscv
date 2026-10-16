// Registers added for CHERI. Note that widened pre-existing registers are
// not included here. Their names will lack the extra "C".

// We don't need to add these to ext_read_CSR() or ext_write_CSR() since those
// functions are for XLEN reads/writes which will never go through the non-CHERI
// handle_csr_op().

function clause is_CSR_defined(0x03f) = cheri_registers_enabled() // ddc
// TODO: Once https://github.com/riscv/sail-riscv/pull/1140
// (is_CSR_accessible(csr, p, isWrite)) is merged, check
// `not(isWrite) | pcc_access_system_regs()` here for mtid/stid/utid.
function clause is_CSR_defined(0x37f) = cheri_registers_enabled() // mtidc
function clause is_CSR_defined(0x17f) = cheri_registers_enabled() & currentlyEnabled(Ext_S) // stidc
function clause is_CSR_defined(0x07f) = cheri_registers_enabled() & currentlyEnabled(Ext_U) // utidc
function clause is_CSR_defined(0x7bd) = cheri_registers_enabled() & debug_mode_active // drootcsel
function clause is_CSR_defined(0x7be) = cheri_registers_enabled() & debug_mode_active // drootc
function clause is_CSR_defined(0x7bf) = cheri_registers_enabled() & debug_mode_active // dddc


mapping clause csr_name_map = 0x03f <-> "ddc"
mapping clause csr_name_map = 0x37f <-> "mtidc"
mapping clause csr_name_map = 0x17f <-> "stidc"
mapping clause csr_name_map = 0x07f <-> "utidc"
mapping clause csr_name_map = 0x7bd <-> "drootcsel"
mapping clause csr_name_map = 0x7be <-> "drootc"
mapping clause csr_name_map = 0x7bf <-> "dddc"
