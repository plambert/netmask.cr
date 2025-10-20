# Netmask implementation in Crystal

Crystal is a programming language whose API is documented at https://crystal-lang.org/API/latest/ and whose syntax is documented at https://crystal-lang.org/reference/1.18/syntax_and_semantics/index.html

Create a `struct Netmask` that can contain either an IPv4 or IPv6 CIDR netmask.

I should be able to create it in these ways:

```
a = Netmask.new "192.168.0.0/24"
b = Netmask.new "3fff::/20"
c = Netmask.new "example.host.name/32"
d = Netmask.new ip, bits # where ip is a Socket::IPAddress and bits is an integer representing the mask
```

And I should be able to test an appropriate IP address for membership in the network range with a `matches?(address)` method. This method should accept the address value in these types:

* `String`
  - Like `192.168.1.73` or `fe80::1062:2bf2:ae43:2c71`
* `Socket::IPAddress`
  - Raising an `ArgumentError` if it is not an IPv4 or IPv6 address, and then ignoring the port value
* `UInt32 | UInt128`
  - Representing the raw unsigned integer value (network byte order) of the address
* `StaticArray(Uint8, 4) | StaticArray(UInt16, 8)`
  - Representing the address in network byte order
* `Slice(UInt8)`
  - Representing the address in network byte order, with a size of either 4 or 16
* `Slice(UInt16)`
  - Representing an IPv6 address in network byte order, with a size of 8

Write spec files in the `test/` directory to ensure that all of these constructors and match permutations work correctly.

The result must be a library I can include in any Crystal program to easily compare IP addresses to a Netmask without having to do difficult conversions myself.

# The Crystal programming language

To run Crystal tests using the `Spec` tools, run:

  `crystal spec -v --error-trace`

To reformat Crystal code and quickly find syntax errors, run:

  `crystal tool format src/ spec/`

# Source control requirements

Create a new branch for each TODO item being implemented.  Commit the implementation as it is created or updated, including after each test is written or updated.  Describe the changes clearly in the commit message but do not repeat the obvious things like what files were updated; summarize the _why_ and give less time to the _what_.

When a TODO item is completed, the tests are written and seem to be covering all reasonable cases, and all the tests are passing, commit the result and merge the branch into the `main` branch.


