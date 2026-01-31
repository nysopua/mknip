///|
pub fn analyze(
  files : Array[SourceFile],
  pkg_content : String,
  main_pkg_dirs : Array[String],
) -> AnalysisResult {
  let analyses = analyze_files(files)
  let graph = SymbolGraph::from_analyses(analyses)
  let entry_files = find_entry_files(files, main_pkg_dirs)
  if entry_files.is_empty() {
    return AnalysisResult::{
      unused_symbols: [],
      unreachable_files: [],
      unused_deps: find_unused_deps(pkg_content, files),
    }
  }
  let reachability = compute_reachability(graph, entry_files)
  extend_with_library_exports(graph, main_pkg_dirs, reachability)
  let unused_symbols = find_unused_symbols(
    graph, entry_files, main_pkg_dirs, reachability,
  )
  let unreachable_files = find_unreachable_files(
    graph, main_pkg_dirs, reachability,
  )
  let unused_deps = find_unused_deps(pkg_content, files)
  { unused_symbols, unreachable_files, unused_deps }
}

///| Find symbols in main packages that are not reachable from entry points
fn find_unused_symbols(
  graph : SymbolGraph,
  entry_files : Array[FilePath],
  main_pkg_dirs : Array[String],
  reachability : ReachabilityResult,
) -> Array[Symbol] {
  let entry_file_set = to_string_set(entry_files)
  let unused : Array[Symbol] = []
  for file in graph.files {
    if not(is_in_main_pkg(file, main_pkg_dirs)) {
      continue
    }
    let symbols = graph.symbols_by_file.get(file.to_string()).unwrap_or([])
    for sym in symbols {
      let is_entry = entry_file_set.contains(sym.loc.file.to_string())
      let is_reachable = reachability.reachable_symbols.contains(sym.name)
      if not(is_entry) && not(is_reachable) {
        unused.push(sym)
      }
    }
  }
  unused
}

///| Convert FilePath array to HashSet of strings
fn to_string_set(paths : Array[FilePath]) -> @hashset.HashSet[String] {
  let set : @hashset.HashSet[String] = @hashset.new()
  paths.each(fn(p) { set.add(p.to_string()) })
  set
}

///|
fn find_unreachable_files(
  graph : SymbolGraph,
  main_pkg_dirs : Array[String],
  reachability : ReachabilityResult,
) -> Array[FilePath] {
  let result : Array[FilePath] = []
  for file in graph.files {
    if is_in_main_pkg(file, main_pkg_dirs) &&
      not(reachability.reachable_files.contains(file.to_string())) {
      result.push(file)
    }
  }
  result
}

///|
fn find_unused_deps(
  pkg_content : String,
  files : Array[SourceFile],
) -> Array[String] {
  let config = match parse_moon_pkg(pkg_content) {
    Some(c) => c
    None => return []
  }
  let used_pkgs = collect_used_packages(files)
  config.imports.filter(fn(imp) {
    let pkg_name = get_package_name(imp)
    not(used_pkgs.contains(pkg_name))
  })
}

///| Collect all package references from source files
fn collect_used_packages(files : Array[SourceFile]) -> @hashset.HashSet[String] {
  let used : @hashset.HashSet[String] = @hashset.new()
  for file in files {
    extract_pkg_refs(file.content).each(fn(pkg) { used.add(pkg) })
    extract_implicit_deps(file.content).each(fn(pkg) { used.add(pkg) })
  }
  used
}

///| Extract last component from import path (e.g. "moonbitlang/core/json" -> "json")
fn get_package_name(import_path : String) -> String {
  let mut last_start = 0
  let chars = import_path.to_array()
  for i, c in chars {
    if c == '/' {
      last_start = i + 1
    }
  }
  let buf = StringBuilder::new()
  for i = last_start; i < chars.length(); i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}
