options gen2
options indenting = 4
options strict_smart_pointers = true


module macro_boost shared private







require daslib/ast_boost
require daslib/templates_boost

[macro_function, tag_function(macro_verify_tag), unused_argument(expr, prog, at, message)]
def public macro_verify(expr : bool; prog : ProgramPtr; at : LineInfo; message : string) {
    
    pass
}

[tag_function_macro(tag="macro_verify_tag")]
class MacroVerifyMacro : AstFunctionAnnotation {
    
    def override transform(var call : ExprCallFunc?; var errors : das_string) : ExpressionPtr {
        
        var res = qmacro_block() {
            if (!$e(call.arguments[0])) {
                macro_error($e(call.arguments[1]), $e(call.arguments[2]), $e(call.arguments[3]))
                return null
            }
        }
        res |> force_at(call.at)
        return res
    }
}

[macro]
class CaptureBlock : AstVisitor {
    
    @do_not_delete scope : table<Variable?>
    @do_not_delete captured : table<Variable?; ExprVar?>
    def override preVisitExprVar(expr : ExprVar?) : void {
        if (!(expr.varFlags.local || expr.varFlags.argument || expr.varFlags._block)) return
        let vptr = expr.variable
        if (!(scope |> key_exists(vptr))) {
            unsafe {
                captured[vptr] = reinterpret<ExprVar?>(expr)
            }
        }
    }
    def override preVisitExprLetVariable(expr : ExprLet?; arg : VariablePtr; lastArg : bool) : void {
        scope |> insert(arg)
    }
    def override preVisitExprForVariable(expr : ExprFor?; svar : VariablePtr; last : bool) : void {
        scope |> insert(svar)
    }
    def override preVisitExprBlockArgument(blk : ExprBlock?; arg : VariablePtr; lastArg : bool) : void {
        scope |> insert(arg)
    }
}

struct public CapturedVariable {
    
    variable : Variable?    
    expression : ExprVar?   
    eref : bool             
}

[macro_function]
def public capture_block(expr : ExpressionPtr) : array<CapturedVariable> {
    
    var astVisitor = new CaptureBlock()
    make_visitor(*astVisitor) $(adapter) {
        visit(expr, adapter)
    }
    var res := [for (k, v in keys(astVisitor.captured), values(astVisitor.captured)); CapturedVariable(variable=k, expression=v) ]
    unsafe {
        delete astVisitor
    }
    return <- res
}

[macro]
class ColletFinally : AstVisitor {
    
    @do_not_delete blocks : table<ExprBlock?>
    alwaysFor : bool
    def override preVisitExprBlock(blk : ExprBlock?) : void {
        unsafe {
            if (!empty(blk.finalList)) {
                blocks |> insert(reinterpret<ExprBlock?>(blk))
            } elif (alwaysFor && blk.blockFlags.forLoop) {
                blocks |> insert(reinterpret<ExprBlock?>(blk))
            }
        }
    }
    def override canVisitMakeBlockBody(expr : ExprMakeBlock?) : bool {
        return false
    }
}

[macro_function]
def public collect_finally(expr : ExpressionPtr; alwaysFor : bool = false) {
    
    
    
    var astVisitor = new ColletFinally(alwaysFor = alwaysFor)
    make_visitor(*astVisitor) $(adapter) {
        visit(expr, adapter)
    }
    var res := [for (k in keys(astVisitor.blocks)); k ]
    unsafe {
        delete astVisitor
    }
    return <- res
}

[macro]
class ColletLabels : AstVisitor {
    
    labels : table<int>
    def override preVisitExprLabel(expr : ExprLabel?) : void {
        labels |> insert(expr.labelName)
    }
    def override canVisitMakeBlockBody(expr : ExprMakeBlock?) : bool {
        return false
    }
}

[macro_function]
def public collect_labels(expr : ExpressionPtr) {
    
    
    var astVisitor = new ColletLabels()
    make_visitor(*astVisitor) $(adapter) {
        visit(expr, adapter)
    }
    var res := [for (k in keys(astVisitor.labels)); k ]
    unsafe {
        delete astVisitor
    }
    return <- res
}

