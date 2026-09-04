options gen2
options indenting = 4
options strict_smart_pointers = true
options _comment_hygiene = true

module flatten shared private













require daslib/ast
require daslib/ast_boost
require daslib/templates_boost
require daslib/rtti
require daslib/flatten_opt







let private PHASE_LOWERED = 1
let private PHASE_FOLDED = 2
let private PHASE_OPTIMIZED = 3
let private PHASE_FUSED = 4
let private PHASE_DONE = 999




let private FLATTEN_BARRIERS : table<string> <- {
    "tex2d", "noise"
}




let private STD_WHITELIST : table<string> <- {
    "min", "max", "abs", "clamp", "saturate", "sign", "floor", "ceil", "round", "trunc", "frac",
    "sqrt", "rsqrt", "pow", "exp", "exp2", "log", "log2",
    "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sincos",
    "radians", "degrees",   
    "dot", "cross", "length", "normalize", "distance", "reflect", "refract",
    "hmin", "hmax", "hadd",   
    "lerp", "mix", "step", "smooth_step", "rcp", "mad",
    "float2", "float3", "float4", "int2", "int3", "int4", "uint2", "uint3", "uint4"
}




let private ASSIGN_BASE : table<string; string> <- {
    "+=" => "+", "-=" => "-", "*=" => "*", "/=" => "/", "%=" => "%",
    "&=" => "&", "|=" => "|", "^=" => "^", "<<=" => "<<", ">>=" => ">>"
}

def private twin_name(func : FunctionPtr) : string {
    return "{func.name}_flat"
}

def private get_flatten_phase(func : FunctionPtr) : int {
    for (ann in func.annotations) {
        if (ann.annotation.name == "flatten") {
            let pv = find_arg(ann.arguments, "phase")
            if (pv is tInt) return pv as tInt
        }
    }
    return -1
}

def private set_flatten_phase(var func : FunctionPtr; ph : int) {
    for (ann in func.annotations) {
        if (ann.annotation.name != "flatten") continue
        var found = false
        for (a in ann.arguments) {
            if ("{a.name}" == "phase") {
                a.iValue = ph
                found = true
            }
        }
        if (!found) ann.arguments |> add_annotation_argument("phase", ph)
    }
}




let public FLATTEN_MAX_UNROLL = 4096

def private get_flatten_max_unroll(func : FunctionPtr) : int {
    for (ann in func.annotations) {
        if (ann.annotation.name == "flatten") {
            let mv = find_arg(ann.arguments, "max_unroll")
            if (mv is tInt) return mv as tInt
        }
    }
    return FLATTEN_MAX_UNROLL
}





struct private LoopMask {
    loopLive : string
    iterLive : string
}

class private FlatCtx {
    counter   : int
    liveName  : string
    retName   : string
    hasRet    : bool
    worklist  : array<string>
    loopMasks : array<LoopMask>   
    whitelist : table<string>     
    unrollFactor : int            
    maxUnroll : int               
    ok        : bool
    err      : string
}

def private fresh(var ctx : FlatCtx?; pfx : string) : string {
    let n = "{pfx}_{ctx.counter}"
    ctx.counter ++
    return n
}

def private contains(a : array<string>; s : string) : bool {
    for (x in a) {
        if (x == s) return true
    }
    return false
}

def private p_and(a, b : ExpressionPtr) : ExpressionPtr {
    if (a == null && b == null) return null
    if (a == null) return clone_expression(b)
    if (b == null) return clone_expression(a)
    return qmacro($e(a) && $e(b))
}




def private live_pred(ctx : FlatCtx?; structPred : ExpressionPtr; exclude : string = "") : ExpressionPtr {
    var acc : ExpressionPtr = null
    if (ctx.liveName != exclude) {
        acc = qmacro($i(ctx.liveName))
    }
    for (lm in ctx.loopMasks) {
        if (lm.loopLive != "" && lm.loopLive != exclude) {
            acc = acc == null ? qmacro($i(lm.loopLive)) : qmacro($e(acc) && $i(lm.loopLive))
        }
        if (lm.iterLive != "" && lm.iterLive != exclude) {
            acc = acc == null ? qmacro($i(lm.iterLive)) : qmacro($e(acc) && $i(lm.iterLive))
        }
    }
    if (structPred != null) {
        acc = acc == null ? clone_expression(structPred) : qmacro($e(acc) && $e(structPred))
    }
    return acc
}




