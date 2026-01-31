///| Language features that require packages without explicit @pkg references
pub fn extract_implicit_deps(source : String) -> Array[String] {
  if source.contains("async ") {
    ["async"]
  } else {
    []
  }
}
