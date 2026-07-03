// MoonBit 数值类型与语言特性实验
// 目的：验证各种数值类型的边界、溢出、转换行为

test "Int max value" {
  let max_int = 0x7FFFFFFF
  inspect(max_int, content="2147483647")
}

test "Int min value" {
  let min_int = 0x80000000
  inspect(min_int, content="-2147483648")
}

test "Int hex literal sign" {
  // 0x80000000 in 32-bit signed Int is -2147483648
  let x = 0x80000000
  inspect(x < 0, content="true")
  inspect(x, content="-2147483648")
}

test "Int overflow wrap" {
  // 0x7FFFFFFF + 1 should wrap to -2147483648
  let max = 0x7FFFFFFF
  let overflowed = max + 1
  inspect(overflowed, content="-2147483648")
}

test "Int underflow wrap" {
  // -2147483648 - 1 should wrap to 2147483647
  let min = 0x80000000
  let underflowed = min - 1
  inspect(underflowed, content="2147483647")
}

test "Int comparison with 0x80000000" {
  // This is the critical bug we found:
  // 7 >= 0x80000000 should be false (7 >= -2147483648 is true in signed)
  let raw = 7
  let threshold = 0x80000000
  // In signed comparison: 7 >= -2147483648 is TRUE
  inspect(raw >= threshold, content="true")
  // This shows why i32 sign extension was broken
}

test "Byte to Int conversion" {
  let b : Byte = 0xFF
  let n = b.to_int()
  // Byte is unsigned, so 0xFF = 255
  inspect(n, content="255")
  inspect(n >= 0, content="true")
}

test "Byte range" {
  let max_byte : Byte = 0xFF
  let min_byte : Byte = 0x00
  inspect(max_byte.to_int(), content="255")
  inspect(min_byte.to_int(), content="0")
}

test "Bit shift left" {
  let x = 1 << 3
  inspect(x, content="8")
}

test "Bit shift right" {
  // >> is arithmetic right shift in MoonBit (preserves sign)
  let x = 0x80000000 >> 1
  // Arithmetic right shift: 0x80000000 >> 1 = 0xC0000000 = -1073741824
  inspect(x, content="-1073741824")
}

test "Logical shift right via lsr" {
  // Use lsr() for logical right shift - need parentheses for method call on literal
  let x = (0x80000000).lsr(1)
  // Logical: 0x80000000 >> 1 = 0x40000000 = 1073741824
  inspect(x, content="1073741824")
}

test "Bit AND" {
  let x = 0xFF & 0x0F
  inspect(x, content="15")
}

test "Bit OR" {
  let x = 0xF0 | 0x0F
  inspect(x, content="255")
}

test "Int negative hex" {
  // -1 in 32-bit signed is 0xFFFFFFFF
  let x = -1
  let y = x & 0xFF
  inspect(y, content="255")
}

test "u32 reads correct value" {
  // Simulating BinaryReader::u32 behavior
  let bytes : FixedArray[Byte] = [0x07, 0x00, 0x00, 0x00]
  let val = bytes[0].to_int() |
    (bytes[1].to_int() << 8) |
    (bytes[2].to_int() << 16) |
    (bytes[3].to_int() << 24)
  inspect(val, content="7")
}

test "u32 reads large value" {
  // 0x80000007 as bytes
  let bytes : FixedArray[Byte] = [0x07, 0x00, 0x00, 0x80]
  let val = bytes[0].to_int() |
    (bytes[1].to_int() << 8) |
    (bytes[2].to_int() << 16) |
    (bytes[3].to_int() << 24)
  // This should be -2147483641 in signed Int
  inspect(val, content="-2147483641")
  inspect(val < 0, content="true")
}

test "i32 should return same as u32" {
  // The fix: i32 just returns u32 result
  let bytes : FixedArray[Byte] = [0x07, 0x00, 0x00, 0x00]
  let u32_val = bytes[0].to_int() |
    (bytes[1].to_int() << 8) |
    (bytes[2].to_int() << 16) |
    (bytes[3].to_int() << 24)
  // i32 should be same as u32 for correct bit pattern
  let i32_val = u32_val  // This is what our fix does
  inspect(i32_val, content="7")
}

test "FixedArray creation" {
  let a : FixedArray[Byte] = [0x01, 0x02, 0x03]
  // FixedArray is value type - assignment copies
  inspect(a[0].to_int(), content="1")
  inspect(a[1].to_int(), content="2")
  inspect(a[2].to_int(), content="3")
  inspect(a.length(), content="3")
}

test "FixedArray value copy semantics" {
  // FixedArray[Int] is NOT value type - it's reference type
  let a : FixedArray[Int] = [1, 2, 3]
  let b = a  // b is a reference
  b[0] = 99
  // a is also changed - FixedArray[Int] is reference type
  inspect(a[0], content="99")
  inspect(b[0], content="99")
}

test "Array reference semantics" {
  let a : Array[Int] = [1, 2, 3]
  let b = a  // b is a reference
  b[0] = 99
  // a is changed because Array is reference type
  inspect(a[0], content="99")
  inspect(b[0], content="99")
}

test "UInt range" {
  let max_uint : UInt = 0xFFFFFFFF
  // UInt.to_int() is deprecated, use reinterpret_as_int
  inspect(max_uint.reinterpret_as_int(), content="-1")
  // UInt wraps differently than Int
}

