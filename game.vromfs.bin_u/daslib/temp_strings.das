options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module temp_strings shared private

require daslib/ast_boost
require strings public

def public build_temp_string(bldr : block<(var writer : StringBuilderWriter) : void>; cb : block<(res : string#) : void>) {
    
    
    var str = build_string(bldr)
    unsafe {
        cb |> invoke(reinterpret<string#> str)
        if (!is_intern_strings()) {
            delete_string(reinterpret<string&> str)
        }
    }
}

[tag_function(temp_string_tag)]
def public temp_string(str : string; cb : block<(res : string#) : void>) {
    
    
    unsafe {
        cb |> invoke(reinterpret<string#> str)
        if (!is_intern_strings()) {
            delete_string(reinterpret<string&> str)
        }
    }
}

[tag_function_macro(tag="temp_string_tag")]
class TempStringMacro : AstFunctionAnnotation {
    def override verifyCall(var call : smart_ptr<ExprCallFunc>; args, progArgs : AnnotationArgumentList; var errors : das_string) : bool {
        if (call.arguments[0] is ExprStringBuilder) {
            return true
        }

        errors := "temp_string argument must be a string with subtitutions (string builder)"
        return false
    }
}

def public temp_string(arr : array<uint8>; cb : block<(res : string#) : void>) {
    
    
    var str = string(arr)
    unsafe {
        cb |> invoke(reinterpret<string#> str)
        if (!is_intern_strings()) {
            delete_string(reinterpret<string&> str)
        }
    }
}
