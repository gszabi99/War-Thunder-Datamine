options indenting = 2
options no_aot
module enum_macro shared

require daslib/ast_boost


[enumeration_macro(name="export_enum")]
class ExportAnnotation : AstEnumerationAnnotation
  [unused_argument(enu, group, args, errors)] def override apply(var enu : EnumerationPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    return true
