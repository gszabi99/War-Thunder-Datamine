options gen2
options indenting = 4
options strict_smart_pointers = true

module module_path shared public























































require fio_core public
require daslib/ast_boost
require daslib/macro_boost
require daslib/templates_boost

[call_macro(name="get_this_module_dir")]
class private GetThisModuleDirMacro : AstCallMacro {
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        macro_verify(empty(call.arguments), prog, call.at, "expecting get_this_module_dir()")
        let baked = string(call.at.fileInfo.name)
        
        return qmacro(__builtin_resolve_this_module_dir($v(baked), is_standalone_exe()))
    }
}
