options gen2
options indenting = 4
options strict_smart_pointers = true

module sort_boost shared private









require daslib/ast_boost
require daslib/array_boost public
require daslib/macro_boost














def public partial_sort(var a : array<auto(TT)> | #; n : int) {
    if (length(a) <= 1 || n <= 0) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        __builtin_array_lock(a)
        unsafe {
            __builtin_partial_sort(addr(a[0]), length(a), n)
        }
        __builtin_array_unlock(a)
    } static_elif (typeinfo is_vector(type<TT>)) {
        concept_assert(false, "there is no default compare function for vectors")
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_partial_sort_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), n) $(x, y : TT) : bool {
                    return x < y
                }
            } else {
                __builtin_partial_sort_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), n) $(x, y : TT) : bool {
                    return x < y
                }
            }
        }
    }
}


def public partial_sort(var a : array<auto(TT)> | #; n : int; cmp : block<(x, y : TT) : bool>) {
    if (length(a) <= 1 || n <= 0) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        unsafe {
            __builtin_partial_sort_cblock_array(a, typeinfo sizeof(a[0]), length(a), n, cmp)
        }
    } static_elif (typeinfo is_vector(type<TT>)) {
        unsafe {
            __builtin_partial_sort_cblock_array(a, typeinfo sizeof(a[0]), length(a), n, cmp)
        }
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_partial_sort_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), n, cmp)
            } else {
                __builtin_partial_sort_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), n, cmp)
            }
        }
    }
}





def public nth_element(var a : array<auto(TT)> | #; n : int) {
    if (length(a) <= 1 || n < 0 || n >= length(a)) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        __builtin_array_lock(a)
        unsafe {
            __builtin_nth_element(addr(a[0]), length(a), n)
        }
        __builtin_array_unlock(a)
    } static_elif (typeinfo is_vector(type<TT>)) {
        concept_assert(false, "there is no default compare function for vectors")
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_nth_element_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), n) $(x, y : TT) : bool {
                    return x < y
                }
            } else {
                __builtin_nth_element_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), n) $(x, y : TT) : bool {
                    return x < y
                }
            }
        }
    }
}


def public nth_element(var a : array<auto(TT)> | #; n : int; cmp : block<(x, y : TT) : bool>) {
    if (length(a) <= 1 || n < 0 || n >= length(a)) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        unsafe {
            __builtin_nth_element_cblock_array(a, typeinfo sizeof(a[0]), length(a), n, cmp)
        }
    } static_elif (typeinfo is_vector(type<TT>)) {
        unsafe {
            __builtin_nth_element_cblock_array(a, typeinfo sizeof(a[0]), length(a), n, cmp)
        }
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_nth_element_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), n, cmp)
            } else {
                __builtin_nth_element_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), n, cmp)
            }
        }
    }
}








def public make_heap(var a : array<auto(TT)> | #) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        __builtin_array_lock(a)
        unsafe {
            __builtin_make_heap(addr(a[0]), length(a))
        }
        __builtin_array_unlock(a)
    } static_elif (typeinfo is_vector(type<TT>)) {
        concept_assert(false, "there is no default compare function for vectors")
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_make_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            } else {
                __builtin_make_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            }
        }
    }
}


def public make_heap(var a : array<auto(TT)> | #; cmp : block<(x, y : TT) : bool>) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        unsafe {
            __builtin_make_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } static_elif (typeinfo is_vector(type<TT>)) {
        unsafe {
            __builtin_make_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_make_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            } else {
                __builtin_make_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            }
        }
    }
}



def public push_heap(var a : array<auto(TT)> | #) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        __builtin_array_lock(a)
        unsafe {
            __builtin_push_heap(addr(a[0]), length(a))
        }
        __builtin_array_unlock(a)
    } static_elif (typeinfo is_vector(type<TT>)) {
        concept_assert(false, "there is no default compare function for vectors")
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_push_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            } else {
                __builtin_push_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            }
        }
    }
}


def public push_heap(var a : array<auto(TT)> | #; cmp : block<(x, y : TT) : bool>) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        unsafe {
            __builtin_push_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } static_elif (typeinfo is_vector(type<TT>)) {
        unsafe {
            __builtin_push_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_push_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            } else {
                __builtin_push_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            }
        }
    }
}



def public pop_heap(var a : array<auto(TT)> | #) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        __builtin_array_lock(a)
        unsafe {
            __builtin_pop_heap(addr(a[0]), length(a))
        }
        __builtin_array_unlock(a)
    } static_elif (typeinfo is_vector(type<TT>)) {
        concept_assert(false, "there is no default compare function for vectors")
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_pop_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            } else {
                __builtin_pop_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a)) $(x, y : TT) : bool {
                    return x < y
                }
            }
        }
    }
}


