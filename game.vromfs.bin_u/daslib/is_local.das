options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module is_local shared public

require ast public
require rtti
require daslib/ast_boost
require strings

def is_temp_safe(expr : ExpressionPtr) : bool {
    
    
    if (expr is ExprVar) {
        return (expr as ExprVar).varFlags.local 
    } elif (expr is ExprAt) {
        let ea = expr as ExprAt
        if (ea.subexpr._type != null && ea.subexpr._type.dim |> length != 0) {
            return is_temp_safe(ea.subexpr)
        }
    } elif (expr is ExprField) {
        let ef = expr as ExprField
        if (!(ef.value._type.baseType == Type.tHandle) || (ef.value._type.isLocal)) {
            return is_temp_safe(ef.value)
        }
    } elif (expr is ExprSwizzle) {
        return is_temp_safe((expr as ExprSwizzle).value)    
    } elif (expr is ExprCall) {
        return expr._type.isRef                             
    }
    return false;
}

def is_shared_expr(expr : ExpressionPtr) {
    
    if (expr is ExprVar) {
        let evar = expr as ExprVar
        if (evar.variable.flags.global_shared) {
            return true
        }
        if (evar.variable.source != null) {
            return is_shared_expr(evar.variable.source)
        }
        return false
    } elif (expr is ExprCall) {
        let ecall = expr as ExprCall
        let func = ecall.func;
        if (func != null && func._module != null &&
            (string(func.name).starts_with("builtin`keys`") || string(func.name).starts_with("builtin`values`"))) {
            return is_shared_expr(ecall.arguments[0])
        }
        return false
    } elif (expr is ExprAt) {
        let ea = expr as ExprAt
        if (ea.subexpr._type != null && (ea.subexpr._type.baseType == Type.tArray || ea.subexpr._type.isArray)) {
            return is_shared_expr(ea.subexpr)
        }
    } elif (expr is ExprField) {
        let ef = expr as ExprField
        if (!(ef.value._type.baseType == Type.tHandle) || (ef.value._type.isLocal)) {
            return is_shared_expr(ef.value)
        }
    } elif (expr is ExprSwizzle) {
        return is_shared_expr((expr as ExprSwizzle).value)
    }
    return false
}

def is_local_expr(expr : ExpressionPtr) {
    
    if (expr is ExprVar) {
        return (expr as ExprVar).varFlags.local
    } elif (expr is ExprAt) {
        let ea = expr as ExprAt
        if (ea.subexpr._type != null && ea.subexpr._type.dim |> length != 0) {
            return is_local_expr(ea.subexpr)
        }
    } elif (expr is ExprField) {
        let ef = expr as ExprField
        if (!(ef.value._type.baseType == Type.tHandle) || (ef.value._type.isLocal)) {
            return is_local_expr(ef.value)
        }
    } elif (expr is ExprSwizzle) {
        return is_local_expr((expr as ExprSwizzle).value)
    }
    return false
}

def is_local_or_global_expr(expr : ExpressionPtr) {
    
    if (expr is ExprVar) {
        let ev = expr as ExprVar
        return ev.varFlags.local || !(ev.varFlags.argument || ev.varFlags._block)
    } elif (expr is ExprAt) {
        let ea = expr as ExprAt
        if (ea.subexpr._type != null && ea.subexpr._type.dim |> length != 0) {
            return is_local_or_global_expr(ea.subexpr)
        }
    } elif (expr is ExprField) {
        let ef = expr as ExprField
        if (!(ef.value._type.baseType == Type.tHandle) || (ef.value._type.isLocal)) {
            return is_local_or_global_expr(ef.value)
        }
    } elif (expr is ExprSwizzle) {
        let ef = expr as ExprSwizzle
        return is_local_or_global_expr(ef.value)
    }
    return false
}

def is_scope_expr(expr : ExpressionPtr) {
    
    if (expr is ExprVar) {
        return true
    } elif (expr is ExprAt) {
        let ea = expr as ExprAt
        if (ea.subexpr._type != null && ea.subexpr._type.dim |> length != 0) {
            return is_scope_expr(ea.subexpr)
        }
    } elif (expr is ExprField) {
        let ef = expr as ExprField
        if (!(ef.value._type.baseType == Type.tHandle) || (ef.value._type.isLocal)) {
            return is_scope_expr(ef.value)
        }
    } elif (expr is ExprSwizzle) {
        let ef = expr as ExprSwizzle
        return is_scope_expr(ef.value)
    }
    return false
}