def private emit_narrow(var out : array<ExpressionPtr>; name : string; term : ExpressionPtr) {
    if (term == null) {
        out |> push <| qmacro_expr(${ $i(name) = false; })
    } else {
        out |> push <| qmacro_expr(${ $i(name) = $i(name) && !($e(term)); })
    }
}

def private is_user_call(e : ExpressionPtr) : bool {
    if (!(e is ExprCall)) return false
    let c = e as ExprCall
    return c.func != null && !c.func.flags.builtIn && c.func.body != null
}


def private inline_call(var ctx : FlatCtx?; call : ExprCall?; structPred : ExpressionPtr; var out : array<ExpressionPtr>) : ExpressionPtr {
    let callee = call.func
    let cname = string(callee.name)
    if (ctx.worklist |> contains(cname)) {
        ctx.ok = false
        ctx.err = "flatten: recursion through '{cname}' cannot be flattened"
        return qmacro(0)
    }
    let liveN = fresh(ctx, "__flat_live")
    let isVoidCallee = callee.result.isVoid
    var subst : Template
    for (p, ai in callee.arguments, count()) {
        let argN = fresh(ctx, "__flat_arg")
        
        let lifted = lift_expr(ctx, call.arguments[ai], structPred, out)
        out |> push <| qmacro_expr(${ var $i(argN) = $e(lifted); })
        subst |> replaceVariable(string(p.name)) <| qmacro($i(argN))
    }
    
    var seenLocals : array<string>
    let calleeLocals <- collect_let_names(callee.body)
    for (ln in calleeLocals) {
        if (!(seenLocals |> contains(ln))) {
            seenLocals |> push(ln)
            subst |> renameVariable(ln, fresh(ctx, "__flat_loc"))
        }
    }
    
    let seed = live_pred(ctx, structPred)
    out |> push <| qmacro_expr(${ var $i(liveN) = $e(seed); })
    
    var retN = ""
    if (!isVoidCallee) {
        retN = fresh(ctx, "__flat_ret")
        var crt = clone_type(callee.result)
        crt.flags.constant = false
        
        out |> push <| qmacro_expr(${ var $i(retN) : $t(crt); })
    }
    let savedLive = ctx.liveName
    let savedRet = ctx.retName
    let savedHas = ctx.hasRet
    var savedLoops <- ctx.loopMasks   
    ctx.liveName = liveN
    ctx.retName = retN
    ctx.hasRet = !isVoidCallee
    ctx.worklist |> push(cname)
    var cbody = clone_expression(callee.body)
    subst |> apply_template(call.at, cbody, false)
    lower_list(ctx, cbody as ExprBlock, null, out)
    ctx.worklist |> pop()
    ctx.liveName = savedLive
    ctx.retName = savedRet
    ctx.hasRet = savedHas
    ctx.loopMasks <- savedLoops
    if (isVoidCallee) return null
    return qmacro($i(retN))
}




