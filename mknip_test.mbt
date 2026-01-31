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

///|
test "extract_refs finds function calls" {
  let source =
    #| fn main {
    #|   let x = foo()
    #|   bar(x)
    #| }
  let refs = extract_refs(source)
  assert_true(refs.contains("foo"))
  assert_true(refs.contains("bar"))
  assert_true(refs.contains("x"))
}

///|
test "extract_refs finds type references" {
  let source =
    #| fn process(p: Point) -> Color {
    #|   Color::Red
    #| }
  let refs = extract_refs(source)
  assert_true(refs.contains("Point"))
  assert_true(refs.contains("Color"))
}

///|
test "extract_refs finds constructor usage" {
  let source =
    #| fn make_color() -> Color {
    #|   Red
    #| }
    #|
    #| fn match_color(c: Color) -> Int {
    #|   match c {
    #|     Red => 1
    #|     Blue => 2
    #|   }
    #| }
  let refs = extract_refs(source)
  assert_true(refs.contains("Red"))
  assert_true(refs.contains("Blue"))
}

///|
test "find_unused_exports detects unused pub fn" {
  let lib_src =
    #| pub fn used_fn() -> Int { 1 }
    #| pub fn unused_fn() -> Int { 2 }
  let main_src =
    #| fn main {
    #|   let _ = used_fn()
    #| }
  let files = [
    SourceFile::new("lib.mbt", lib_src),
    SourceFile::new("main.mbt", main_src),
  ]
  let unused = find_unused_exports(files)
  assert_eq(unused.length(), 1)
  assert_eq(unused[0].name, "unused_fn")
}

///|
test "find_unused_exports detects unused pub struct" {
  let types_src =
    #| pub struct UsedPoint { x: Int }
    #| pub struct UnusedPoint { y: Int }
  let main_src =
    #| fn process(p: UsedPoint) -> Int {
    #|   p.x
    #| }
  let files = [
    SourceFile::new("types.mbt", types_src),
    SourceFile::new("main.mbt", main_src),
  ]
  let unused = find_unused_exports(files)
  assert_eq(unused.length(), 1)
  assert_eq(unused[0].name, "UnusedPoint")
}

///|
test "find_unused_exports returns empty when all used" {
  let lib_src =
    #| pub fn add(a: Int, b: Int) -> Int { a + b }
  let main_src =
    #| fn main {
    #|   let _ = add(1, 2)
    #| }
  let files = [
    SourceFile::new("lib.mbt", lib_src),
    SourceFile::new("main.mbt", main_src),
  ]
  let unused = find_unused_exports(files)
  assert_eq(unused.length(), 0)
}