[macro_function]
def public has_sideeffects(expr : Expression?) : bool {
    
    if (expr == null || expr.flags.noSideEffects
            || expr is ExprVar
            || expr is ExprConstInt || expr is ExprConstInt8 || expr is ExprConstInt16
            || expr is ExprConstInt64 || expr is ExprConstUInt || expr is ExprConstUInt8
            || expr is ExprConstUInt16 || expr is ExprConstUInt64 || expr is ExprConstFloat
            || expr is ExprConstFloat16
            || expr is ExprConstDouble || expr is ExprConstBool || expr is ExprConstString
            || expr is ExprConstPtr || expr is ExprConstRange || expr is ExprConstURange
            || expr is ExprConstRange64 || expr is ExprConstURange64
            || expr is ExprConstEnumeration || expr is ExprConstBitfield) return false
    
    if (expr is ExprField) return has_sideeffects((expr as ExprField).value)
    if (expr is ExprSafeField) return has_sideeffects((expr as ExprSafeField).value)
    if (expr is ExprSwizzle) return has_sideeffects((expr as ExprSwizzle).value)
    
    if (expr is ExprRef2Value) return has_sideeffects((expr as ExprRef2Value).subexpr)
    if (expr is ExprRef2Ptr) return has_sideeffects((expr as ExprRef2Ptr).subexpr)
    if (expr is ExprPtr2Ref) return has_sideeffects((expr as ExprPtr2Ref).subexpr)
    if (expr is ExprAddr) return false
    
    if (expr is ExprIs) return has_sideeffects((expr as ExprIs).subexpr)
    if (expr is ExprIsVariant) return has_sideeffects((expr as ExprIsVariant).value)
    if (expr is ExprAsVariant) return has_sideeffects((expr as ExprAsVariant).value)
    if (expr is ExprSafeAsVariant) return has_sideeffects((expr as ExprSafeAsVariant).value)
    
    if (expr is ExprCast) return has_sideeffects((expr as ExprCast).subexpr)
    
    if (expr is ExprTypeInfo || expr is ExprTypeDecl || expr is ExprTag) return false
    
    if (expr is ExprAt) {
        let at_e = expr as ExprAt
        
        if (at_e.subexpr == null || at_e.subexpr._type == null
                || at_e.subexpr._type.isGoodTableType) return true
        return has_sideeffects(at_e.subexpr) || has_sideeffects(at_e.index)
    }
    if (expr is ExprSafeAt) {
        let sat = expr as ExprSafeAt
        return has_sideeffects(sat.subexpr) || has_sideeffects(sat.index)
    }
    
    if (expr is ExprNullCoalescing) {
        let nc = expr as ExprNullCoalescing
        return has_sideeffects(nc.subexpr) || has_sideeffects(nc.defaultValue)
    }
    
    if (expr is ExprStringBuilder) {
        let sb = expr as ExprStringBuilder
        for (e in sb.elements) {
            if (has_sideeffects(e)) return true
        }
        return false
    }
    
    if (expr is ExprKeyExists) {
        let ke = expr as ExprKeyExists
        for (a in ke.arguments) {
            if (has_sideeffects(a)) return true
        }
        return false
    }
    
    if (expr is ExprOp1) {
        let e1 = expr as ExprOp1
        
        
        
        if (is_mutation_op1(e1.op)
                || (e1.func != null && func_has_sideeffects(e1.func))
                || (e1.func == null && !is_safe_op1(e1.op))) return true
        return has_sideeffects(e1.subexpr)
    }
    if (expr is ExprOp2) {
        let e2 = expr as ExprOp2
        if (is_mutation_op2(e2.op) || e2.op == "/" || e2.op == "%"
                || (e2.func != null && func_has_sideeffects(e2.func))
                || (e2.func == null && !is_safe_op2(e2.op))) return true
        return has_sideeffects(e2.left) || has_sideeffects(e2.right)
    }
    if (expr is ExprOp3) {
        let e3 = expr as ExprOp3
        
        return has_sideeffects(e3.subexpr) || has_sideeffects(e3.left) || has_sideeffects(e3.right)
    }
    if (expr is ExprCall) {
        let ec = expr as ExprCall
        if (func_has_sideeffects(ec.func)) return true
        for (a in ec.arguments) {
            if (has_sideeffects(a)) return true
        }
        return false
    }
    
    return true
}

[macro_function]
def private func_has_sideeffects(f : Function?) : bool {
    
    return (f == null || !f.flags.builtIn
        || f.flags.knownSideEffects || f.flags.unsafeOperation)
}

[macro_function]
def private is_safe_op1(op : das_string) : bool {
    
    return op == "-" || op == "!" || op == "~" || op == "+"
}

[macro_function]
def private is_safe_op2(op : das_string) : bool {
    
    return (op == "+" || op == "-" || op == "*"
        || op == "==" || op == "!=" || op == "<" || op == "<=" || op == ">" || op == ">="
        || op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>"
        || op == "&&" || op == "||")
}

[macro_function]
def private is_mutation_op1(op : das_string) : bool {
    
    return op == "++" || op == "--" || op == "+++" || op == "---"
}

[macro_function]
def private is_mutation_op2(op : das_string) : bool {
    
    return (op == "+=" || op == "-=" || op == "*=" || op == "/=" || op == "%="
        || op == "&=" || op == "|=" || op == "^="
        || op == "<<=" || op == ">>="
        || op == "&&=" || op == "||=" || op == "^^=")
}

