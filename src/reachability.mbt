///|
pub fn find_entry_files(
  files : Array[SourceFile],
  main_pkg_dirs : Array[String],
) -> Array[FilePath] {
  files
    .iter()
    .filter(fn(file) {
      is_in_main_pkg(file.path, main_pkg_dirs) && has_entry_point(file.content)
    })
    .map(fn(file) { file.path })
    .collect()
}

///|
/// Check for private fn main or fn init
fn has_entry_point(source : String) -> Bool {
  let (impls, _) = @parser.parse_string(source)
  for impl_ in impls {
    match impl_ {
      TopFuncDef(fun_decl~, ..) => {
        let name = fun_decl.name.name
        if (name == "main" || name == "init") && not(fun_decl.vis is Pub(..)) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
pub fn is_in_main_pkg(path : FilePath, main_pkg_dirs : Array[String]) -> Bool {
  main_pkg_dirs.contains(path.dir())
}

///|
/// BFS from entry points to compute reachable symbols and files
pub fn compute_reachability(
  graph : SymbolGraph,
  entry_files : Array[FilePath],
) -> ReachabilityResult {
  let result = ReachabilityResult::empty()
  let file_queue : Array[String] = []
  for entry in entry_files {
    file_queue.push(entry.to_string())
  }
  while file_queue.length() > 0 {
    let current = file_queue.pop().unwrap()
    if result.reachable_files.contains(current) {
      continue
    }
    result.reachable_files.add(current)
    process_file_refs(graph, current, result, file_queue)
  }
  mark_entry_exports_reachable(graph, entry_files, result)
  result
}

///| Process references in a file, adding reachable symbols to result
fn process_file_refs(
  graph : SymbolGraph,
  file : String,
  result : ReachabilityResult,
  queue : Array[String],
) -> Unit {
  let refs = graph.refs_by_file.get(file).unwrap_or([])
  for ref_name in refs {
    result.reachable_symbols.add(ref_name)
    let symbols = graph.symbols_by_name.get(ref_name).unwrap_or([])
    for sym in symbols {
      let target = sym.loc.file.to_string()
      if not(result.reachable_files.contains(target)) {
        queue.push(target)
      }
    }
  }
}

///| Mark all exports in entry files as reachable
fn mark_entry_exports_reachable(
  graph : SymbolGraph,
  entry_files : Array[FilePath],
  result : ReachabilityResult,
) -> Unit {
  for entry in entry_files {
    let symbols = graph.symbols_by_file.get(entry.to_string()).unwrap_or([])
    symbols.each(fn(sym) { result.reachable_symbols.add(sym.name) })
  }
}

///| Library packages (is-main: false) treat all pub symbols as reachable
pub fn extend_with_library_exports(
  graph : SymbolGraph,
  main_pkg_dirs : Array[String],
  result : ReachabilityResult,
) -> Unit {
  for file in graph.files {
    if not(is_in_main_pkg(file, main_pkg_dirs)) {
      result.reachable_files.add(file.to_string())
      let symbols = graph.symbols_by_file.get(file.to_string()).unwrap_or([])
      symbols.each(fn(sym) { result.reachable_symbols.add(sym.name) })
    }
  }
}
