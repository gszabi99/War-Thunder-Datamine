options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module safe_addr shared private

require ast
require rtti
require daslib/ast_boost
require daslib/is_local

[tag_function(safe_addr_tag)]
def public safe_addr(var x : auto(T)& ==const) : T -&?# {
    
    unsafe {
        return reinterpret<T -&?#>(addr(x))
    }
}

[tag_function(safe_addr_tag)]
def public safe_addr(x : auto(T)& ==const) : T -&? const# {
    
    unsafe {
        return reinterpret<T -&? const#>(addr(x))
    }
}

[tag_function_macro(tag="safe_addr_tag")]
class SafeAddrMacro : AstFunctionAnnotation {
    
    
    def override transform(var call : smart_ptr<ExprCallFunc>; var errors : das_string) : ExpressionPtr {
        if (!is_local_or_global_expr(call.arguments[0])) {
            compiling_program() |> macro_error(call.at, "not a local value")
        }
        return <- default<ExpressionPtr>
    }
}


def public temp_ptr(x : auto(T)? implicit ==const) : T? const# {
    
    unsafe {
        return reinterpret<T? const#>(x)
    }
}


def public temp_ptr(var x : auto(T)? implicit ==const) : T?# {
    
    unsafe {
        return reinterpret<T?#>(x)
    }
}

[tag_function(shared_addr_tag)]
def public shared_addr(tab : table<auto(KEY); auto(VAL)>; k : KEY) {
    
    return unsafe(find(tab, k))
}

[tag_function(shared_addr_tag)]
def public shared_addr(val : auto(VALUE)&) {
    
    return unsafe(addr(val))
}

[tag_function_macro(tag="shared_addr_tag")]
class SharedAddrMacro : AstFunctionAnnotation {
    
    
    def override verifyCall(var call : smart_ptr<ExprCallFunc>; args, progArgs : AnnotationArgumentList; var errors : das_string) : bool {
        if (is_shared_expr(call.arguments[0])) {
            return true
        }
        compiling_program() |> macro_error(call.at, "{call.name} can only be used with shared global variables")
        return false
    }
}

[tag_function(temp_value_tag)]
def public temp_value(x : auto(T)& ==const) : T&# const {
    
    unsafe {
        return reinterpret<T&# const>(x)
    }
}

[tag_function(temp_value_tag)]
def public temp_value(var x : auto(T)& ==const) : T&# {
    
    unsafe {
        return reinterpret<T&#>(x)
    }
}

[tag_function_macro(tag="temp_value_tag")]
class TempValueMacro : AstFunctionAnnotation {
    
    def override verifyCall(var call : smart_ptr<ExprCallFunc>; args, progArgs : AnnotationArgumentList; var errors : das_string) : bool {
        if (is_temp_safe(call.arguments[0])) {
            return true
        }
        compiling_program() |> macro_error(call.at, "{describe(call.arguments[0])} can't be simply promoted to temp value")
        return false
    }
}
























