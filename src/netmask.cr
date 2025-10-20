require "socket"

# A `Netmask` represents an IPv4 or IPv6 CIDR network block.
#
# A `Netmask` is typically created with a CIDR notation string:
#
# ```
# ipv4 = Netmask.new "192.168.0.0/24"
# ipv6 = Netmask.new "fe80::/64"
# ```
#
# It can also be created from a hostname (which will be resolved via DNS):
#
# ```
# host = Netmask.new "example.com/32"
# ```
#
# Or from a `Socket::IPAddress` and prefix length:
#
# ```
# ip = Socket::IPAddress.new "192.168.1.0", 0
# netmask = Netmask.new ip, 24
# ```
#
# Once created, a `Netmask` can test whether IP addresses fall within its range
# using the `#matches?` method, which accepts addresses in multiple formats:
#
# ```
# netmask = Netmask.new "192.168.0.0/24"
#
# # String addresses
# netmask.matches? "192.168.0.100" # => true
# netmask.matches? "192.168.1.100" # => false
#
# # Socket::IPAddress (port is ignored)
# ip = Socket::IPAddress.new "192.168.0.50", 8080
# netmask.matches? ip # => true
#
# # Raw integer values (network byte order)
# netmask.matches? 0xC0A80064_u32 # => true (192.168.0.100)
#
# # Byte arrays
# netmask.matches? StaticArray[192_u8, 168_u8, 0_u8, 100_u8] # => true
# netmask.matches? Slice[192_u8, 168_u8, 0_u8, 100_u8]       # => true
# ```
#
# ## IPv4 and IPv6 Support
#
# `Netmask` uses Crystal's union types to efficiently store either IPv4 or IPv6
# network addresses. The network address is stored internally as either `UInt32`
# (for IPv4) or `UInt128` (for IPv6). The address family is automatically
# determined based on the input format.
#
# ```
# ipv4 = Netmask.new "10.0.0.0/8"
# ipv4.ipv4? # => true
# ipv4.ipv6? # => false
#
# ipv6 = Netmask.new "2001:db8::/32"
# ipv6.ipv4? # => false
# ipv6.ipv6? # => true
# ```
#
# ## Network Mask Application
#
# When a `Netmask` is created, the network address is automatically normalized
# by applying the mask. This means host bits are zeroed out:
#
# ```
# netmask = Netmask.new "192.168.0.100/24"
# netmask.matches? "192.168.0.1"   # => true
# netmask.matches? "192.168.0.254" # => true
# ```
#
# ## Address Family Matching
#
# A `Netmask` will only match addresses of the same address family. IPv4 netmasks
# will not match IPv6 addresses and vice versa:
#
# ```
# ipv4_net = Netmask.new "192.168.0.0/24"
# ipv4_net.matches? "fe80::1" # => false
#
# ipv6_net = Netmask.new "fe80::/64"
# ipv6_net.matches? "192.168.0.1" # => false
# ```
struct Netmask
  #VERSION = "0.1.0"
  VERSION    = {{ system("#{__DIR__}/../tools/get-version.sh").stringify }}

  @network : UInt32 | UInt128
  @bits : Int32

  # Creates a new `Netmask` from a CIDR notation string.
  #
  # The *cidr* parameter must be in the format `"address/prefix_length"`,
  # where the address can be:
  # - An IPv4 address (e.g., `"192.168.0.0/24"`)
  # - An IPv6 address (e.g., `"fe80::/64"`)
  # - A hostname that resolves to an IP address (e.g., `"example.com/32"`)
  #
  # The prefix length specifies how many leading bits define the network portion.
  # For IPv4, this must be between 0 and 32. For IPv6, this must be between 0 and 128.
  #
  # The network address is automatically normalized by applying the mask, so host
  # bits in the address portion are ignored:
  #
  # ```
  # netmask = Netmask.new "192.168.0.100/24"
  # netmask.matches? "192.168.0.1" # => true
  # ```
  #
  # IPv6 addresses can use compressed notation:
  #
  # ```
  # netmask = Netmask.new "fe80::1/64"
  # netmask.matches? "fe80::abcd" # => true
  # ```
  #
  # Hostnames are resolved via DNS:
  #
  # ```
  # netmask = Netmask.new "localhost/32"
  # netmask.matches? "127.0.0.1" # => true
  # ```
  #
  # Raises `ArgumentError` if:
  # - The string is not in valid CIDR notation (must contain exactly one `/`)
  # - The address cannot be parsed or resolved
  # - The prefix length is out of range for the address family
  #
  # ```
  # Netmask.new "192.168.0.0/33" # raises ArgumentError (IPv4 max is /32)
  # Netmask.new "192.168.0.0"    # raises ArgumentError (missing prefix)
  # Netmask.new "invalid/24"     # raises ArgumentError (cannot resolve)
  # ```
  def initialize(cidr : String)
    parts = cidr.split('/')
    raise ArgumentError.new("Invalid CIDR notation: #{cidr}") if parts.size != 2

    address_str = parts[0]
    bits = parts[1].to_i

    # Try to resolve as IP address first, then as hostname if that fails
    ip_addr = begin
      # Wrap IPv6 addresses in brackets for URI parsing
      test_addr = address_str.includes?(':') ? "[#{address_str}]" : address_str
      Socket::IPAddress.parse("ip://#{test_addr}:0")
    rescue
      # Try DNS resolution
      addrinfo = Socket::Addrinfo.resolve(address_str, "0", type: Socket::Type::STREAM).first
      addrinfo.ip_address
    end

    # Now initialize based on the IP address
    @bits = bits

    case ip_addr.family
    when Socket::Family::INET
      raise ArgumentError.new("Invalid IPv4 mask bits: #{bits}") if bits < 0 || bits > 32

      # Parse IPv4 address into UInt32
      octets = ip_addr.address.split('.').map(&.to_u8)
      addr_u32 = (octets[0].to_u32 << 24) | (octets[1].to_u32 << 16) |
                 (octets[2].to_u32 << 8) | octets[3].to_u32

      # Apply mask
      if bits == 0
        @network = 0_u32
      elsif bits >= 32
        @network = addr_u32
      else
        mask = ~((1_u32 << (32 - bits)) - 1)
        @network = addr_u32 & mask
      end
    when Socket::Family::INET6
      raise ArgumentError.new("Invalid IPv6 mask bits: #{bits}") if bits < 0 || bits > 128

      # Parse IPv6 address into UInt128
      addr_u128 = parse_ipv6_to_u128(ip_addr.address)

      # Apply mask
      if bits == 0
        @network = 0_u128
      elsif bits >= 128
        @network = addr_u128
      else
        mask = ~((1_u128 << (128 - bits)) - 1)
        @network = addr_u128 & mask
      end
    else
      raise ArgumentError.new("Unsupported address family: #{ip_addr.family}")
    end
  end

  # Creates a new `Netmask` from a `Socket::IPAddress` and prefix length.
  #
  # The *ip* parameter provides the network address, and *bits* specifies
  # the prefix length (number of leading bits that define the network).
  #
  # For IPv4 addresses, *bits* must be between 0 and 32.
  # For IPv6 addresses, *bits* must be between 0 and 128.
  #
  # The port number in the `Socket::IPAddress` is ignored:
  #
  # ```
  # ip = Socket::IPAddress.new "192.168.1.0", 8080
  # netmask = Netmask.new ip, 24
  # netmask.matches? "192.168.1.100" # => true
  # ```
  #
  # Works with both IPv4 and IPv6:
  #
  # ```
  # ipv4 = Socket::IPAddress.new "10.0.0.0", 0
  # net4 = Netmask.new ipv4, 8
  # net4.matches? "10.255.255.255" # => true
  #
  # ipv6 = Socket::IPAddress.new "fe80::1", 0
  # net6 = Netmask.new ipv6, 64
  # net6.matches? "fe80::ffff" # => true
  # ```
  #
  # Raises `ArgumentError` if:
  # - The prefix length is negative
  # - The prefix length exceeds the maximum for the address family (32 for IPv4, 128 for
  #   IPv6)
  # - The address family is not IPv4 or IPv6
  #
  # ```
  # ip = Socket::IPAddress.new "192.168.0.0", 0
  # Netmask.new ip, 33 # raises ArgumentError
  # Netmask.new ip, -1 # raises ArgumentError
  # ```
  def initialize(ip : Socket::IPAddress, bits : Int32)
    @bits = bits

    case ip.family
    when Socket::Family::INET
      raise ArgumentError.new("Invalid IPv4 mask bits: #{bits}") if bits < 0 || bits > 32

      # Parse IPv4 address into UInt32
      octets = ip.address.split('.').map(&.to_u8)
      addr_u32 = (octets[0].to_u32 << 24) | (octets[1].to_u32 << 16) |
                 (octets[2].to_u32 << 8) | octets[3].to_u32

      # Apply mask
      if bits == 0
        @network = 0_u32
      elsif bits >= 32
        @network = addr_u32
      else
        mask = ~((1_u32 << (32 - bits)) - 1)
        @network = addr_u32 & mask
      end
    when Socket::Family::INET6
      raise ArgumentError.new("Invalid IPv6 mask bits: #{bits}") if bits < 0 || bits > 128

      # Parse IPv6 address into UInt128
      addr_u128 = parse_ipv6_to_u128(ip.address)

      # Apply mask
      if bits == 0
        @network = 0_u128
      elsif bits >= 128
        @network = addr_u128
      else
        mask = ~((1_u128 << (128 - bits)) - 1)
        @network = addr_u128 & mask
      end
    else
      raise ArgumentError.new("Unsupported address family: #{ip.family}")
    end
  end

  # Returns `true` if this netmask represents an IPv4 network, `false` otherwise.
  #
  # ```
  # ipv4 = Netmask.new "192.168.0.0/24"
  # ipv4.ipv4? # => true
  #
  # ipv6 = Netmask.new "fe80::/64"
  # ipv6.ipv4? # => false
  # ```
  def ipv4? : Bool
    case @network
    in UInt32
      true
    in UInt128
      false
    end
  end

  # Returns `true` if this netmask represents an IPv6 network, `false` otherwise.
  #
  # ```
  # ipv6 = Netmask.new "fe80::/64"
  # ipv6.ipv6? # => true
  #
  # ipv4 = Netmask.new "192.168.0.0/24"
  # ipv4.ipv6? # => false
  # ```
  def ipv6? : Bool
    !ipv4?
  end

  # Returns `true` if the given string *address* falls within this network block.
  #
  # The *address* can be an IPv4 address (e.g., `"192.168.0.1"`) or an IPv6
  # address (e.g., `"fe80::1"`). IPv6 addresses can use compressed notation.
  #
  # Returns `false` if:
  # - The address is not within the network range
  # - The address is invalid or cannot be parsed
  # - The address family doesn't match the netmask's family
  #
  # ```
  # netmask = Netmask.new "192.168.0.0/24"
  # netmask.matches? "192.168.0.1"   # => true
  # netmask.matches? "192.168.0.254" # => true
  # netmask.matches? "192.168.1.1"   # => false
  # netmask.matches? "invalid"       # => false
  # netmask.matches? "fe80::1"       # => false (wrong family)
  # ```
  #
  # IPv6 example:
  #
  # ```
  # netmask = Netmask.new "fe80::/64"
  # netmask.matches? "fe80::1"         # => true
  # netmask.matches? "fe80::ffff:ffff" # => true
  # netmask.matches? "fe81::1"         # => false
  # ```
  def matches?(address : String) : Bool
    # Wrap IPv6 addresses in brackets for URI parsing
    test_addr = address.includes?(':') ? "[#{address}]" : address
    ip = Socket::IPAddress.parse("ip://#{test_addr}:0")
    matches?(ip)
  rescue
    false
  end

  # Returns `true` if the given `Socket::IPAddress` falls within this network block.
  #
  # The port number in *address* is ignored; only the IP address is used for matching.
  #
  # Returns `false` if the address is not within the network range or if the
  # address family doesn't match the netmask's family.
  #
  # ```
  # netmask = Netmask.new "192.168.0.0/24"
  # ip = Socket::IPAddress.new "192.168.0.100", 8080
  # netmask.matches? ip # => true (port 8080 is ignored)
  #
  # ip2 = Socket::IPAddress.new "10.0.0.1", 80
  # netmask.matches? ip2 # => false
  # ```
  #
  # Raises `ArgumentError` if the address family is not IPv4 or IPv6:
  #
  # ```
  # # Assuming a hypothetical unsupported address type
  # netmask.matches? unsupported_addr # raises ArgumentError
  # ```
  def matches?(address : Socket::IPAddress) : Bool
    case address.family
    when Socket::Family::INET
      return false unless ipv4?
      octets = address.address.split('.').map(&.to_u8)
      addr_u32 = (octets[0].to_u32 << 24) | (octets[1].to_u32 << 16) |
                 (octets[2].to_u32 << 8) | octets[3].to_u32
      matches?(addr_u32)
    when Socket::Family::INET6
      return false unless ipv6?
      matches?(parse_ipv6(address.address))
    else
      raise ArgumentError.new("Unsupported address family: #{address.family}")
    end
  end

  # Returns `true` if the given `UInt32` *address* (in network byte order) falls within
  # this network block.
  #
  # This overload is only valid for IPv4 netmasks. Returns `false` if called on an IPv6
  # netmask.
  #
  # The address must be in network byte order (big-endian), with the most significant
  # byte representing the first octet:
  #
  # ```
  # netmask = Netmask.new "192.168.0.0/24"
  # # 192.168.0.100 = 0xC0A80064
  # netmask.matches? 0xC0A80064_u32 # => true
  # netmask.matches? 0xC0A80164_u32 # => false (192.168.1.100)
  # ```
  #
  # Returns `false` when called on an IPv6 netmask:
  #
  # ```
  # ipv6_net = Netmask.new "fe80::/64"
  # ipv6_net.matches? 0xC0A80064_u32 # => false
  # ```
  def matches?(address : UInt32) : Bool
    return false unless ipv4?
    masked = apply_mask_ipv4(address)
    masked == @network
  end

  # Returns `true` if the given `UInt128` *address* (in network byte order) falls within
  # this network block.
  #
  # This overload is only valid for IPv6 netmasks. Returns `false` if called on an IPv4
  # netmask.
  #
  # The address must be in network byte order (big-endian):
  #
  # ```
  # netmask = Netmask.new "fe80::/64"
  # # fe80::1 = 0xfe800000000000000000000000000001
  # netmask.matches? 0xfe800000000000000000000000000001_u128 # => true
  # netmask.matches? 0xfe810000000000000000000000000001_u128 # => false
  # ```
  #
  # Returns `false` when called on an IPv4 netmask:
  #
  # ```
  # ipv4_net = Netmask.new "192.168.0.0/24"
  # ipv4_net.matches? 0xfe800000000000000000000000000001_u128 # => false
  # ```
  def matches?(address : UInt128) : Bool
    return false unless ipv6?
    masked = apply_mask_ipv6(address)
    masked == @network
  end

  # Returns `true` if the given byte array *address* (IPv4 in network byte order) falls
  # within this network block.
  #
  # This overload is only valid for IPv4 netmasks. Returns `false` if called on an IPv6
  # netmask.
  #
  # The array must contain exactly 4 bytes representing the IPv4 address in network byte
  # order:
  #
  # ```
  # netmask = Netmask.new "192.168.0.0/24"
  # addr = StaticArray[192_u8, 168_u8, 0_u8, 100_u8]
  # netmask.matches? addr # => true
  #
  # addr2 = StaticArray[192_u8, 168_u8, 1_u8, 100_u8]
  # netmask.matches? addr2 # => false
  # ```
  def matches?(address : StaticArray(UInt8, 4)) : Bool
    return false unless ipv4?
    addr_u32 = (address[0].to_u32 << 24) | (address[1].to_u32 << 16) |
               (address[2].to_u32 << 8) | address[3].to_u32
    matches?(addr_u32)
  end

  # Returns `true` if the given segment array *address* (IPv6 in network byte order) falls
  # within this network block.
  #
  # This overload is only valid for IPv6 netmasks. Returns `false` if called on an IPv4
  # netmask.
  #
  # The array must contain exactly 8 16-bit segments representing the IPv6 address in
  # network byte order:
  #
  # ```
  # netmask = Netmask.new "fe80::/64"
  # # fe80::1
  # addr = StaticArray[0xfe80_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
  # netmask.matches? addr # => true
  #
  # # fe81::1
  # addr2 = StaticArray[0xfe81_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
  # netmask.matches? addr2 # => false
  # ```
  def matches?(address : StaticArray(UInt16, 8)) : Bool
    return false unless ipv6?
    addr_u128 = 0_u128
    address.each_with_index do |segment, i|
      addr_u128 |= segment.to_u128 << (112 - i * 16)
    end
    matches?(addr_u128)
  end

  # Returns `true` if the given byte slice *address* (in network byte order) falls within
  # this network block.
  #
  # The slice size determines the address family:
  # - Size 4: Interpreted as IPv4 address (only matches IPv4 netmasks)
  # - Size 16: Interpreted as IPv6 address (only matches IPv6 netmasks)
  #
  # ```
  # ipv4_net = Netmask.new "192.168.0.0/24"
  # ipv4_bytes = Slice[192_u8, 168_u8, 0_u8, 100_u8]
  # ipv4_net.matches? ipv4_bytes # => true
  #
  # ipv6_net = Netmask.new "fe80::/64"
  # ipv6_bytes = Slice[0xfe_u8, 0x80_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8,
  #   0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 1_u8]
  # ipv6_net.matches? ipv6_bytes # => true
  # ```
  #
  # Raises `ArgumentError` if the slice size is not 4 or 16:
  #
  # ```
  # netmask = Netmask.new "192.168.0.0/24"
  # bad_slice = Slice[192_u8, 168_u8] # only 2 bytes
  # netmask.matches? bad_slice        # raises ArgumentError
  # ```
  def matches?(address : Slice(UInt8)) : Bool
    case address.size
    when 4
      return false unless ipv4?
      addr_u32 = (address[0].to_u32 << 24) | (address[1].to_u32 << 16) |
                 (address[2].to_u32 << 8) | address[3].to_u32
      matches?(addr_u32)
    when 16
      return false unless ipv6?
      addr_u128 = 0_u128
      address.each_with_index do |byte, i|
        addr_u128 |= byte.to_u128 << (120 - i * 8)
      end
      matches?(addr_u128)
    else
      raise ArgumentError.new("Invalid slice size: #{address.size}, expected 4 or 16")
    end
  end

  # Returns `true` if the given segment slice *address* (IPv6 in network byte order) falls
  # within this network block.
  #
  # This overload is only valid for IPv6 netmasks. Returns `false` if called on an IPv4
  # netmask.
  #
  # The slice must contain exactly 8 16-bit segments representing the IPv6 address:
  #
  # ```
  # netmask = Netmask.new "fe80::/64"
  # # fe80::1
  # segments = Slice[0xfe80_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
  # netmask.matches? segments # => true
  # ```
  #
  # Raises `ArgumentError` if the slice size is not 8:
  #
  # ```
  # netmask = Netmask.new "fe80::/64"
  # bad_slice = Slice[0xfe80_u16, 0_u16, 0_u16, 0_u16] # only 4 segments
  # netmask.matches? bad_slice                         # raises ArgumentError
  # ```
  def matches?(address : Slice(UInt16)) : Bool
    raise ArgumentError.new("Invalid slice size: #{address.size}, expected 8") if address.size != 8
    return false unless ipv6?
    addr_u128 = 0_u128
    address.each_with_index do |segment, i|
      addr_u128 |= segment.to_u128 << (112 - i * 16)
    end
    matches?(addr_u128)
  end

  # Apply IPv4 mask to an address
  private def apply_mask_ipv4(addr : UInt32) : UInt32
    if @bits == 0
      0_u32
    elsif @bits >= 32
      addr
    else
      mask = ~((1_u32 << (32 - @bits)) - 1)
      addr & mask
    end
  end

  # Apply IPv6 mask to an address
  private def apply_mask_ipv6(addr : UInt128) : UInt128
    if @bits == 0
      0_u128
    elsif @bits >= 128
      addr
    else
      mask = ~((1_u128 << (128 - @bits)) - 1)
      addr & mask
    end
  end

  # Parse an IPv6 address string into a UInt128
  private def parse_ipv6(address : String) : UInt128
    parse_ipv6_to_u128(address)
  end

  # Parse an IPv6 address string into a UInt128 (helper for constructors and instance
  # methods)
  private def parse_ipv6_to_u128(address : String) : UInt128
    # Split by :: to handle compression
    parts = address.split("::")

    if parts.size > 2
      raise ArgumentError.new("Invalid IPv6 address: #{address}")
    end

    segments = Array(UInt16).new(8, 0_u16)

    if parts.size == 1
      # No compression
      segs = parts[0].split(':')
      raise ArgumentError.new("Invalid IPv6 address: #{address}") if segs.size != 8
      segs.each_with_index do |seg, i|
        segments[i] = seg.to_u16(16)
      end
    else
      # Handle compression
      left = parts[0].empty? ? [] of String : parts[0].split(':')
      right = parts[1].empty? ? [] of String : parts[1].split(':')

      left.each_with_index do |seg, i|
        segments[i] = seg.to_u16(16)
      end

      right.reverse.each_with_index do |seg, i|
        segments[7 - i] = seg.to_u16(16)
      end
    end

    # Convert to UInt128
    result = 0_u128
    segments.each_with_index do |seg, i|
      result |= seg.to_u128 << (112 - i * 16)
    end
    result
  end
end
