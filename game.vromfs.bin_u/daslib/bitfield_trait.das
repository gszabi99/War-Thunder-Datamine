options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module bitfield_trait shared private

require ast
require daslib/ast_boost
require daslib/contracts
require daslib/strings_boost
require daslib/templates_boost

[expect_any_bitfield(argT), tag_function(each_bitfield_tag), unused_argument(argT)]
def public each(argT) {
    
    pass
}

[tag_function_macro(tag="each_bitfield_tag")]
class EachBitfieldMacro : AstFunctionAnnotation {
    
    
    
    
    
    
    def override transform(var call : smart_ptr<ExprCallFunc>; var errors : das_string) : ExpressionPtr {
        var inscope yields : array<ExpressionPtr>
        for (name in call.arguments[0]._type.argNames) {
            yields |> emplace_new <| qmacro_expr(${ yield $v(string(name)); })
        }
        let call_name = "field`names"
        var inscope qfn <- qmacro_function(call_name) <| $() {
            return <- generator<string>() <| $() {
                $b(yields)
                return false
            }
        }
        qfn.flags |= FunctionFlags.generated | FunctionFlags.privateFunction
        compiling_module() |> add_function(qfn)
        let call_expr_name = "_::{call_name}"
        return <- qmacro($c(call_expr_name)())
    }
}