def private lift_expr(var ctx : FlatCtx?; e : ExpressionPtr; structPred : ExpressionPtr; var out : array<ExpressionPtr>) : ExpressionPtr {   
    if (e == null) return null
    if (e is ExprCall) {
        let c = e as ExprCall
        let bname = string(c.name)
        
        if (key_exists(ctx.whitelist, simple_name(bname))) {
            var n = clone_expression(e)
            var o = n as ExprCall
            for (ai in range(length(c.arguments))) {
                o.arguments[ai] = lift_expr(ctx, c.arguments[ai], structPred, out)
            }
            return n
        }
        
        if (is_user_call(e)) {
            return inline_call(ctx, c, structPred, out)
        }
        
        if (is_all_const(e) && eval_to_const_supported(e._type)) {
            var n = clone_expression(e)
            var o = n as ExprCall
            for (ai in range(length(c.arguments))) {
                o.arguments[ai] = lift_expr(ctx, c.arguments[ai], structPred, out)
            }
            return n
        }
        
        ctx.ok = false
        ctx.err = "flatten: builtin '{bname}' is not on the whitelist (not GPU-expressible / may have side effects)"
        return clone_expression(e)
    }
    if (e is ExprOp2) {
        var n = clone_expression(e)
        var o = n as ExprOp2
        let oe = e as ExprOp2
        o.left = lift_expr(ctx, oe.left, structPred, out)
        o.right = lift_expr(ctx, oe.right, structPred, out)
        return n
    }
    if (e is ExprOp1) {
        var n = clone_expression(e)
        var o = n as ExprOp1
        let oe = e as ExprOp1
        o.subexpr = lift_expr(ctx, oe.subexpr, structPred, out)
        return n
    }
    if (e is ExprOp3) {
        var n = clone_expression(e)
        var o = n as ExprOp3
        let oe = e as ExprOp3
        o.subexpr = lift_expr(ctx, oe.subexpr, structPred, out)
        o.left = lift_expr(ctx, oe.left, structPred, out)
        o.right = lift_expr(ctx, oe.right, structPred, out)
        return n
    }
    
    if (e is ExprField) {
        var n = clone_expression(e)
        var o = n as ExprField
        o.value = lift_expr(ctx, (e as ExprField).value, structPred, out)
        return n
    }
    if (e is ExprSwizzle) {
        var n = clone_expression(e)
        var o = n as ExprSwizzle
        o.value = lift_expr(ctx, (e as ExprSwizzle).value, structPred, out)
        return n
    }
    if (e is ExprCast) {
        var n = clone_expression(e)
        var o = n as ExprCast
        o.subexpr = lift_expr(ctx, (e as ExprCast).subexpr, structPred, out)
        return n
    }
    if (e is ExprAt) {
        var n = clone_expression(e)
        var o = n as ExprAt
        let oe = e as ExprAt
        o.subexpr = lift_expr(ctx, oe.subexpr, structPred, out)
        o.index = lift_expr(ctx, oe.index, structPred, out)
        return n
    }
    if (e is ExprMakeStruct) {
        var n = clone_expression(e)
        var o = n as ExprMakeStruct
        for (si in range(length(o.structs))) {
            for (fld in *(o.structs[si])) {
                fld.value = lift_expr(ctx, fld.value, structPred, out)
            }
        }
        return n
    }
    if (e is ExprMakeTuple) {
        var n = clone_expression(e)
        var o = n as ExprMakeTuple
        for (vi in range(length(o.values))) {
            o.values[vi] = lift_expr(ctx, o.values[vi], structPred, out)
        }
        return n
    }
    if (e is ExprMakeArray) {
        var n = clone_expression(e)
        var o = n as ExprMakeArray
        for (vi in range(length(o.values))) {
            o.values[vi] = lift_expr(ctx, o.values[vi], structPred, out)
        }
        return n
    }
    
    if (e is ExprRef2Value) {
        var n = clone_expression(e)
        var o = n as ExprRef2Value
        o.subexpr = lift_expr(ctx, (e as ExprRef2Value).subexpr, structPred, out)
        return n
    }
    if (e is ExprPtr2Ref) {
        var n = clone_expression(e)
        var o = n as ExprPtr2Ref
        o.subexpr = lift_expr(ctx, (e as ExprPtr2Ref).subexpr, structPred, out)
        return n
    }
    return clone_expression(e)
}

def private lower_value(var ctx : FlatCtx?; e : ExpressionPtr; structPred : ExpressionPtr; var out : array<ExpressionPtr>) : ExpressionPtr {
    return lift_expr(ctx, e, structPred, out)
}

def private lower_list(var ctx : FlatCtx?; blk : ExprBlock?; structPred : ExpressionPtr; var out : array<ExpressionPtr>) {
    for (s in blk.list) {
        lower_stmt(ctx, s, structPred, out)
    }
}

def private lower_branch(var ctx : FlatCtx?; br : ExpressionPtr; structPred : ExpressionPtr; var out : array<ExpressionPtr>) {
    if (br is ExprBlock) {
        lower_list(ctx, br as ExprBlock, structPred, out)
    } else {
        lower_stmt(ctx, br, structPred, out)
    }
}




