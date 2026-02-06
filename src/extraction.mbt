///|
pub fn analyze_file(file : SourceFile) -> FileAnalysis {
  {
    path: file.path,
    symbols: extract_pub_symbols(file.content, file.path),
    refs: extract_refs(file.content),
  }
}

///|
pub fn analyze_files(files : Array[SourceFile]) -> Array[FileAnalysis] {
  files.map(analyze_file)
}

///|
/// Extract package names from "pkg.name" patterns
pub fn extract_pkg_refs(source : String) -> Array[String] {
  extract_refs(source)
    .iter()
    .filter(fn(ref_) { ref_.contains(".") })
    .filter_map(fn(ref_) { ref_.split(".").collect().get(0) })
    .map(fn(s) { s.to_string() })
    .collect()
    |> to_unique
}

///|
fn to_unique(arr : Array[String]) -> Array[String] {
  let set : @hashset.HashSet[String] = @hashset.new()
  arr.each(fn(s) { set.add(s) })
  set.to_array()
}

///|
fn extract_pub_symbols(source : String, file : FilePath) -> Array[Symbol] {
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
              file,
              loc.start.lnum,
              loc.start.column(),
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
              file,
              type_decl.tycon_loc.start.lnum,
              type_decl.tycon_loc.start.column(),
            ),
          )
          match type_decl.components {
            Variant(constrs) =>
              for constr in constrs {
                symbols.push(
                  Symbol::new(
                    constr.name.name,
                    EnumVariant(parent=type_decl.tycon),
                    file,
                    constr.name.loc.start.lnum,
                    constr.name.loc.start.column(),
                  ),
                )
              }
            _ => ()
          }
        }
      TopTrait(trait_decl) =>
        if trait_decl.vis is Pub(..) {
          symbols.push(
            Symbol::new(
              trait_decl.name.name,
              Trait,
              file,
              trait_decl.name.loc.start.lnum,
              trait_decl.name.loc.start.column(),
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
              file,
              binder.loc.start.lnum,
              binder.loc.start.column(),
            ),
          )
        }
      _ => ()
    }
  }
  symbols
}

///|
priv struct RefCollector {
  refs : Array[String]
}

///|
fn RefCollector::new() -> RefCollector {
  { refs: [] }
}

///|
/// Walk AST with IterVisitor to collect reference names
fn extract_refs(source : String) -> Array[String] {
  let (impls, _) = @parser.parse_string(source)
  let collector = RefCollector::new()
  for impl_ in impls {
    collector.base().visit_Impl(impl_)
  }
  collector.refs
}

///|
fn extract_full_name(ident : @syntax.LongIdent) -> String {
  match ident {
    Ident(name~) => name
    Dot(pkg~, id~) => "\{pkg}.\{id}"
  }
}

///|
fn extract_simple_name(ident : @syntax.LongIdent) -> String {
  match ident {
    Ident(name~) => name
    Dot(id~, ..) => id
  }
}

///|
fn add_long_ident_refs(
  collector : RefCollector,
  ident : @syntax.LongIdent,
) -> Unit {
  collector.refs.push(extract_full_name(ident))
  if ident is Dot(..) {
    collector.refs.push(extract_simple_name(ident))
  }
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Expr_Ident(
  self,
  id~ : @syntax.Var,
  loc~ : @basic.Location,
) -> Unit {
  let _ = loc
  add_long_ident_refs(self, id.name)
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Type_Name(
  self,
  constr_id~ : @syntax.ConstrId,
  tys~ : @list.List[@syntax.Type],
  loc~ : @basic.Location,
) -> Unit {
  let _ = loc
  add_long_ident_refs(self, constr_id.id)
  for ty in tys {
    self.base().visit_Type(ty)
  }
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Expr_Constr(
  self,
  constr~ : @syntax.Constructor,
  loc~ : @basic.Location,
) -> Unit {
  let _ = loc
  self.refs.push(constr.name.name)
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Pattern_Constr(
  self,
  constr~ : @syntax.Constructor,
  args~ : @list.List[@syntax.ConstrPatArg]?,
  is_open~ : Bool,
  loc~ : @basic.Location,
) -> Unit {
  let _ = (is_open, loc)
  self.refs.push(constr.name.name)
  args.iter().each(fn(arg_list) {
    arg_list.each(fn(arg) { self.base().visit_ConstrPatArg(arg) })
  })
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Parameter_Labelled(
  self,
  binder~,
  ty~,
) -> Unit {
  let _ = binder
  ty.iter().each(fn(t) { self.base().visit_Type(t) })
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Parameter_Positional(
  self,
  binder~,
  ty~,
) -> Unit {
  let _ = binder
  ty.iter().each(fn(t) { self.base().visit_Type(t) })
}

///|
/// Static method calls: @pkg.Type::method()
impl @syntax.IterVisitor for RefCollector with visit_Expr_Method(
  self,
  type_name~ : @syntax.TypeName,
  method_name~ : @syntax.Label,
  loc~ : @basic.Location,
) -> Unit {
  let _ = (method_name, loc)
  add_long_ident_refs(self, type_name.name)
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Expr_DotApply(
  receiver,
  self~ : @syntax.Expr,
  method_name~ : @syntax.Label,
  args~ : @list.List[@syntax.Argument],
  return_self~ : Bool,
  attr~ : @syntax.ApplyAttr,
  loc~ : @basic.Location,
) -> Unit {
  let _ = (return_self, attr, loc)
  receiver.refs.push(method_name.name)
  receiver.base().visit_Expr(self)
  for arg in args {
    receiver.base().visit_Argument(arg)
  }
}

///|
impl @syntax.IterVisitor for RefCollector with visit_Impl_TopImpl(
  self,
  self_ty~,
  trait_~,
  method_name~,
  has_error~,
  quantifiers~,
  params~,
  ret_ty~,
  err_ty~,
  body~,
  vis~,
  loc~,
  attrs~,
  doc~,
) -> Unit {
  let _ = (method_name, has_error, quantifiers, vis, loc, attrs, doc)
  add_long_ident_refs(self, trait_.name)
  self_ty.iter().each(fn(ty) { self.base().visit_Type(ty) })
  params.each(fn(param) { self.base().visit_Parameter(param) })
  ret_ty.iter().each(fn(ty) { self.base().visit_Type(ty) })
  self.base().visit_ErrorType(err_ty)
  self.base().visit_DeclBody(body)
}