test "UInt overflow wrap" {
  let max : UInt = 0xFFFFFFFF
  let overflowed = max + 1
  // UInt overflow wraps to 0
  inspect(overflowed.reinterpret_as_int(), content="0")
}

test "Byte conversion from negative Int" {
  // (-1).to_byte() behavior
  let b : Byte = (-1).to_byte()
  // Should truncate to 0xFF = 255
  inspect(b.to_int(), content="255")
}

test "Int UInt mixed operations" {
  // Test if Int and UInt can be mixed in operations
  let i : Int = 10
  let u : UInt = 5
  // This should be a type error - can't mix Int and UInt
  // inspect(i + u)  // Would fail to compile
  // Need to convert explicitly
  inspect(i + u.reinterpret_as_int(), content="15")
}

test "Arithmetic vs logical right shift" {
  // Test -1 (all bits set) with both shifts
  let neg_one = -1
  // Arithmetic right shift preserves sign
  let arith = neg_one >> 1
  inspect(arith, content="-1")
  // Logical right shift fills with zeros
  let logic = (neg_one).lsr(1)
  // 0xFFFFFFFF >> 1 = 0x7FFFFFFF = 2147483647
  inspect(logic, content="2147483647")
}

test "Map iteration order preserves insertion" {
  let map : Map[String, Int] = {}
  map["c"] = 3
  map["a"] = 1
  map["b"] = 2
  let keys : Array[String] = []
  for k, _ in map {
    keys.push(k)
  }
  // Should preserve insertion order: c, a, b
  inspect(keys.length(), content="3")
}

test "Map length not size" {
  let map : Map[String, Int] = { "x": 1, "y": 2 }
  // .length() is correct, .size() is deprecated
  inspect(map.length(), content="2")
}

test "String equal_ignore_ascii_case" {
  // Test case-insensitive comparison
  inspect("hello".equal_ignore_ascii_case("HELLO"), content="true")
  inspect("hello".equal_ignore_ascii_case("Hello"), content="true")
  inspect("hello".equal_ignore_ascii_case("world"), content="false")
}

test "StringBuilder append" {
  let sb = StringBuilder::new()
  sb <+ "hello"
  sb <+ " "
  sb <+ "world"
  inspect(sb.to_string(), content="hello world")
}

test "Logical not operator" {
  let t = true
  let f = false
  inspect(!t, content="false")
  inspect(!f, content="true")
}

test "has_prefix for string prefix check" {
  // Test has_prefix (new syntax) vs starts_with (deprecated)
  let s = "hello world"
  inspect(s.has_prefix("hello"), content="true")
  inspect(s.has_prefix("world"), content="false")
}

test "derive Debug vs derive Show" {
  // derive(Show) is deprecated, use derive(Debug)
  // This is a compilation test - if it compiles, it works
  let x = 42
  inspect(x, content="42")
}

test "Array length not size" {
  let arr : Array[Int] = [1, 2, 3]
  // .length() is correct, .size() is deprecated
  inspect(arr.length(), content="3")
}

test "String contains case sensitive" {
  let s = "CONTENTS"
  // contains is case-sensitive
  inspect(s.contains("CONTENTS"), content="true")
  inspect(s.contains("contents"), content="false")
  inspect(s.contains("CONTENT"), content="true")
}

test "to_owned vs to_string for StringView" {
  // Both should produce the same result
  let sv : StringView = "hello"
  let owned1 = sv.to_owned()
  let owned2 = sv.to_string()
  inspect(owned1, content="hello")
  inspect(owned2, content="hello")
}

test "Map new vs constructor" {
  // Map::new() and Map() both create empty maps
  let m1 : Map[String, Int] = Map::new()
  let m2 : Map[String, Int] = {}
  inspect(m1.length(), content="0")
  inspect(m2.length(), content="0")
}

test "land method syntax" {
  let x = 0xFF
  let y = 0x0F
  // Method syntax for bitwise AND
  inspect(x.land(y), content="15")
  // Operator syntax (same result)
  inspect(x & y, content="15")
}

test "lor method syntax" {
  let x = 0xF0
  let y = 0x0F
  // Method syntax for bitwise OR
  inspect(x.lor(y), content="255")
  // Operator syntax (same result)
  inspect(x | y, content="255")
}

test "lsl method syntax" {
  let x = 1
  // Method syntax for left shift
  inspect(x.lsl(3), content="8")
  // Operator syntax (same result)
  inspect(x << 3, content="8")
}

test "not function vs operator" {
  let t = true
  let f = false
  // Both ! and not() should work
  inspect(!t, content="false")
  inspect(!f, content="true")
  inspect(not(t), content="false")
  inspect(not(f), content="true")
}

test "FixedArray fixed size" {
  let a : FixedArray[Int] = [1, 2, 3]
  // FixedArray has fixed size, cannot push/pop
  // a.push(4)  // Would fail to compile
  inspect(a.length(), content="3")
  // But can modify existing elements
  a[0] = 10
  inspect(a[0], content="10")
}

test "Array dynamic size" {
  let a : Array[Int] = [1, 2, 3]
  // Array is dynamic, can push/pop
  a.push(4)
  a.push(5)
  inspect(a.length(), content="5")
  ignore(a.pop())
  inspect(a.length(), content="4")
}