def private lower_loop_exit(var ctx : FlatCtx?; structPred : ExpressionPtr; var out : array<ExpressionPtr>; isBreak : bool) {
    if (empty(ctx.loopMasks)) {
        ctx.ok = false
        ctx.err = "flatten: internal error - {isBreak ? "break" : "continue"} outside a flattened loop"
        return
    }
    let lm = ctx.loopMasks[length(ctx.loopMasks) - 1]
    let nm = isBreak ? lm.loopLive : lm.iterLive
    if (nm == "") {
        ctx.ok = false
        ctx.err = "flatten: internal error - {isBreak ? "break" : "continue"} mask was not allocated"
        return
    }
    emit_narrow(out, nm, live_pred(ctx, structPred, nm))
}

def private lower_stmt(var ctx : FlatCtx?; stmt : ExpressionPtr; structPred : ExpressionPtr; var out : array<ExpressionPtr>) {   
    if (stmt is ExprReturn) {
        let r = stmt as ExprReturn
        if (ctx.hasRet && r.subexpr != null) {
            let valExpr = lower_value(ctx, r.subexpr, structPred, out)
            let pred = live_pred(ctx, structPred)
            out |> push <| qmacro_expr(${ $i(ctx.retName) = $e(pred) ? $e(valExpr) : $i(ctx.retName); })
        }
        
        emit_narrow(out, ctx.liveName, live_pred(ctx, structPred, ctx.liveName))
    } elif (stmt is ExprIfThenElse) {
        let ite = stmt as ExprIfThenElse
        let cN = fresh(ctx, "__flat_c")
        out |> push <| qmacro_expr(${ let $i(cN) = $e(ite.cond); })
        lower_branch(ctx, ite.if_true, p_and(structPred, qmacro($i(cN))), out)
        if (ite.if_false != null) {
            lower_branch(ctx, ite.if_false, p_and(structPred, qmacro(!$i(cN))), out)
        }
    } elif (stmt is ExprCopy) {
        let cp = stmt as ExprCopy
        let rhs = lower_value(ctx, cp.right, structPred, out)
        let pred = live_pred(ctx, structPred)
        out |> push <| qmacro_expr(${ $e(cp.left) = $e(pred) ? $e(rhs) : $e(cp.left); })
    } elif (stmt is ExprLet) {
        
        var letClone = clone_expression(stmt)
        var lc = letClone as ExprLet
        for (v in lc.variables) {
            if (v.init != null) {
                v.init = lower_value(ctx, v.init, structPred, out)
            } else {
                
                v.init = zero_const_of(v._type, v.at)
            }
        }
        out |> push <| letClone
    } elif (stmt is ExprFor) {
        lower_for(ctx, stmt as ExprFor, structPred, out)
    } elif (stmt is ExprWhile) {
        ctx.ok = false
        ctx.err = "flatten: while loops are not supported; use a fixed range(N) or array-literal for loop"
    } elif (stmt is ExprBreak) {
        
        lower_loop_exit(ctx, structPred, out, true)
    } elif (stmt is ExprContinue) {
        
        lower_loop_exit(ctx, structPred, out, false)
    } elif (stmt is ExprMove || stmt is ExprClone) {
        ctx.ok = false
        ctx.err = "flatten: move (<-) / clone (:=) cannot be predicated; only copyable-value assignment is supported"
    } elif (stmt is ExprOp2 && key_exists(ASSIGN_BASE, "{(stmt as ExprOp2).op}")) {
        
        let o = stmt as ExprOp2
        let bop = ASSIGN_BASE?["{o.op}"] ?? ""
        let pred = live_pred(ctx, structPred)
        var combined = new ExprOp2(at = o.at, op := bop, left = clone_expression(o.left),
            right = lower_value(ctx, o.right, structPred, out))
        out |> push <| qmacro_expr(${ $e(o.left) = $e(pred) ? $e(combined) : $e(o.left); })
    } elif (stmt is ExprOp1 && ("{(stmt as ExprOp1).op}" == "++" || "{(stmt as ExprOp1).op}" == "--")) {
        
        let o = stmt as ExprOp1
        let bop = "{o.op}" == "++" ? "+" : "-"
        let pred = live_pred(ctx, structPred)
        var combined = new ExprOp2(at = o.at, op := bop, left = clone_expression(o.subexpr),
            right = new ExprConstInt(at = o.at, value = 1))
        out |> push <| qmacro_expr(${ $e(o.subexpr) = $e(pred) ? $e(combined) : $e(o.subexpr); })
    } elif (stmt is ExprBlock) {
        
        lower_list(ctx, stmt as ExprBlock, structPred, out)
    } elif (stmt is ExprWith) {
        
        lower_branch(ctx, (stmt as ExprWith).body, structPred, out)
    } else {
        
        lower_value(ctx, stmt, structPred, out)
    }
}




