options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module consume shared private

require daslib/ast_boost

[macro_function]
def private isConsumeArgument(expr : ExpressionPtr) : bool {
    
    if (expr is ExprCall) {
        var func = (expr as ExprCall).func
        if (func.fromGeneric != null) {
            func = func.fromGeneric.get_ptr()
        }
        if (func.name == "consume_argument" && func._module.name == "$") {
            return true
        }
    }
    return false
}

[function_macro(name="consume")]
class CheckConsumeArguments : AstFunctionAnnotation {
    
    
    def override verifyCall(var call : smart_ptr<ExprCallFunc>; args, progArgs : AnnotationArgumentList; var errors : das_string) : bool {
        
        var check_args <- {for (aa in args); string(aa.name)}
        for (ca, ce in call.func.arguments, call.arguments) {
            if (check_args.key_exists(string(ca.name))) {
                if (!isConsumeArgument(ce)) {
                    errors := "argument {ca.name} is not passed as moved value, {describe(ce)}\nuse '<-' operator to move the argument, i.e. <-{describe(ce)}"
                    return false
                }
            }
        }
        return true;
    }
}
