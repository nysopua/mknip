pub enum SymbolKind {
  Fn
  Struct
  Enum
  Trait
  Let
  Const
  TypeAlias
}

pub fn SymbolKind::to_string(self : SymbolKind) -> String {
  match self {
    Fn => "fn"
    Struct => "struct"
    Enum => "enum"
    Trait => "trait"
    Let => "let"
    Const => "const"
    TypeAlias => "type"
  }
}

pub struct Location {
  file : String
  line : Int
  column : Int
}

pub struct Symbol {
  name : String
  kind : SymbolKind
  loc : Location
}

pub fn Symbol::new(name : String, kind : SymbolKind, loc : Location) -> Symbol {
  { name, kind, loc }
}

pub fn Symbol::to_string(self : Symbol) -> String {
  "\{self.kind.to_string()} \{self.name} (\{self.loc.file}:\{self.loc.line})"
}

pub struct SourceFile {
  path : String
  content : String
}

pub fn SourceFile::new(path : String, content : String) -> SourceFile {
  { path, content }
}

pub struct PackageConfig {
  imports : Array[String]
}