class private LetNameScan : AstVisitor {
    names : array<string>
    def override preVisitExprLet(expr : ExprLet?) : void {
        for (v in expr.variables) {
            names |> push("{v.name}")   
        }
    }
}

def private collect_let_names(body : ExpressionPtr) : array<string> {
    var v = new LetNameScan()
    make_visitor(*v) $(adapter) {
        visit(body, adapter)
    }
    var result <- v.names
    unsafe {
        delete v
    }
    return <- result
}




class private BreakContinueScan : AstVisitor {
    depth       : int
    hasBreak    : bool
    hasContinue : bool
    def override preVisitExprFor(expr : ExprFor?) : void {
        depth ++
    }
    def override visitExprFor(var expr : ExprFor?) : ExpressionPtr {
        depth --
        return expr
    }
    def override preVisitExprWhile(expr : ExprWhile?) : void {
        depth ++
    }
    def override visitExprWhile(var expr : ExprWhile?) : ExpressionPtr {
        depth --
        return expr
    }
    def override preVisitExprBreak(expr : ExprBreak?) : void {
        if (depth == 0) {
            hasBreak = true
        }
    }
    def override preVisitExprContinue(expr : ExprContinue?) : void {
        if (depth == 0) {
            hasContinue = true
        }
    }
}

def private scan_break_continue(body : ExpressionPtr; var hasBreak : bool&; var hasContinue : bool&) {
    var v = new BreakContinueScan()
    make_visitor(*v) $(adapter) {
        visit(body, adapter)
    }
    if (v.hasBreak) {
        hasBreak = true
    }
    if (v.hasContinue) {
        hasContinue = true
    }
    unsafe {
        delete v
    }
}




def private for_source_substs(var ctx : FlatCtx?; src : Expression?; at : LineInfo) : array<ExpressionPtr> {
    var substs : array<ExpressionPtr>
    if (src is ExprConstRange) {
        for (i in (src as ExprConstRange).value) {
            var e : ExpressionPtr = new ExprConstInt(at = at, value = i)
            substs |> push(e)   
        }
    } elif (src is ExprConstURange) {
        for (i in (src as ExprConstURange).value) {
            var e : ExpressionPtr = new ExprConstUInt(at = at, value = i)
            substs |> push(e)   
        }
    } else {
        
        var mk : ExprMakeArray? = null
        if (src is ExprMakeArray) {
            mk = src as ExprMakeArray
        } elif (src is ExprCall && !empty((src as ExprCall).arguments) &&
                (src as ExprCall).arguments[0] is ExprMakeArray) {
            mk = (src as ExprCall).arguments[0] as ExprMakeArray
        }
        if (mk == null) {
            ctx.ok = false
            ctx.err = "flatten: for loop source must be a constant range(N)/urange(N) or an array literal"
            return <- substs
        }
        substs <- [for (v in mk.values); clone_expression(v)]
    }
    return <- substs
}




