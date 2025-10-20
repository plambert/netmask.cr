require "./spec_helper"

describe Netmask do
  describe "IPv4 constructors" do
    it "creates from IPv4 CIDR string" do
      netmask = Netmask.new("192.168.0.0/24")
      netmask.should_not be_nil
    end

    it "creates from Socket::IPAddress with mask bits" do
      ip = Socket::IPAddress.new("192.168.1.0", 0)
      netmask = Netmask.new(ip, 24)
      netmask.should_not be_nil
    end

    it "raises on invalid IPv4 mask bits" do
      ip = Socket::IPAddress.new("192.168.1.0", 0)
      expect_raises(ArgumentError, /Invalid IPv4 mask bits/) do
        Netmask.new(ip, 33)
      end
    end
  end

  describe "IPv6 constructors" do
    it "creates from IPv6 CIDR string" do
      netmask = Netmask.new("3fff::/20")
      netmask.should_not be_nil
    end

    it "creates from compressed IPv6 CIDR string" do
      netmask = Netmask.new("fe80::1/64")
      netmask.should_not be_nil
    end

    it "creates from Socket::IPAddress with mask bits" do
      ip = Socket::IPAddress.new("fe80::1", 0)
      netmask = Netmask.new(ip, 64)
      netmask.should_not be_nil
    end

    it "raises on invalid IPv6 mask bits" do
      ip = Socket::IPAddress.new("fe80::1", 0)
      expect_raises(ArgumentError, /Invalid IPv6 mask bits/) do
        Netmask.new(ip, 129)
      end
    end
  end

  describe "matches? with String addresses" do
    it "matches IPv4 addresses in range" do
      netmask = Netmask.new("192.168.0.0/24")
      netmask.matches?("192.168.0.1").should be_true
      netmask.matches?("192.168.0.254").should be_true
      netmask.matches?("192.168.0.0").should be_true
    end

    it "does not match IPv4 addresses out of range" do
      netmask = Netmask.new("192.168.0.0/24")
      netmask.matches?("192.168.1.0").should be_false
      netmask.matches?("192.167.0.1").should be_false
      netmask.matches?("10.0.0.1").should be_false
    end

    it "matches IPv6 addresses in range" do
      netmask = Netmask.new("3fff::/20")
      netmask.matches?("3fff::1").should be_true
      netmask.matches?("3fff:0fff:ffff:ffff:ffff:ffff:ffff:ffff").should be_true
    end

    it "does not match IPv6 addresses out of range" do
      netmask = Netmask.new("3fff::/20")
      netmask.matches?("3f00::1").should be_false
      netmask.matches?("4000::1").should be_false
      netmask.matches?("3fff:1000::1").should be_false
    end

    it "does not match IPv6 address against IPv4 netmask" do
      netmask = Netmask.new("192.168.0.0/24")
      netmask.matches?("fe80::1").should be_false
    end

    it "does not match IPv4 address against IPv6 netmask" do
      netmask = Netmask.new("fe80::/64")
      netmask.matches?("192.168.0.1").should be_false
    end
  end

  describe "matches? with Socket::IPAddress" do
    it "matches IPv4 Socket::IPAddress in range" do
      netmask = Netmask.new("192.168.0.0/24")
      ip = Socket::IPAddress.new("192.168.0.100", 8080)
      netmask.matches?(ip).should be_true
    end

    it "does not match IPv4 Socket::IPAddress out of range" do
      netmask = Netmask.new("192.168.0.0/24")
      ip = Socket::IPAddress.new("192.168.1.100", 8080)
      netmask.matches?(ip).should be_false
    end

    it "matches IPv6 Socket::IPAddress in range" do
      netmask = Netmask.new("fe80::/64")
      ip = Socket::IPAddress.new("fe80::1234:5678", 8080)
      netmask.matches?(ip).should be_true
    end

    it "does not match IPv6 Socket::IPAddress out of range" do
      netmask = Netmask.new("fe80::/64")
      ip = Socket::IPAddress.new("fe81::1234:5678", 8080)
      netmask.matches?(ip).should be_false
    end
  end

  describe "matches? with UInt32 (IPv4)" do
    it "matches UInt32 addresses in range" do
      netmask = Netmask.new("192.168.0.0/24")
      # 192.168.0.100 = 0xC0A80064
      addr = 0xC0A80064_u32
      netmask.matches?(addr).should be_true
    end

    it "does not match UInt32 addresses out of range" do
      netmask = Netmask.new("192.168.0.0/24")
      # 192.168.1.100 = 0xC0A80164
      addr = 0xC0A80164_u32
      netmask.matches?(addr).should be_false
    end

    it "does not match UInt32 against IPv6 netmask" do
      netmask = Netmask.new("fe80::/64")
      addr = 0xC0A80064_u32
      netmask.matches?(addr).should be_false
    end
  end

  describe "matches? with UInt128 (IPv6)" do
    it "matches UInt128 addresses in range" do
      netmask = Netmask.new("3fff::/20")
      # 3fff::1
      addr = 0x3fff0000000000000000000000000001_u128
      netmask.matches?(addr).should be_true
    end

    it "does not match UInt128 addresses out of range" do
      netmask = Netmask.new("3fff::/20")
      # 4000::1
      addr = 0x40000000000000000000000000000001_u128
      netmask.matches?(addr).should be_false
    end

    it "does not match UInt128 against IPv4 netmask" do
      netmask = Netmask.new("192.168.0.0/24")
      addr = 0x3fff0000000000000000000000000001_u128
      netmask.matches?(addr).should be_false
    end
  end

  describe "matches? with StaticArray(UInt8, 4) (IPv4)" do
    it "matches IPv4 byte arrays in range" do
      netmask = Netmask.new("192.168.0.0/24")
      addr = StaticArray[192_u8, 168_u8, 0_u8, 100_u8]
      netmask.matches?(addr).should be_true
    end

    it "does not match IPv4 byte arrays out of range" do
      netmask = Netmask.new("192.168.0.0/24")
      addr = StaticArray[192_u8, 168_u8, 1_u8, 100_u8]
      netmask.matches?(addr).should be_false
    end

    it "does not match IPv4 byte array against IPv6 netmask" do
      netmask = Netmask.new("fe80::/64")
      addr = StaticArray[192_u8, 168_u8, 0_u8, 100_u8]
      netmask.matches?(addr).should be_false
    end
  end

  describe "matches? with StaticArray(UInt16, 8) (IPv6)" do
    it "matches IPv6 segment arrays in range" do
      netmask = Netmask.new("3fff::/20")
      # 3fff::1
      addr = StaticArray[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(addr).should be_true
    end

    it "does not match IPv6 segment arrays out of range" do
      netmask = Netmask.new("3fff::/20")
      # 4000::1
      addr = StaticArray[0x4000_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(addr).should be_false
    end

    it "does not match IPv6 segment array against IPv4 netmask" do
      netmask = Netmask.new("192.168.0.0/24")
      addr = StaticArray[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(addr).should be_false
    end
  end

  describe "matches? with Slice(UInt8)" do
    it "matches IPv4 byte slices (size 4) in range" do
      netmask = Netmask.new("192.168.0.0/24")
      bytes = Slice[192_u8, 168_u8, 0_u8, 100_u8]
      netmask.matches?(bytes).should be_true
    end

    it "does not match IPv4 byte slices out of range" do
      netmask = Netmask.new("192.168.0.0/24")
      bytes = Slice[192_u8, 168_u8, 1_u8, 100_u8]
      netmask.matches?(bytes).should be_false
    end

    it "matches IPv6 byte slices (size 16) in range" do
      netmask = Netmask.new("3fff::/20")
      # 3fff::1
      bytes = Slice[0x3f_u8, 0xff_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8,
        0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 1_u8]
      netmask.matches?(bytes).should be_true
    end

    it "does not match IPv6 byte slices out of range" do
      netmask = Netmask.new("3fff::/20")
      # 4000::1
      bytes = Slice[0x40_u8, 0x00_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8,
        0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 1_u8]
      netmask.matches?(bytes).should be_false
    end

    it "raises on invalid slice size" do
      netmask = Netmask.new("192.168.0.0/24")
      bytes = Slice[192_u8, 168_u8, 0_u8]
      expect_raises(ArgumentError, /Invalid slice size/) do
        netmask.matches?(bytes)
      end
    end
  end

  describe "matches? with Slice(UInt16)" do
    it "matches IPv6 segment slices in range" do
      netmask = Netmask.new("3fff::/20")
      # 3fff::1
      segments = Slice[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(segments).should be_true
    end

    it "does not match IPv6 segment slices out of range" do
      netmask = Netmask.new("3fff::/20")
      # 4000::1
      segments = Slice[0x4000_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(segments).should be_false
    end

    it "does not match IPv6 segment slice against IPv4 netmask" do
      netmask = Netmask.new("192.168.0.0/24")
      segments = Slice[0x3fff_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 1_u16]
      netmask.matches?(segments).should be_false
    end

    it "raises on invalid slice size" do
      netmask = Netmask.new("3fff::/20")
      segments = Slice[0x3fff_u16, 0_u16, 0_u16, 0_u16]
      expect_raises(ArgumentError, /Invalid slice size/) do
        netmask.matches?(segments)
      end
    end
  end

  describe "edge cases" do
    it "handles /32 IPv4 netmask (single host)" do
      netmask = Netmask.new("192.168.0.1/32")
      netmask.matches?("192.168.0.1").should be_true
      netmask.matches?("192.168.0.2").should be_false
    end

    it "handles /0 IPv4 netmask (all addresses)" do
      netmask = Netmask.new("0.0.0.0/0")
      netmask.matches?("192.168.0.1").should be_true
      netmask.matches?("10.0.0.1").should be_true
      netmask.matches?("255.255.255.255").should be_true
    end

    it "handles /128 IPv6 netmask (single host)" do
      netmask = Netmask.new("fe80::1/128")
      netmask.matches?("fe80::1").should be_true
      netmask.matches?("fe80::2").should be_false
    end

    it "handles /0 IPv6 netmask (all addresses)" do
      netmask = Netmask.new("::/0")
      netmask.matches?("fe80::1").should be_true
      netmask.matches?("2001:db8::1").should be_true
    end

    it "properly applies network mask on construction" do
      # Creating with host bits set should normalize to network address
      netmask = Netmask.new("192.168.0.100/24")
      # Should match network range, not just the host
      netmask.matches?("192.168.0.1").should be_true
      netmask.matches?("192.168.0.254").should be_true
    end

    it "handles common IPv4 subnet masks" do
      netmask8 = Netmask.new("10.0.0.0/8")
      netmask8.matches?("10.255.255.255").should be_true
      netmask8.matches?("11.0.0.0").should be_false

      netmask16 = Netmask.new("172.16.0.0/16")
      netmask16.matches?("172.16.255.255").should be_true
      netmask16.matches?("172.17.0.0").should be_false
    end

    it "handles common IPv6 prefix lengths" do
      netmask64 = Netmask.new("fe80::/64")
      netmask64.matches?("fe80::ffff:ffff:ffff:ffff").should be_true
      netmask64.matches?("fe80:0:0:1::1").should be_false

      netmask48 = Netmask.new("2001:db8::/48")
      netmask48.matches?("2001:db8:0:ffff::1").should be_true
      netmask48.matches?("2001:db8:1:0::1").should be_false
    end
  end
end
