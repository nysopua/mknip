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

priv struct RefCollector {
  refs : Array[String]
}

fn RefCollector::new() -> RefCollector {
  { refs: [] }
}

fn extract_name_from_long_ident(ident : @syntax.LongIdent) -> String {
  match ident {
    Ident(name~) => name
    Dot(pkg~, id~) => "\{pkg}.\{id}"
  }
}

impl @syntax.IterVisitor for RefCollector with visit_Expr_Ident(
  self,
  id~ : @syntax.Var,
  loc~ : @basic.Location
) -> Unit {
  let _ = loc
  let name = extract_name_from_long_ident(id.name)
  self.refs.push(name)
}

impl @syntax.IterVisitor for RefCollector with visit_Type_Name(
  self,
  constr_id~ : @syntax.ConstrId,
  tys~ : @list.List[@syntax.Type],
  loc~ : @basic.Location
) -> Unit {
  let _ = loc
  let name = extract_name_from_long_ident(constr_id.id)
  self.refs.push(name)
  for ty in tys {
    self.base().visit_Type(ty)
  }
}

impl @syntax.IterVisitor for RefCollector with visit_Expr_Constr(
  self,
  constr~ : @syntax.Constructor,
  loc~ : @basic.Location
) -> Unit {
  let _ = loc
  self.refs.push(constr.name.name)
}

impl @syntax.IterVisitor for RefCollector with visit_Pattern_Constr(
  self,
  constr~ : @syntax.Constructor,
  args~ : @list.List[@syntax.ConstrPatArg]?,
  is_open~ : Bool,
  loc~ : @basic.Location
) -> Unit {
  let _ = (is_open, loc)
  self.refs.push(constr.name.name)
  if args is Some(arg_list) {
    for arg in arg_list {
      self.base().visit_ConstrPatArg(arg)
    }
  }
}

pub fn extract_refs(source : String) -> Array[String] {
  let (impls, _) = @parser.parse_string(source)
  let collector = RefCollector::new()
  for impl_ in impls {
    collector.base().visit_Impl(impl_)
  }
  collector.refs
}

pub struct SourceFile {
  path : String
  content : String
}

pub fn SourceFile::new(path : String, content : String) -> SourceFile {
  { path, content }
}

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