def private lower_for(var ctx : FlatCtx?; efor : ExprFor?; structPred : ExpressionPtr; var out : array<ExpressionPtr>) {   
    let nIter = length(efor.iterators)
    if (nIter == 0 || length(efor.sources) != nIter) {
        ctx.ok = false
        ctx.err = "flatten: a for loop needs one source per iterator"
        return
    }
    
    var perSource : array<array<ExpressionPtr>>
    perSource |> reserve(nIter)
    var count = -1
    for (si in range(nIter)) {
        var s <- for_source_substs(ctx, efor.sources[si], efor.at)
        if (!ctx.ok) {
            return
        }
        if (count >= 0 && length(s) != count) {
            ctx.ok = false
            ctx.err = "flatten: parallel for sources must all have the same length ({count} vs {length(s)})"
            return
        }
        count = length(s)
        perSource |> emplace(s)
    }
    
    let projected = int64(ctx.unrollFactor) * int64(count)
    if (projected > int64(ctx.maxUnroll)) {
        ctx.ok = false
        ctx.err = "flatten: loop unrolling exceeds max_unroll={ctx.maxUnroll} (would expand to {projected} iterations); reduce the range/nesting or raise [flatten(max_unroll=N)]"
        return
    }
    let savedFactor = ctx.unrollFactor
    ctx.unrollFactor = int(projected)
    let localNames <- collect_let_names(efor.body)
    
    var hasBreak = false
    var hasContinue = false
    scan_break_continue(efor.body, hasBreak, hasContinue)
    var pushed = false
    if (hasBreak || hasContinue) {
        var loopName = ""
        if (hasBreak) {
            loopName = fresh(ctx, "__flat_loop")
            out |> push <| qmacro_expr(${ var $i(loopName) = true; })   
        }
        ctx.loopMasks |> push(LoopMask(loopLive = loopName, iterLive = ""))
        pushed = true
    }
    for (k in range(count)) {
        if (pushed && hasContinue) {
            
            let iterName = fresh(ctx, "__flat_iter")
            out |> push <| qmacro_expr(${ var $i(iterName) = true; })
            ctx.loopMasks[length(ctx.loopMasks) - 1].iterLive = iterName
        }
        var iblk = clone_expression(efor.body)
        var rules : Template
        
        for (vi in range(nIter)) {
            let van = "{efor.iterators[vi]}"
            remove_deref(van, iblk)            
            rules |> replaceVariable(van) <| perSource[vi][k]
        }
        
        for (ln in localNames) {
            rules |> renameVariable(ln, "{ln}_{k}")
        }
        apply_template(rules, efor.at, iblk, false)
        lower_branch(ctx, iblk, structPred, out)
        if (!ctx.ok) {
            if (pushed) {
                ctx.loopMasks |> pop()
            }
            ctx.unrollFactor = savedFactor
            return
        }
    }
    if (pushed) {
        ctx.loopMasks |> pop()
    }
    ctx.unrollFactor = savedFactor
}

[macro_function]
def public flatten_function(var func : FunctionPtr; whitelist : table<string>; maxUnroll : int = FLATTEN_MAX_UNROLL) : FlatCtx? {
    
    
    
    var ctx = new FlatCtx(counter = 0, liveName = "__flat_live", retName = "__flat_ret",
        hasRet = !func.result.isVoid, unrollFactor = 1, maxUnroll = maxUnroll, ok = true)
    ctx.whitelist := whitelist
    if (!(func.body is ExprBlock)) return ctx
    let bodyBlk = func.body as ExprBlock
    
    
    ast_gc_collect_scope(func) {
        var out : array<ExpressionPtr>
        out |> push <| qmacro_expr(${ var $i(ctx.liveName) = true; })
        if (ctx.hasRet) {
            var rt = clone_type(func.result)
            rt.flags.constant = false
            
            
            
            rt.flags.safeWhenUninitialized = true
            out |> push <| qmacro_expr(${ var $i(ctx.retName) : $t(rt); })
        }
        lower_list(ctx, bodyBlk, null, out)
        if (ctx.hasRet) {
            out |> push <| qmacro_expr(${ return $i(ctx.retName); })
        }
        if (ctx.ok) {
            dse_pass(out)          
            copy_prop_pass(out)    
                                   
            mask_const_prop_pass(out)  
                                   
            dse_pass(out)          
            ssa_rename_pass(out)   
        }
        var newBody = new ExprBlock(at = func.body.at)
        for (s in out) {
            newBody.list |> emplace(s)
        }
        func.body = newBody
    }
    return ctx
}



