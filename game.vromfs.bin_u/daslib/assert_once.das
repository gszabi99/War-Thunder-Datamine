options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers

module assert_once shared private

require ast
require rtti
require daslib/ast_boost
require daslib/templates_boost

[tag_function(asset_once_tag)]
def public assert_once(expr : bool; message : string = "") {
    
    pass
}

[tag_function_macro(tag="asset_once_tag")]
class AssertOnceMacro : AstFunctionAnnotation {
    
    
    
    
    
    
    def override transform(var call : smart_ptr<ExprCallFunc>; var errors : das_string) : ExpressionPtr {
        let once_name = make_unique_private_name("__assert_once", call.at)
        if (!compiling_module() |> add_global_private_var(once_name, call.at) <| quote(true)) {
            errors := "can't add global variable {once_name}"
            return <- default<ExpressionPtr>
        }
        
        var inscope qb <- qmacro_block() <| $() {
            if ($i(once_name) && !$e(call.arguments[0])) {
                $i(once_name) = false
                assert(false, $e(call.arguments[1]))
            }
        }
        qb |> force_at(call.at)
        return <- qb
    }
}


