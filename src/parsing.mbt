///|
/// JSON format (moon.pkg.json)
pub fn parse_moon_pkg_json(content : String) -> PackageConfig? {
  let json = @json.parse(content) catch { _ => return None }
  match json {
    Object(obj) => {
      let imports = extract_json_imports(obj)
      let is_main = obj.get("is-main") is Some(True)
      Some({ imports, is_main })
    }
    _ => None
  }
}

///|
fn extract_json_imports(obj : Map[String, Json]) -> Array[String] {
  let arr = match obj.get("import") {
    Some(Array(arr)) => arr
    _ => return []
  }
  arr
  .iter()
  .filter_map(fn(item) {
    match item {
      String(s) => Some(s)
      Object(o) =>
        match o.get("path") {
          Some(String(p)) => Some(p)
          _ => None
        }
      _ => None
    }
  })
  .collect()
}

///|
/// DSL format (moon.pkg)
pub fn parse_moon_pkg_dsl(content : String) -> PackageConfig? {
  let imports = extract_dsl_imports(content)
  let is_main = content.contains("\"is-main\":true") ||
    check_is_main_normalized(content)
  Some({ imports, is_main })
}

///|
fn check_is_main_normalized(content : String) -> Bool {
  if not(content.contains("\"is-main\"")) {
    return false
  }
  content
  .iter()
  .filter(fn(c) { not(is_whitespace(c)) })
  .fold(init=StringBuilder::new(), fn(sb, c) {
    sb.write_char(c)
    sb
  })
  .to_string()
  .contains("\"is-main\":true")
}

///|
fn extract_dsl_imports(content : String) -> Array[String] {
  let imports : Array[String] = []
  let chars = content.to_array()
  let len = chars.length()
  let mut i = 0
  while i <= len - 6 {
    if is_import_keyword(chars, i) {
      i = i + 6
      i = skip_whitespace(chars, i, len)
      if i < len && chars[i] == '{' {
        parse_import_block(chars, i + 1, len, imports)
      }
      break
    }
    i = i + 1
  }
  imports
}

///|
fn is_import_keyword(chars : Array[Char], i : Int) -> Bool {
  chars[i] == 'i' &&
  chars[i + 1] == 'm' &&
  chars[i + 2] == 'p' &&
  chars[i + 3] == 'o' &&
  chars[i + 4] == 'r' &&
  chars[i + 5] == 't'
}

///|
fn skip_whitespace(chars : Array[Char], start : Int, len : Int) -> Int {
  let mut i = start
  while i < len && is_whitespace(chars[i]) {
    i = i + 1
  }
  i
}

///|
fn parse_import_block(
  chars : Array[Char],
  start : Int,
  len : Int,
  imports : Array[String],
) -> Unit {
  let mut i = start
  while i < len && chars[i] != '}' {
    i = skip_whitespace_and_commas(chars, i, len)
    if i < len && chars[i] == '"' {
      let (path, next_i) = extract_quoted_string(chars, i + 1, len)
      if path.contains("/") {
        imports.push(path)
      }
      i = skip_until_delimiter(chars, next_i, len)
    } else {
      i = i + 1
    }
  }
}

///|
fn skip_whitespace_and_commas(
  chars : Array[Char],
  start : Int,
  len : Int,
) -> Int {
  let mut i = start
  while i < len && (is_whitespace(chars[i]) || chars[i] == ',') {
    i = i + 1
  }
  i
}

///|
fn extract_quoted_string(
  chars : Array[Char],
  start : Int,
  _len : Int,
) -> (String, Int) {
  let end = chars.iter().drop(start).take_while(fn(c) { c != '"' }).count() +
    start
  let str = chars[start:end]
    .iter()
    .fold(init=StringBuilder::new(), fn(sb, c) {
      sb.write_char(c)
      sb
    })
    .to_string()
  (str, end + 1)
}

///|
fn skip_until_delimiter(chars : Array[Char], start : Int, len : Int) -> Int {
  let mut i = start
  while i < len && chars[i] != ',' && chars[i] != '}' {
    i = i + 1
  }
  i
}

///|
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\t' || c == '\r'
}

///|
/// Auto-detect format by first non-whitespace char
pub fn parse_moon_pkg(content : String) -> PackageConfig? {
  for c in content {
    if not(is_whitespace(c)) {
      return if c == '{' {
        parse_moon_pkg_json(content)
      } else {
        parse_moon_pkg_dsl(content)
      }
    }
  }
  None
}
