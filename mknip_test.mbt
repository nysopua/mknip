///|
test "extract_pub_symbols finds pub fn" {
  let source =
    #| pub fn hello() -> String {
    #|   "hello"
    #| }
    #|
    #| fn private_fn() -> Unit {
    #|   ()
    #| }
  let symbols = extract_pub_symbols(source, "test.mbt")
  assert_eq(symbols.length(), 1)
  assert_eq(symbols[0].name, "hello")
  assert_true(symbols[0].kind is Fn)
}

///|
test "extract_pub_symbols finds pub struct and enum" {
  let source =
    #| pub struct Point {
    #|   x: Int
    #|   y: Int
    #| }
    #|
    #| pub enum Color {
    #|   Red
    #|   Green
    #| }
    #|
    #| struct Private {}
  let symbols = extract_pub_symbols(source, "test.mbt")
  assert_eq(symbols.length(), 2)
  let names = symbols.map(fn(s) { s.name })
  assert_true(names.contains("Point"))
  assert_true(names.contains("Color"))
}

///|
test "extract_pub_symbols finds pub trait" {
  let source =
    #| pub trait Show {
    #|   show(Self) -> String
    #| }
  let symbols = extract_pub_symbols(source, "test.mbt")
  assert_eq(symbols.length(), 1)
  assert_eq(symbols[0].name, "Show")
  assert_true(symbols[0].kind is Trait)
}

///|
test "extract_pub_symbols finds pub let and const" {
  let source =
    #| pub let value = 42
    #| pub const PI = 3.14
    #| let private_val = 0
  let symbols = extract_pub_symbols(source, "test.mbt")
  assert_eq(symbols.length(), 2)
}
