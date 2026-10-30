options gen2
options indenting = 4
options strict_smart_pointers

module module_group shared private



require daslib/ast_boost
require daslib/templates_boost
require daslib/fio
require daslib/rtti
require strings

def public module_group_module_name(member : string) : string {
    
    
    let name = base_name(member)
    return extension(name) == ".das" ? slice(name, 0, length(name) - 4) : name
}

[call_macro(name="call_module_group")]
class CallModuleGroup : AstCallMacro {
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; expr : ExprCallMacro?) : ExpressionPtr {
        if (length(expr.arguments) < 2 || !(expr.arguments[0] is ExprConstString) || !(expr.arguments[1] is ExprConstString)) {
            macro_error(prog, expr.at, "call_module_group expects (\"group\", \"entry\", args...)")
            return <- default<ExpressionPtr>
        }
        let group = string((expr.arguments[0] as ExprConstString).value)
        let entry = string((expr.arguments[1] as ExprConstString).value)
        var res <- qmacro_block() {
        }
        var blk = res as ExprBlock
        var argNames : array<string>
        for (i in range(2, length(expr.arguments))) {
            if (expr.arguments[i] is ExprVar || expr.arguments[i].__rtti |> starts_with("ExprConst")) {
                argNames |> push("")
            } else {
                let name = make_unique_private_name("_cmg_arg_{i - 2}", expr.at)  
                argNames |> push(name)
                var decl <- qmacro_block() {
                    let $i(name) = $e(expr.arguments[i])
                }
                var declBlk = decl as ExprBlock
                for (st in declBlk.list) {
                    blk.list |> emplace_new(clone_expression(st))
                }
            }
        }
        module_group_for_each_member(group) $(member : string) {
            var call <- make_call(expr.at, "{module_group_module_name(member)}::{entry}")
            for (i in range(2, length(expr.arguments))) {
                let name = argNames[i - 2]
                if (empty(name)) {
                    (call as ExprCall).arguments |> emplace_new(clone_expression(expr.arguments[i]))
                } else {
                    (call as ExprCall).arguments |> emplace_new(qmacro($i(name)))
                }
            }
            blk.list |> emplace_new(call)
        }
        return <- res
    }
}
