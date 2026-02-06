///|
pub fn analyze(
  files : Array[SourceFile],
  pkg_content : String,
  main_pkg_dirs : Array[String],
) -> AnalysisResult {
  let graph = files |> analyze_files |> SymbolGraph::from_analyses
  let entry_files = find_entry_files(files, main_pkg_dirs)
  if entry_files.is_empty() {
    return {
      unused_symbols: [],
      unreachable_files: [],
      unused_deps: find_unused_deps(pkg_content, files),
    }
  }
  let reachability = compute_reachability(graph, entry_files)
  extend_with_library_exports(graph, main_pkg_dirs, reachability)
  {
    unused_symbols: find_unused_symbols(graph, entry_files, main_pkg_dirs, reachability),
    unreachable_files: find_unreachable_files(graph, main_pkg_dirs, reachability),
    unused_deps: find_unused_deps(pkg_content, files),
  }
}

///| Find symbols in main packages that are not reachable from entry points
fn find_unused_symbols(
  graph : SymbolGraph,
  entry_files : Array[FilePath],
  main_pkg_dirs : Array[String],
  reachability : ReachabilityResult,
) -> Array[Symbol] {
  let entry_file_set = entry_files |> to_string_set
  graph.files
    .iter()
    .filter(fn(file) { is_in_main_pkg(file, main_pkg_dirs) })
    .flat_map(fn(file) {
      graph.symbols_by_file.get(file.to_string()).unwrap_or([]).iter()
    })
    .filter(fn(sym) {
      let is_entry = entry_file_set.contains(sym.loc.file.to_string())
      let is_reachable = reachability.reachable_symbols.contains(sym.name)
      not(is_entry) && not(is_reachable)
    })
    .collect()
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
  graph.files
    .iter()
    .filter(fn(file) {
      is_in_main_pkg(file, main_pkg_dirs) &&
        not(reachability.reachable_files.contains(file.to_string()))
    })
    .collect()
}

///|
fn find_unused_deps(
  pkg_content : String,
  files : Array[SourceFile],
) -> Array[String] {
  let config = parse_moon_pkg(pkg_content).unwrap_or(PackageConfig::empty())
  let used_pkgs = collect_used_packages(files)
  config.imports
    .iter()
    .filter(fn(imp) { not(used_pkgs.contains(get_package_name(imp))) })
    .collect()
}

///| Collect all package references from source files
fn collect_used_packages(files : Array[SourceFile]) -> @hashset.HashSet[String] {
  let used : @hashset.HashSet[String] = @hashset.new()
  files.each(fn(file) {
    extract_pkg_refs(file.content).each(fn(pkg) { used.add(pkg) })
    extract_implicit_deps(file.content).each(fn(pkg) { used.add(pkg) })
  })
  used
}

///| Extract last component from import path (e.g. "moonbitlang/core/json" -> "json")
fn get_package_name(import_path : String) -> String {
  import_path
    .split("/")
    .collect()
    .last()
    .map(fn(s) { s.to_string() })
    .unwrap_or(import_path)
}
