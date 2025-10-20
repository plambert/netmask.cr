# TODO: Netmask Crystal Library Implementation

## Core Implementation

- [x] Create `src/netmask.cr` main file with basic structure
- [x] Define `Netmask` struct with IPv4 and IPv6 support
- [x] Implement internal representation for storing network address and mask bits

## Constructors

- [x] Implement `Netmask.new(cidr : String)` constructor
  - [x] Parse IPv4 CIDR notation (e.g., "192.168.0.0/24")
  - [x] Parse IPv6 CIDR notation (e.g., "3fff::/20")
  - [x] Support hostname resolution with CIDR (e.g., "example.host.name/32")
  - [x] Validate and normalize network addresses
- [x] Implement `Netmask.new(ip : Socket::IPAddress, bits : Int32)` constructor
  - [x] Extract IP address from Socket::IPAddress (ignore port)
  - [x] Validate mask bits are appropriate for address family

## matches?(address) Method - Multiple Type Support

- [x] Implement `matches?(address : String)`
  - [x] Parse IPv4 string addresses
  - [x] Parse IPv6 string addresses
- [x] Implement `matches?(address : Socket::IPAddress)`
  - [x] Validate it's IPv4 or IPv6 (raise ArgumentError otherwise)
  - [x] Ignore port value
- [x] Implement `matches?(address : UInt32)` for IPv4
- [x] Implement `matches?(address : UInt128)` for IPv6
- [x] Implement `matches?(address : StaticArray(UInt8, 4))` for IPv4
- [x] Implement `matches?(address : StaticArray(UInt16, 8))` for IPv6
- [x] Implement `matches?(address : Slice(UInt8))`
  - [x] Support size 4 for IPv4
  - [x] Support size 16 for IPv6
- [x] Implement `matches?(address : Slice(UInt16))` for IPv6 (size 8)

## Core Matching Logic

- [x] Implement network address masking algorithm
- [x] Handle IPv4 vs IPv6 address family matching
- [x] Ensure addresses are compared in network byte order

## Testing (spec/ directory)

- [x] Create `spec/netmask_spec.cr` main spec file
- [x] Create `spec/spec_helper.cr` if needed

### Constructor Tests
- [x] Test IPv4 CIDR string constructor
- [x] Test IPv6 CIDR string constructor
- [x] Test hostname resolution constructor
- [x] Test Socket::IPAddress constructor
- [x] Test error handling for invalid inputs

### matches? Method Tests
- [x] Test String input (IPv4 and IPv6)
- [x] Test Socket::IPAddress input
- [x] Test UInt32 input (IPv4)
- [x] Test UInt128 input (IPv6)
- [x] Test StaticArray(UInt8, 4) input
- [x] Test StaticArray(UInt16, 8) input
- [x] Test Slice(UInt8) input (sizes 4 and 16)
- [x] Test Slice(UInt16) input (size 8)
- [x] Test edge cases (network boundaries, broadcast addresses)
- [x] Test address family mismatches (IPv4 netmask vs IPv6 address, etc.)

## Project Configuration

- [x] Configure `shard.yml` with proper metadata
- [x] Add appropriate dependencies if needed
- [x] Set up proper project structure

## Documentation

- [x] Add inline documentation for public methods
- [x] Update README.md with usage examples
- [x] Document supported formats and types

## Final Validation

- [x] Run all specs and ensure they pass
- [x] Test with real-world use cases
- [x] Verify the library can be included in other Crystal programs
