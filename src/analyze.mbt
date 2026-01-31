pub fn find_unused_exports(files : Array[SourceFile]) -> Array[Symbol] {
  let all_exports : Array[Symbol] = []
  let all_refs : @hashset.HashSet[String] = @hashset.new()

  for file in files {
    let exports = extract_pub_symbols(file.content, file.path)
    for sym in exports {
      all_exports.push(sym)
    }
    let refs = extract_refs(file.content)
    for ref_ in refs {
      all_refs.add(ref_)
    }
  }

  all_exports.filter(fn(sym) { not(all_refs.contains(sym.name)) })
}

pub fn parse_moon_pkg_json(content : String) -> PackageConfig? {
  let json = try { @json.parse(content) } catch { _ => return None }
  let imports : Array[String] = []

  match json {
    Object(obj) =>
      match obj.get("import") {
        Some(Array(arr)) =>
          for item in arr {
            match item {
              String(s) => imports.push(s)
              Object(o) =>
                match o.get("path") {
                  Some(String(p)) => imports.push(p)
                  _ => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  Some({ imports, })
}

pub fn find_unused_deps(
  pkg_json : String,
  sources : Array[SourceFile]
) -> Array[String] {
  let config = match parse_moon_pkg_json(pkg_json) {
    Some(c) => c
    None => return []
  }

  let used_pkgs : @hashset.HashSet[String] = @hashset.new()
  for file in sources {
    let refs = extract_pkg_refs(file.content)
    for pkg in refs {
      used_pkgs.add(pkg)
    }
  }

  config.imports.filter(fn(imp) {
    let parts : Array[String] = imp.split("/").map(fn(sv) { sv.to_string() }).collect()
    let pkg_name = parts[parts.length() - 1]
    not(used_pkgs.contains(pkg_name))
  })
}
