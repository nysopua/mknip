///|
test "analyze_file finds pub fn" {
  let source =
    #| pub fn hello() -> String {
    #|   "hello"
    #| }
    #|
    #| fn private_fn() -> Unit {
    #|   ()
    #| }
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_eq(analysis.symbols.length(), 1)
  assert_eq(analysis.symbols[0].name, "hello")
  assert_true(analysis.symbols[0].kind is Fn)
}

///|
test "analyze_file finds pub struct and enum with variants" {
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
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  // Point + Color + Red + Green = 4
  assert_eq(analysis.symbols.length(), 4)
  let names = analysis.symbols.map(fn(s) { s.name })
  assert_true(names.contains("Point"))
  assert_true(names.contains("Color"))
  assert_true(names.contains("Red"))
  assert_true(names.contains("Green"))
}

///|
test "analyze_file finds pub trait" {
  let source =
    #| pub trait Show {
    #|   show(Self) -> String
    #| }
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_eq(analysis.symbols.length(), 1)
  assert_eq(analysis.symbols[0].name, "Show")
  assert_true(analysis.symbols[0].kind is Trait)
}

///|
test "analyze_file finds pub let and const" {
  let source =
    #| pub let value = 42
    #| pub const PI = 3.14
    #| let private_val = 0
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_eq(analysis.symbols.length(), 2)
}

///|
test "analyze_file extracts function call refs" {
  let source =
    #| fn main {
    #|   let x = foo()
    #|   bar(x)
    #| }
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_true(analysis.refs.contains("foo"))
  assert_true(analysis.refs.contains("bar"))
  assert_true(analysis.refs.contains("x"))
}

///|
test "analyze_file extracts type refs" {
  let source =
    #| fn process(p: Point) -> Color {
    #|   Color::Red
    #| }
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_true(analysis.refs.contains("Point"))
  assert_true(analysis.refs.contains("Color"))
}

///|
test "analyze_file extracts constructor refs" {
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
  let analysis = analyze_file(SourceFile::new("test.mbt", source))
  assert_true(analysis.refs.contains("Red"))
  assert_true(analysis.refs.contains("Blue"))
}

///|
test "analyze detects unused pub fn" {
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
  let result = analyze(files, "{}", ["."])
  assert_eq(result.unused_symbols.length(), 1)
  assert_eq(result.unused_symbols[0].name, "unused_fn")
}

///|
test "analyze detects unused pub struct" {
  let types_src =
    #| pub struct UsedPoint { x: Int }
    #| pub struct UnusedPoint { y: Int }
  let main_src =
    #| fn main {
    #|   let _ = process(UsedPoint::{ x: 1 })
    #| }
    #| fn process(p: UsedPoint) -> Int {
    #|   p.x
    #| }
  let files = [
    SourceFile::new("types.mbt", types_src),
    SourceFile::new("main.mbt", main_src),
  ]
  let result = analyze(files, "{}", ["."])
  assert_eq(result.unused_symbols.length(), 1)
  assert_eq(result.unused_symbols[0].name, "UnusedPoint")
}

///|
test "analyze returns empty when all used" {
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
  let result = analyze(files, "{}", ["."])
  assert_eq(result.unused_symbols.length(), 0)
}

///|
test "parse_moon_pkg_json parses string imports" {
  let json =
    #| {
    #|   "import": [
    #|     "moonbitlang/parser",
    #|     "moonbitlang/core/json"
    #|   ]
    #| }
  let config = parse_moon_pkg_json(json)
  assert_true(config is Some(_))
  let c = config.unwrap()
  assert_eq(c.imports.length(), 2)
  assert_true(c.imports.contains("moonbitlang/parser"))
  assert_true(c.imports.contains("moonbitlang/core/json"))
}

///|
test "parse_moon_pkg_json parses object imports with path" {
  let json =
    #| {
    #|   "import": [
    #|     { "path": "myorg/mylib", "alias": "lib" }
    #|   ]
    #| }
  let config = parse_moon_pkg_json(json)
  assert_true(config is Some(_))
  let c = config.unwrap()
  assert_eq(c.imports.length(), 1)
  assert_true(c.imports.contains("myorg/mylib"))
}

///|
test "extract_pkg_refs finds package references" {
  let src =
    #| fn main {
    #|   let x = @parser.parse("test")
    #|   let y = @json.parse("{}")
    #| }
  let refs = extract_pkg_refs(src)
  assert_true(refs.contains("parser"))
  assert_true(refs.contains("json"))
}

///|
test "analyze detects unused dependency" {
  let pkg_json =
    #| {
    #|   "import": [
    #|     "moonbitlang/parser",
    #|     "moonbitlang/unused"
    #|   ]
    #| }
  let src =
    #| fn main {
    #|   let _ = @parser.parse("test")
    #| }
  let result = analyze([SourceFile::new("main.mbt", src)], pkg_json, ["."])
  assert_eq(result.unused_deps.length(), 1)
  assert_true(result.unused_deps.contains("moonbitlang/unused"))
}

///|
test "analyze returns no unused deps when all used" {
  let pkg_json =
    #| {
    #|   "import": [
    #|     "moonbitlang/parser"
    #|   ]
    #| }
  let src =
    #| fn main {
    #|   let _ = @parser.parse("test")
    #| }
  let result = analyze([SourceFile::new("main.mbt", src)], pkg_json, ["."])
  assert_eq(result.unused_deps.length(), 0)
}

///|
test "parse_moon_pkg_dsl parses is-main" {
  let dsl =
    #| import {
    #|   "moonbitlang/parser",
    #| }
    #|
    #| options(
    #|   "is-main": true,
    #| )
  let config = parse_moon_pkg_dsl(dsl)
  assert_true(config is Some(_))
  let c = config.unwrap()
  assert_true(c.is_main)
}

///|
test "parse_moon_pkg_dsl parses imports" {
  let dsl = "import {\n  \"example/foo\" as @foo,\n  \"example/bar\",\n}"
  let config = parse_moon_pkg_dsl(dsl)
  assert_true(config is Some(_))
  let c = config.unwrap()
  assert_eq(c.imports.length(), 2)
  assert_true(c.imports.contains("example/foo"))
  assert_true(c.imports.contains("example/bar"))
}

///|
test "parse_moon_pkg auto-detects format" {
  // JSON format
  let json =
    #| { "is-main": true }
  let json_config = parse_moon_pkg(json)
  assert_true(json_config.unwrap().is_main)

  // DSL format
  let dsl =
    #| options(
    #|   "is-main": true,
    #| )
  let dsl_config = parse_moon_pkg(dsl)
  assert_true(dsl_config.unwrap().is_main)
}

///|
test "extract_implicit_deps detects async keyword" {
  let src_with_async = "async fn main { }"
  let deps = extract_implicit_deps(src_with_async)
  assert_true(deps.contains("async"))
  let src_without_async = "fn main { }"
  let deps2 = extract_implicit_deps(src_without_async)
  assert_eq(deps2.length(), 0)
}
