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

pub fn extract_pub_symbols(
  source : String,
  file : String
) -> Array[Symbol] {
  let (impls, _) = @parser.parse_string(source)
  let symbols : Array[Symbol] = []
  for impl_ in impls {
    match impl_ {
      TopFuncDef(fun_decl~, ..) =>
        if fun_decl.vis is Pub(..) {
          let loc = fun_decl.name.loc
          symbols.push(
            Symbol::new(
              fun_decl.name.name,
              Fn,
              { file, line: loc.start.lnum, column: loc.start.column() },
            ),
          )
        }
      TopTypeDef(type_decl) =>
        if type_decl.type_vis is Pub(..) {
          let kind = match type_decl.components {
            Variant(_) => Enum
            Record(_) => Struct
            Alias(_) => TypeAlias
            _ => Struct
          }
          symbols.push(
            Symbol::new(
              type_decl.tycon,
              kind,
              { file, line: type_decl.tycon_loc.start.lnum, column: type_decl.tycon_loc.start.column() },
            ),
          )
        }
      TopTrait(trait_decl) =>
        if trait_decl.vis is Pub(..) {
          symbols.push(
            Symbol::new(
              trait_decl.name.name,
              Trait,
              { file, line: trait_decl.name.loc.start.lnum, column: trait_decl.name.loc.start.column() },
            ),
          )
        }
      TopLetDef(binder~, vis~, is_constant~, ..) =>
        if vis is Pub(..) {
          let kind = if is_constant { Const } else { Let }
          symbols.push(
            Symbol::new(
              binder.name,
              kind,
              { file, line: binder.loc.start.lnum, column: binder.loc.start.column() },
            ),
          )
        }
      _ => ()
    }
  }
  symbols
}
