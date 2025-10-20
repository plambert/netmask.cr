# netmask

A Crystal library for working with IPv4 and IPv6 CIDR network masks. Easily check if IP addresses belong to specific network ranges.

Documentation is published to [plambert.github.io/netmask.cr](https://plambert.github.io/netmask.cr/)

## Artificial Intelligence / LLM Contribution

This library was written by Claude Code using the Sonnet 4.5 model.  The resulting code was manually reviewed by the author listed below.  This was work that the author is entirely capable of having performed personally however it was a fun exercise in learning how to use Claude Code, and the author plans to support the library without the use of such tools in the future, except for advisory usage such as auto-completion and pointing out possible gaps in testing, etc.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     netmask:
       github: plambert/netmask.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "netmask"

# Create netmasks from CIDR notation
ipv4_net = Netmask.new "192.168.0.0/24"
ipv6_net = Netmask.new "3fff::/20"

# Create from hostname (resolves via DNS)
host_net = Netmask.new "example.host.name/32"

# Create from Socket::IPAddress
ip = Socket::IPAddress.new "192.168.1.0", 0
net = Netmask.new ip, 24 

# Check if addresses match the network
ipv4_net.matches? "192.168.0.100"   # => true
ipv4_net.matches? "192.168.1.100"   # => false

# Works with IPv6
ipv6_net.matches? "3fff::1"         # => true
ipv6_net.matches? "fe80::1"         # => false

# Multiple input types supported
ipv4_net.matches? 0xC0A80064_u32    # UInt32 (IPv4)
ipv6_net.matches? 0x3fff0000000000000000000000000001_u128   # UInt128 (IPv6)

# Byte arrays
ipv4_net.matches? StaticArray[192_u8, 168_u8, 0_u8, 100_u8] 
ipv6_net.matches? StaticArray[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16] 

# Slices
ipv4_net.matches? Slice[192_u8, 168_u8, 0_u8, 100_u8] 
ipv6_net.matches? Slice[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16] 

# Socket::IPAddress (port is ignored)
ip_addr = Socket::IPAddress.new("192.168.0.50", 8080)
ipv4_net.matches? ip_addr   # => true

# Check network type
ipv4_net.ipv4?  # => true
ipv4_net.ipv6?  # => false
```

## Supported Input Types for matches?

The `matches?` method accepts addresses in multiple formats:

- **String**: IPv4 (`"192.168.1.73"`) or IPv6 (`"fe80::1062:2bf2:ae43:2c71"`)
- **Socket::IPAddress**: Extracts IP and ignores port
- **UInt32**: IPv4 address in network byte order
- **UInt128**: IPv6 address in network byte order
- **StaticArray(UInt8, 4)**: IPv4 as 4 bytes
- **StaticArray(UInt16, 8)**: IPv6 as 8 16-bit segments
- **Slice(UInt8)**: IPv4 (size 4) or IPv6 (size 16) as bytes
- **Slice(UInt16)**: IPv6 as 8 16-bit segments (size 8)

## Development

Run tests:
```bash
crystal spec -v --error-trace
```

Format code:
```bash
crystal tool format src/ spec/
```

Run linter:
```bash
ameba -f json src/ spec/
```

## Contributing

1. Fork it (<https://github.com/plambert/netmask.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Paul M. Lambert](https://github.com/plambert) - creator and maintainer
