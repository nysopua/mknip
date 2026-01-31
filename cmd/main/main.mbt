fn collect_mbt_files(dir : String) -> Array[String] raise @fs.IOError {
  let files : Array[String] = []
  let entries = @fs.read_dir(dir)
  for entry in entries {
    let path = if dir == "." { entry } else { "\{dir}/\{entry}" }
    if @fs.is_dir(path) {
      if not(entry.has_prefix(".")) && entry != "_build" && entry != "target" {
        let sub_files = collect_mbt_files(path)
        for f in sub_files {
          files.push(f)
        }
      }
    } else if entry.has_suffix(".mbt") && not(entry.has_suffix("_test.mbt")) {
      files.push(path)
    }
  }
  files
}

fn run() -> Unit raise @fs.IOError {
  let args = @sys.get_cli_args()
  let dir = if args.length() > 1 { args[1] } else { "." }

  let mbt_paths = collect_mbt_files(dir)
  let source_files : Array[@src.SourceFile] = []
  for path in mbt_paths {
    let content = @fs.read_file_to_string(path)
    source_files.push(@src.SourceFile::new(path, content))
  }

  let unused = @src.find_unused_exports(source_files)

  if unused.length() == 0 {
    println("No unused exports found.")
  } else {
    println("Unused exports:")
    for sym in unused {
      println("  \{sym.to_string()}")
    }
  }

  let pkg_json_path = if dir == "." { "moon.pkg.json" } else { "\{dir}/moon.pkg.json" }
  if @fs.path_exists(pkg_json_path) {
    let pkg_json = @fs.read_file_to_string(pkg_json_path)
    let unused_deps = @src.find_unused_deps(pkg_json, source_files)
    if unused_deps.length() > 0 {
      println("\nUnused dependencies:")
      for dep in unused_deps {
        println("  \{dep}")
      }
    }
  }
}

///|
fn main {
  try {
    run()
  } catch {
    e => {
      println("Error: \{e}")
      @sys.exit(1)
    }
  }
}
