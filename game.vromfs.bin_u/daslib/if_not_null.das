options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module if_not_null shared private






require daslib/ast
require daslib/rtti
require daslib/ast_boost
require daslib/templates_boost
require daslib/defer
require daslib/macro_boost

[call_macro(name="if_not_null")]
class ApplyMacro : AstCallMacro {
    
    
    
    
    
    
    
    
    
    
    if_not_null_index : int = 0
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        macro_verify(expr.arguments |> length == 2, prog, expr.at, "expecting 2 arguments, expecting ptr |> if_not_null() <| call()")
        macro_verify(expr.arguments[1] is ExprCall, prog, expr.at, "2nd argument must be call(), expecting ptr |> if_not_null() <| call()")
        assume PTR = expr.arguments[0]
        if (PTR._type != null) {
            macro_verify(PTR._type.isPointer, prog, expr.at, "first argument must be pointer , expecting ptr |> if_not_null() <| call()")
            let ifnn_name = "__ifnn_ptr_{if_not_null_index++}"
            var fcall = expr.arguments[1] as ExprCall
            var vtype = clone_type(PTR._type)
            if (!PTR._type.flags.constant) {
                vtype.flags |= TypeDeclFlags.removeConstant
            }
            var ptrClone = clone_expression(PTR)
            var argClones : array<ExpressionPtr>
            for (a in fcall.arguments) {
                argClones |> push(clone_expression(a))
            }
            return <- qmacro_block() {
                let $i(ifnn_name) : $t(vtype) = $e(ptrClone)
                if ($i(ifnn_name) != null) {
                    $c(fcall.name)(*$i(ifnn_name), $a(argClones))
                }
            }
        }
        return null
    }
}

