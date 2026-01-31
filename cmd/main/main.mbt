// ANSI color codes

///|
let reset = "\u001b[0m"

///|
let bold = "\u001b[1m"

///|
let dim = "\u001b[2m"

///|
let red = "\u001b[31m"

///|
let green = "\u001b[32m"

///|
let yellow = "\u001b[33m"

///|
let blue = "\u001b[34m"

///|
let cyan = "\u001b[36m"

// Collected files and package info

///|
struct CollectResult {
  mbt_files : Array[String]
  main_pkg_dirs : Array[String]
  pkg_jsons : Map[String, String] // dir -> content
}

///|
fn collect_project_files(dir : String) -> CollectResult raise @fs.IOError {
  let mbt_files : Array[String] = []
  let main_pkg_dirs : Array[String] = []
  let pkg_jsons : Map[String, String] = {}
  collect_recursive(dir, mbt_files, main_pkg_dirs, pkg_jsons)
  { mbt_files, main_pkg_dirs, pkg_jsons }
}

///|
fn collect_recursive(
  dir : String,
  mbt_files : Array[String],
  main_pkg_dirs : Array[String],
  pkg_jsons : Map[String, String],
) -> Unit raise @fs.IOError {
  let entries = @fs.read_dir(dir)

  // Check for moon.pkg (DSL) or moon.pkg.json (JSON) in this directory
  let pkg_dsl_path = if dir == "." { "moon.pkg" } else { "\{dir}/moon.pkg" }
  let pkg_json_path = if dir == "." {
    "moon.pkg.json"
  } else {
    "\{dir}/moon.pkg.json"
  }

  // Prefer moon.pkg (DSL) over moon.pkg.json (JSON)
  let pkg_path = if @fs.path_exists(pkg_dsl_path) {
    Some(pkg_dsl_path)
  } else if @fs.path_exists(pkg_json_path) {
    Some(pkg_json_path)
  } else {
    None
  }
  match pkg_path {
    Some(path) => {
      let content = @fs.read_file_to_string(path)
      pkg_jsons[dir] = content
      // Check if this is a main package (supports both formats)
      match @src.parse_moon_pkg(content) {
        Some(config) => if config.is_main { main_pkg_dirs.push(dir) }
        None => ()
      }
    }
    None => ()
  }

  // Collect files and recurse into subdirectories
  for entry in entries {
    let path = if dir == "." { entry } else { "\{dir}/\{entry}" }
    if @fs.is_dir(path) {
      if not(entry.has_prefix(".")) && entry != "_build" && entry != "target" {
        collect_recursive(path, mbt_files, main_pkg_dirs, pkg_jsons)
      }
    } else if entry.has_suffix(".mbt") &&
      not(entry.has_suffix("_test.mbt")) &&
      not(entry.has_suffix("_wbtest.mbt")) &&
      not(entry.has_suffix("_bench.mbt")) {
      mbt_files.push(path)
    }
  }
}

///|
fn print_header(title : String) -> Unit {
  println("\n\{bold}\{title}\{reset}")
  println(
    "\{dim}─────────────────────────────────\{reset}",
  )
}

///|
let magenta = "\u001b[35m"

///|
fn kind_icon(kind : @src.SymbolKind) -> String {
  match kind {
    Fn => "\{cyan}λ\{reset}"
    Struct => "\{blue}◇\{reset}"
    Enum => "\{yellow}◆\{reset}"
    EnumVariant(_) => "\{yellow}├\{reset}"
    Trait => "\{green}◎\{reset}"
    Let => "\{magenta}▫\{reset}"
    Const => "\{magenta}▪\{reset}"
    TypeAlias => "\{blue}≡\{reset}"
  }
}

///|
fn format_symbol(sym : @src.Symbol) -> String {
  let icon = kind_icon(sym.kind)
  let kind_str = sym.kind.to_string()
  let file = sym.loc.file.to_string()
  let line = sym.loc.line
  "\{icon} \{bold}\{sym.name}\{reset} \{dim}(\{kind_str}) \{file}:\{line}\{reset}"
}

///|
fn run() -> Unit raise @fs.IOError {
  let args = @sys.get_cli_args()
  let dir = if args.length() > 1 { args[1] } else { "." }
  println("\{bold}\{cyan}mknip\{reset} \{dim}v0.1.0\{reset}")
  println("\{dim}Analyzing \{dir}...\{reset}")

  // Collect all project files and package info
  let collected = collect_project_files(dir)
  let source_files : Array[@src.SourceFile] = []
  for path in collected.mbt_files {
    let content = @fs.read_file_to_string(path)
    source_files.push(@src.SourceFile::new(path, content))
  }

  // Get root package config for dependency analysis
  let pkg_json = match collected.pkg_jsons.get(dir) {
    Some(content) => content
    None => "{}"
  }

  // Run knip-style analysis with main package info
  let result = @src.analyze(source_files, pkg_json, collected.main_pkg_dirs)
  let has_issues = result.unused_symbols.length() > 0 ||
    result.unreachable_files.length() > 0 ||
    result.unused_deps.length() > 0
  if not(has_issues) {
    println("\n\{green}✓\{reset} No unused exports or dependencies found.")
    return
  }

  // Group unused symbols by type
  let unused_types : Array[@src.Symbol] = []
  let unused_fns : Array[@src.Symbol] = []
  for sym in result.unused_symbols {
    match sym.kind {
      Struct | Enum | EnumVariant(_) | Trait | TypeAlias =>
        unused_types.push(sym)
      Fn | Let | Const => unused_fns.push(sym)
    }
  }

  // Print unreachable files
  if result.unreachable_files.length() > 0 {
    print_header("Unreachable Files (\{result.unreachable_files.length()})")
    for file in result.unreachable_files {
      println("  \{red}✗\{reset} \{file.to_string()}")
    }
  }
  if unused_types.length() > 0 {
    print_header("Unused Types (\{unused_types.length()})")
    for sym in unused_types {
      println("  \{format_symbol(sym)}")
    }
  }
  if unused_fns.length() > 0 {
    print_header("Unused Functions (\{unused_fns.length()})")
    for sym in unused_fns {
      println("  \{format_symbol(sym)}")
    }
  }
  if result.unused_deps.length() > 0 {
    print_header("Unused Dependencies (\{result.unused_deps.length()})")
    for dep in result.unused_deps {
      println("  \{red}✗\{reset} \{dep}")
    }
  }
  println("")
  let total = result.unused_symbols.length() +
    result.unreachable_files.length() +
    result.unused_deps.length()
  println("\{yellow}⚠\{reset} Found \{bold}\{total}\{reset} issue(s)")
}

///|
fn main {
  run() catch {
    e => {
      println("\{red}Error:\{reset} \{e}")
      @sys.exit(1)
    }
  }
}
