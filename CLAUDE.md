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

Review the documentation, especially the API documentation, to understand what the standard library offers to help.

Crystal supports union types, so you can represent the network data as a union like `UInt32 | UInt128`.  You can implement a `#ipv4?` method like this, if you call the network portion `@network`:

```
struct Netmask
  def ipv4? : Bool
    case @network
    in UInt32
      true
    in UInt128
      false
    end
  end
```

The `case <thing> ... in A ... in B ... end` syntax is great when you are testing a type because it requires that you have an `in` clause for every possibility. Since the type union is known at compile time, the above example is exhaustive and will compile fine. But when you are not doing an exhaustive test, or are sure that you want new possible values you are not explicitly listed to fall into an `else ...` clause.

There is an application installed called `ameba` that will identify problems with Crystal code.  A config file has been added to the repository, `.ameba.yml`, to ignore one warning that we do not care about.

A warning can be silenced in the code by adding a comment in the line before (it must be immediately before, and not on the same line).  The format for the comment is: `# ameba:disable Metrics/CyclomaticComplexity` where the second word is the identifier for the rule to be disabled.  Do this sparingly and only when certain that it is more readable and reliable to ignore the warning than to make code changes that avoid it.

To run this tool, you use `ameba -f json src/ spec/`.

# Source control requirements

Create a new branch for each TODO item being implemented.  Commit the implementation as it is created or updated, including after each test is written or updated.  Describe the changes clearly in the commit message but do not repeat the obvious things like what files were updated; summarize the _why_ and give less time to the _what_.

When a TODO item is completed, the tests are written and seem to be covering all reasonable cases, and all the tests are passing, commit the result and merge the branch into the `main` branch.