[macro_function]
def public flatten_no_fast_math : bool {
    
    
    
    return compiling_program()._options |> find_arg("_flatten_no_fast_math") ?as tBool ?? false
}

[macro_function]
def public flatten_expand_lerp : bool {
    
    
    
    return compiling_program()._options |> find_arg("_flatten_expand_lerp") ?as tBool ?? false
}

[macro_function]
def public flatten_hadd_pack_pairs : bool {
    
    return compiling_program()._options |> find_arg("_flatten_hadd_pack_pairs") ?as tBool ?? false
}

[macro_function]
def public flatten_fold(var func : FunctionPtr; no_fast_math : bool = false; expand_lerp : bool = false) : bool {
    
    
    
    return fold_body(func, no_fast_math, expand_lerp)
}

[macro_function]
def public flatten_log_cse : bool {
    
    
    
    return compiling_program()._options |> find_arg("_flatten_log_cse") ?as tBool ?? false
}

[macro_function]
def public flatten_optimize(var func : FunctionPtr; barriers : table<string>; no_fast_math : bool = false; log_cse : bool = false) : bool {
    
    
    
    return flatten_preshade_cse(func, barriers, no_fast_math, log_cse)
}

[macro_function]
def public flatten_pack(var func : FunctionPtr; no_fast_math : bool = false) : bool {
    
    
    
    return pack_map_reduce(func, no_fast_math)
}

[macro_function]
def public flatten_fuse(var func : FunctionPtr; no_fast_math : bool = false; hadd_min_width : int = 3) : bool {
    
    return fuse_body(func, no_fast_math, hadd_min_width)
}

def public flatten_opt_residuals(var func : FunctionPtr; no_fast_math : bool = false) : array<string> {
    
    
    
    var res : array<string>
    ast_gc_guard() {
        res <- opt_residuals(func, FLATTEN_BARRIERS, no_fast_math)
    }
    return <- res
}





class private FlatVerify : AstVisitor {
    sawBranch   : bool
    sawCall     : bool
    callName    : string
    def override preVisitExprIfThenElse(expr : ExprIfThenElse?) : void {
        sawBranch = true
    }
    def override preVisitExprCall(expr : ExprCall?) : void {
        if (expr.func != null && !expr.func.flags.builtIn && expr.func.body != null) {
            sawCall = true
            callName = "{expr.name}"
        }
    }
}

def private verify_flat(var twin : FunctionPtr) : string {
    var v = new FlatVerify()
    make_visitor(*v) $(adapter) {
        visit(twin.body, adapter)
    }
    var msg = ""
    if (v.sawBranch) {
        msg = "flatten: internal error - a branch (if/else) survived lowering in '{twin.name}'"
    } elif (v.sawCall) {
        msg = "flatten: internal error - user call '{v.callName}' survived lowering in '{twin.name}'"
    }
    unsafe {
        delete v
    }
    return msg
}





class private FoldResidualVisitor : AstVisitor {
    found : array<string>
    noFastMath : bool
    def override preVisitExprCall(expr : ExprCall?) : void {
        if (expr.func != null && expr.func.flags.builtIn && is_all_const(expr) && eval_to_const_supported(expr._type)) {
            found |> push("an unfolded all-const call '{expr.name}'")
        }
    }
    def override preVisitExprOp3(expr : ExprOp3?) : void {
        if (expr.subexpr is ExprConstBool) {
            found |> push("an unfolded const-condition select")
        }
    }
    def override preVisitExprOp2(var expr : ExprOp2?) : void {
        if (is_unfolded_identity_op2(expr)) {
            found |> push("an unfolded algebraic identity ('{expr.op}')")
        } elif (is_all_const(expr) && eval_to_const_supported(expr._type)) {
            found |> push("an unfolded all-const arithmetic ('{expr.op}')")
        } elif (has_scattered_consts(expr, noFastMath)) {
            found |> push("a scattered const chain ('{expr.op}') reassoc should gather")
        } elif (!noFastMath && is_unrcp_const_div(expr)) {
            found |> push("an un-rewritten const division ('x / C' should be 'x * (1/C)')")
        } elif (is_uncollapsed_splat_op2(expr)) {
            found |> push("an uncollapsed splat operand ('v {expr.op} floatN(s)' should use the scalar)")
        } elif (is_unkilled_ctor_zero_lane(expr, noFastMath)) {
            found |> push("an un-killed ctor lane under a zero const lane")
        }
    }
    def override preVisitExprOp1(expr : ExprOp1?) : void {
        if (expr.op == "!" && expr.subexpr is ExprConstBool) {
            found |> push("an unfolded constant '!'")
        } elif (expr.op == "!" && can_negate_bool(expr.subexpr, noFastMath)) {
            found |> push("an unfolded boolean inversion ('!' over a comparison / '!' / && / ||)")
        }
    }
    def override preVisitExprSwizzle(var expr : ExprSwizzle?) : void {
        if (is_unfolded_swizzle_lanes(expr)) {
            found |> push("an un-folded swizzle over decomposable lanes ('ctor(...).mask' should re-pack)")
        }
    }
}