def public pop_heap(var a : array<auto(TT)> | #; cmp : block<(x, y : TT) : bool>) {
    if (length(a) <= 1) return
    static_if (typeinfo is_numeric_comparable(type<TT>)) {
        unsafe {
            __builtin_pop_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } static_elif (typeinfo is_vector(type<TT>)) {
        unsafe {
            __builtin_pop_heap_cblock_array(a, typeinfo sizeof(a[0]), length(a), cmp)
        }
    } else {
        unsafe {
            static_if (typeinfo is_ref_type(type<TT>)) {
                __builtin_pop_heap_array_any_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            } else {
                __builtin_pop_heap_array_any_ref_cblock(a, typeinfo sizeof(a[0]), length(a), cmp)
            }
        }
    }
}







[call_macro(name="qsort")]
class QsortMacro : AstCallMacro {
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        macro_verify(expr.arguments |> length == 2, prog, expr.at, "expecting qsort(value, block)")
        if (expr.arguments[0]._type == null || expr.arguments[1]._type == null) return null
        
        macro_verify(expr.arguments[1]._type.baseType == Type.tBlock, prog, expr.at, "expecting 2nd argument to be block(<a,b:auto(TT)>:bool))")
        if (expr.arguments[0]._type.baseType == Type.tFixedArray || expr.arguments[0]._type.baseType == Type.tArray) {
            var call = new ExprCall(name := "sort", at = expr.at)
            emplace_new(call.arguments) <| clone_expression(expr.arguments[0])
            emplace_new(call.arguments) <| clone_expression(expr.arguments[1])
            return <- call
        } elif (expr.arguments[0]._type.baseType == Type.tHandle) {
            var call = new ExprCall(name := "sort", at = expr.at)
            var tsa = new ExprCall(name := "temp_array", at = expr.at)
            emplace_new(tsa.arguments) <| clone_expression(expr.arguments[0])
            tsa.genFlags.alwaysSafe = true
            emplace(call.arguments, tsa)
            emplace_new(call.arguments) <| clone_expression(expr.arguments[1])
            return <- call
        } else {
            macro_error(prog, expr.at, "can only qsort [], array, or handled vector")
            return null
        }
    }
}


def private build_dispatch_call(prog : ProgramPtr; var expr : ExprCallMacro?; macroName, opName : string; takesN : bool) : ExpressionPtr {
    let expectedArgs = takesN ? 3 : 2
    let argShape = takesN ? "(value, n, block)" : "(value, block)"
    macro_verify(expr.arguments |> length == expectedArgs, prog, expr.at, "expecting {macroName}{argShape}")
    for (a in expr.arguments) {
        if (a._type == null) return null
    }
    let blockIndex = takesN ? 2 : 1
    macro_verify(expr.arguments[blockIndex]._type.baseType == Type.tBlock, prog, expr.at, "expecting block argument as last")
    let srcType = expr.arguments[0]._type
    if (srcType.baseType == Type.tArray) {
        var call = new ExprCall(name := opName, at = expr.at)
        for (a in expr.arguments) {
            emplace_new(call.arguments) <| clone_expression(a)
        }
        return <- call
    } elif (srcType.baseType == Type.tHandle) {
        var call = new ExprCall(name := opName, at = expr.at)
        var tsa = new ExprCall(name := "temp_array", at = expr.at)
        emplace_new(tsa.arguments) <| clone_expression(expr.arguments[0])
        tsa.genFlags.alwaysSafe = true
        emplace(call.arguments, tsa)
        for (i in range(1, expr.arguments |> length)) {
            emplace_new(call.arguments) <| clone_expression(expr.arguments[i])
        }
        return <- call
    } else {
        macro_error(prog, expr.at, "{macroName} can only operate on array or handled vector")
        return null
    }
}

[call_macro(name="qpartial_sort")]
class QPartialSortMacro : AstCallMacro {
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        return <- build_dispatch_call(prog, expr, "qpartial_sort", "partial_sort", true)
    }
}

[call_macro(name="qnth_element")]
class QNthElementMacro : AstCallMacro {
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        return <- build_dispatch_call(prog, expr, "qnth_element", "nth_element", true)
    }
}

[call_macro(name="qmake_heap")]
class QMakeHeapMacro : AstCallMacro {
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        return <- build_dispatch_call(prog, expr, "qmake_heap", "make_heap", false)
    }
}

[call_macro(name="qpush_heap")]
class QPushHeapMacro : AstCallMacro {
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        return <- build_dispatch_call(prog, expr, "qpush_heap", "push_heap", false)
    }
}

[call_macro(name="qpop_heap")]
class QPopHeapMacro : AstCallMacro {
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        return <- build_dispatch_call(prog, expr, "qpop_heap", "pop_heap", false)
    }
}
