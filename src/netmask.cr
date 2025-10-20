require "socket"

# A Netmask represents an IPv4 or IPv6 CIDR network block.
# It can be constructed from CIDR notation strings, hostnames with masks,
# or Socket::IPAddress objects, and supports matching addresses in various formats.
struct Netmask
  VERSION = "0.1.0"

  @network : UInt32 | UInt128
  @bits : Int32

  # Creates a Netmask from a CIDR string (e.g., "192.168.0.0/24" or "3fff::/20")
  # or a hostname with CIDR notation (e.g., "example.host.name/32")
  # ameba:disable Metrics/CyclomaticComplexity
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

  # Creates a Netmask from a Socket::IPAddress and mask bits
  # ameba:disable Metrics/CyclomaticComplexity
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

  # Check if this is an IPv4 netmask
  def ipv4? : Bool
    case @network
    in UInt32
      true
    in UInt128
      false
    end
  end

  # Check if this is an IPv6 netmask
  def ipv6? : Bool
    !ipv4?
  end

  # Checks if an address matches this netmask
  def matches?(address : String) : Bool
    # Try parsing as IP address
    begin
      # Wrap IPv6 addresses in brackets for URI parsing
      test_addr = address.includes?(':') ? "[#{address}]" : address
      ip = Socket::IPAddress.parse("ip://#{test_addr}:0")
      matches?(ip)
    rescue
      false
    end
  end

  # Checks if a Socket::IPAddress matches this netmask
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

  # Checks if a UInt32 address (IPv4 in network byte order) matches this netmask
  def matches?(address : UInt32) : Bool
    return false unless ipv4?
    masked = apply_mask_ipv4(address)
    masked == @network
  end

  # Checks if a UInt128 address (IPv6 in network byte order) matches this netmask
  def matches?(address : UInt128) : Bool
    return false unless ipv6?
    masked = apply_mask_ipv6(address)
    masked == @network
  end

  # Checks if a StaticArray(UInt8, 4) address (IPv4 in network byte order) matches this netmask
  def matches?(address : StaticArray(UInt8, 4)) : Bool
    return false unless ipv4?
    addr_u32 = (address[0].to_u32 << 24) | (address[1].to_u32 << 16) |
               (address[2].to_u32 << 8) | address[3].to_u32
    matches?(addr_u32)
  end

  # Checks if a StaticArray(UInt16, 8) address (IPv6 in network byte order) matches this netmask
  def matches?(address : StaticArray(UInt16, 8)) : Bool
    return false unless ipv6?
    addr_u128 = 0_u128
    address.each_with_index do |segment, i|
      addr_u128 |= segment.to_u128 << (112 - i * 16)
    end
    matches?(addr_u128)
  end

  # Checks if a Slice(UInt8) address (network byte order, size 4 or 16) matches this netmask
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

  # Checks if a Slice(UInt16) address (IPv6 in network byte order, size 8) matches this netmask
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

  # Parse an IPv6 address string into a UInt128 (helper for constructors and instance methods)
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