def public flatten_fold_residuals(var func : FunctionPtr; no_fast_math : bool = false) : array<string> {
    
    
    
    var res : array<string>
    if (func == null || func.body == null) {
        return <- res
    }
    
    
    ast_gc_guard() {
        var v = new FoldResidualVisitor()
        v.noFastMath = no_fast_math
        make_visitor(*v) $(adapter) {
            visit(func.body, adapter)
        }
        res <- v.found
        unsafe {
            delete v
        }
        
        
        if (func.body is ExprBlock && has_fusable_select_chain(func.body as ExprBlock)) {
            res |> push("an un-fused same-condition select chain (N selects should be 1)")
        }
    }
    return <- res
}



[function_macro(name="flatten")]
class FlattenAnnotation : AstFunctionAnnotation {
    
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        let tn = twin_name(func)
        if (find_unique_function(compiling_module(), tn, true) == null) {
            var fn = clone_function(func)
            fn.name := tn
            fn.flags |= FunctionFlags.generated | FunctionFlags.exports
            while (fn.annotations |> length != 0) {
                fn.annotations |> erase(0)
            }
            compiling_module() |> add_function(fn)
        }
        return true
    }
    def override patch(var func : FunctionPtr; var group : ModuleGroup;
                       args, progArgs : AnnotationArgumentList; var errors : das_string;
                       var astChanged : bool&) : bool {
        
        if (is_in_lint_check()) return true
        let ph = get_flatten_phase(func)
        if (ph == PHASE_DONE) return true
        var twin = find_unique_function(compiling_module(), twin_name(func), true)
        if (twin == null) {
            errors := "flatten: twin {twin_name(func)} was not declared"
            return false
        }
        if (ph != PHASE_LOWERED && ph != PHASE_FOLDED && ph != PHASE_OPTIMIZED && ph != PHASE_FUSED) {
            
            var ctx = flatten_function(twin, STD_WHITELIST, get_flatten_max_unroll(func))
            if (!ctx.ok) {
                errors := ctx.err
                return false
            }
            set_flatten_phase(func, PHASE_LOWERED)
            astChanged = true
            return true
        }
        if (ph == PHASE_LOWERED || ph == PHASE_FOLDED) {
            
            let folded = flatten_fold(twin, flatten_no_fast_math(), flatten_expand_lerp())
            set_flatten_phase(func, PHASE_FOLDED)
            if (folded) {
                astChanged = true
                return true
            }
            
            set_flatten_phase(func, PHASE_OPTIMIZED)
            if (flatten_optimize(twin, FLATTEN_BARRIERS, flatten_no_fast_math(), flatten_log_cse())) {
                astChanged = true
                return true
            }
        }
        if (get_flatten_phase(func) == PHASE_OPTIMIZED || get_flatten_phase(func) == PHASE_FUSED) {
            
            set_flatten_phase(func, PHASE_FUSED)
            if (flatten_fuse(twin, flatten_no_fast_math(), flatten_hadd_pack_pairs() ? 2 : 3)) {
                astChanged = true
                return true
            }
        }
        
        let problem = verify_flat(twin)
        if (problem != "") {
            errors := problem
            return false
        }
        set_flatten_phase(func, PHASE_DONE)
        return true
    }
}
