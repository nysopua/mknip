///|
/// File path wrapper to prevent String confusion
pub struct FilePath(String) derive(Eq, Hash, Show)

///|
pub fn FilePath::to_string(self : FilePath) -> String {
  self.0
}

///|
pub fn FilePath::dir(self : FilePath) -> String {
  let parts = self.0.split("/").collect()
  if parts.length() <= 1 {
    "."
  } else {
    let sb = StringBuilder::new()
    for i, part in parts {
      if i == parts.length() - 1 {
        break
      }
      if i > 0 {
        sb.write_char('/')
      }
      sb.write_string(part.to_string())
    }
    sb.to_string()
  }
}

///|
pub enum SymbolKind {
  Fn
  Struct
  Enum
  EnumVariant(parent~ : String)
  Trait
  Let
  Const
  TypeAlias
}

///|
pub fn SymbolKind::to_string(self : SymbolKind) -> String {
  match self {
    Fn => "fn"
    Struct => "struct"
    Enum => "enum"
    EnumVariant(_) => "variant"
    Trait => "trait"
    Let => "let"
    Const => "const"
    TypeAlias => "type"
  }
}

///|
pub struct Location {
  file : FilePath
  line : Int
  column : Int
}

///|
pub struct Symbol {
  name : String
  kind : SymbolKind
  loc : Location
}

///|
pub fn Symbol::new(
  name : String,
  kind : SymbolKind,
  file : FilePath,
  line : Int,
  column : Int,
) -> Symbol {
  { name, kind, loc: { file, line, column } }
}

///|
pub fn Symbol::to_string(self : Symbol) -> String {
  "\{self.kind.to_string()} \{self.name} (\{self.loc.file.to_string()}:\{self.loc.line})"
}

///|
pub struct SourceFile {
  path : FilePath
  content : String
}

///|
pub fn SourceFile::new(path : String, content : String) -> SourceFile {
  { path: FilePath(path), content }
}

///|
/// Extracted from moon.pkg.json or moon.pkg
pub struct PackageConfig {
  imports : Array[String]
  is_main : Bool
}

///|
pub fn PackageConfig::empty() -> PackageConfig {
  { imports: [], is_main: false }
}

///|
pub struct FileAnalysis {
  path : FilePath
  symbols : Array[Symbol]
  refs : Array[String]
}

///|
/// Static snapshot of analyzed codebase
pub struct SymbolGraph {
  files : Array[FilePath]
  symbols_by_name : Map[String, Array[Symbol]]
  symbols_by_file : Map[String, Array[Symbol]]
  refs_by_file : Map[String, Array[String]]
}

///|
/// Build symbol graph from file analyses
pub fn SymbolGraph::from_analyses(
  analyses : Array[FileAnalysis],
) -> SymbolGraph {
  let files : Array[FilePath] = []
  let symbols_by_name : Map[String, Array[Symbol]] = {}
  let symbols_by_file : Map[String, Array[Symbol]] = {}
  let refs_by_file : Map[String, Array[String]] = {}
  for analysis in analyses {
    files.push(analysis.path)
    let path_str = analysis.path.to_string()
    symbols_by_file[path_str] = analysis.symbols
    refs_by_file[path_str] = analysis.refs
    for sym in analysis.symbols {
      add_to_multimap(symbols_by_name, sym.name, sym)
    }
  }
  { files, symbols_by_name, symbols_by_file, refs_by_file }
}

///|
/// Add value to a multimap (map of arrays)
fn[K : Eq + Hash, V] add_to_multimap(
  map : Map[K, Array[V]],
  key : K,
  value : V,
) -> Unit {
  match map.get(key) {
    Some(arr) => arr.push(value)
    None => map[key] = [value]
  }
}

///|
pub struct ReachabilityResult {
  reachable_symbols : @hashset.HashSet[String]
  reachable_files : @hashset.HashSet[String]
}

///|
pub fn ReachabilityResult::empty() -> ReachabilityResult {
  { reachable_symbols: @hashset.new(), reachable_files: @hashset.new() }
}

///|
pub struct AnalysisResult {
  unused_symbols : Array[Symbol]
  unreachable_files : Array[FilePath]
  unused_deps : Array[String]
}

///|
pub fn AnalysisResult::empty() -> AnalysisResult {
  { unused_symbols: [], unreachable_files: [], unused_deps: [] }
}
