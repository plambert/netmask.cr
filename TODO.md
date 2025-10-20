# TODO: Netmask Crystal Library Implementation

## Core Implementation

- [ ] Create `src/netmask.cr` main file with basic structure
- [ ] Define `Netmask` struct with IPv4 and IPv6 support
- [ ] Implement internal representation for storing network address and mask bits

## Constructors

- [ ] Implement `Netmask.new(cidr : String)` constructor
  - [ ] Parse IPv4 CIDR notation (e.g., "192.168.0.0/24")
  - [ ] Parse IPv6 CIDR notation (e.g., "3fff::/20")
  - [ ] Support hostname resolution with CIDR (e.g., "example.host.name/32")
  - [ ] Validate and normalize network addresses
- [ ] Implement `Netmask.new(ip : Socket::IPAddress, bits : Int32)` constructor
  - [ ] Extract IP address from Socket::IPAddress (ignore port)
  - [ ] Validate mask bits are appropriate for address family

## matches?(address) Method - Multiple Type Support

- [ ] Implement `matches?(address : String)`
  - [ ] Parse IPv4 string addresses
  - [ ] Parse IPv6 string addresses
- [ ] Implement `matches?(address : Socket::IPAddress)`
  - [ ] Validate it's IPv4 or IPv6 (raise ArgumentError otherwise)
  - [ ] Ignore port value
- [ ] Implement `matches?(address : UInt32)` for IPv4
- [ ] Implement `matches?(address : UInt128)` for IPv6
- [ ] Implement `matches?(address : StaticArray(UInt8, 4))` for IPv4
- [ ] Implement `matches?(address : StaticArray(UInt16, 8))` for IPv6
- [ ] Implement `matches?(address : Slice(UInt8))`
  - [ ] Support size 4 for IPv4
  - [ ] Support size 16 for IPv6
- [ ] Implement `matches?(address : Slice(UInt16))` for IPv6 (size 8)

## Core Matching Logic

- [ ] Implement network address masking algorithm
- [ ] Handle IPv4 vs IPv6 address family matching
- [ ] Ensure addresses are compared in network byte order

## Testing (spec/ directory)

- [ ] Create `spec/netmask_spec.cr` main spec file
- [ ] Create `spec/spec_helper.cr` if needed

### Constructor Tests
- [ ] Test IPv4 CIDR string constructor
- [ ] Test IPv6 CIDR string constructor
- [ ] Test hostname resolution constructor
- [ ] Test Socket::IPAddress constructor
- [ ] Test error handling for invalid inputs

### matches? Method Tests
- [ ] Test String input (IPv4 and IPv6)
- [ ] Test Socket::IPAddress input
- [ ] Test UInt32 input (IPv4)
- [ ] Test UInt128 input (IPv6)
- [ ] Test StaticArray(UInt8, 4) input
- [ ] Test StaticArray(UInt16, 8) input
- [ ] Test Slice(UInt8) input (sizes 4 and 16)
- [ ] Test Slice(UInt16) input (size 8)
- [ ] Test edge cases (network boundaries, broadcast addresses)
- [ ] Test address family mismatches (IPv4 netmask vs IPv6 address, etc.)

## Project Configuration

- [ ] Configure `shard.yml` with proper metadata
- [ ] Add appropriate dependencies if needed
- [ ] Set up proper project structure

## Documentation

- [ ] Add inline documentation for public methods
- [ ] Update README.md with usage examples
- [ ] Document supported formats and types

## Final Validation

- [ ] Run all specs and ensure they pass
- [ ] Test with real-world use cases
- [ ] Verify the library can be included in other Crystal programs
