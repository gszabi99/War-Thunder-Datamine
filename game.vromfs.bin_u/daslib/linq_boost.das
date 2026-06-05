options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module linq_boost shared public








require daslib/linq public

require daslib/ast_boost
require daslib/templates_boost
require daslib/macro_boost

def private clone_iterator_type(it : TypeDeclPtr) : TypeDeclPtr {
    var res = clone_type(it.firstType)
    res.flags &= ~TypeDeclFlags.ref
    res.flags |= TypeDeclFlags.constant
    return <- res
}

class private AstCallMacro_LinqPred2 : AstCallMacro {
    
    predName = "where_"
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        
        
        macro_verify(call.arguments |> length == 2, prog, call.at, "expecting {predName}(iterator, predicate)")
        assume arg0 = call.arguments[0]
        assume arg0type = call.arguments[0]._type
        macro_verify(arg0type != null, prog, call.at, "input argument is not inferred yet")
        macro_verify(arg0type.isIterator || arg0type.isGoodArrayType, prog, call.at, "expecting iterator or array")
        macro_verify(!arg0type.firstType.isAutoOrAlias, prog, call.at, "iterable type cannot be auto or alias")
        
        var iterType = clone_iterator_type(arg0type)
        var res = qmacro($c(predName)($e(arg0), $(_ : $t(iterType)) => $e(call.arguments[1])))
        
        
        (((res as ExprCall).arguments[1] as ExprMakeBlock)._block as ExprBlock).arguments[0].flags |= VariableFlags.can_shadow
        res.force_at(call.at)
        return res
    }
}

[call_macro(name="_where")]
class private LinqWhere : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "where_"
}

[call_macro(name="_where_to_array")]
class private LinqWhereToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "where_to_array"
}

[call_macro(name="_select")]
class private LinqSelect : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "select"
}

[call_macro(name="_select_to_array")]
class private LinqSelectToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "select_to_array"
}

[call_macro(name="_min_by")]
class private LinqMinBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "min_by"
}

[call_macro(name="_max_by")]
class private LinqMaxBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "max_by"
}

[call_macro(name="_min_max_by")]
class private LinqMinMaxBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "min_max_by"
}

[call_macro(name="_min_max_average_by")]
class private LinqMinMaxAverageBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "min_max_average_by"
}

[call_macro(name="_skip_while")]
class private LinqSkipWhile : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "skip_while"
}

[call_macro(name="_take_while")]
class private LinqTakeWhile : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "take_while"
}

[call_macro(name="_all")]
class private LinqAll : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "all"
}

[call_macro(name="_any")]
class private LinqAny : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "any"
}

[call_macro(name="_none")]
class private LinqNone : AstCallMacro_LinqPred2 {
    
    
    
    
    
    
    
    
    
    
    override predName = "none"
}

[call_macro(name="_count")]
class private LinqCount : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "count"
}

[call_macro(name="_unique_by")]
class private LinqUnique : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "unique_by"
}

[call_macro(name="_unique_by_to_array")]
class private LinqUniqueToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "unique_by_to_array"
}

[call_macro(name="_distinct_by")]
class private LinqDistinctBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "distinct_by"
}

[call_macro(name="_distinct_by_to_array")]
class private LinqDistinctByToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "distinct_by_to_array"
}

[call_macro(name="_order_by")]
class private LinqOrderBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "order_by"
}

[call_macro(name="_order_by_to_array")]
class private LinqOrderByToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "order_by_to_array"
}

[call_macro(name="_order_by_descending")]
class private LinqOrderByDescending : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "order_by_descending"
}

[call_macro(name="_order_by_descending_to_array")]
class private LinqOrderByDescendingToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "order_by_descending_to_array"
}

class private AstCallMacro_LinqPredII2 : AstCallMacro {
    
    predName = "sequence_equal_by"
    
    
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        
        
        macro_verify(call.arguments |> length == 3, prog, call.at, "expecting {predName}(iterator or array, iterator or array, predicate)")
        macro_verify(call.arguments[0]._type != null, prog, call.at, "expecting iterator or array")
        macro_verify(call.arguments[0]._type.isIterator || call.arguments[0]._type.isGoodArrayType, prog, call.at, "expecting iterator or array")
        macro_verify(call.arguments[1]._type != null, prog, call.at, "expecting iterator or array")
        macro_verify(call.arguments[1]._type.isIterator || call.arguments[1]._type.isGoodArrayType, prog, call.at, "expecting iterator or array")
        macro_verify(!call.arguments[0]._type.firstType.isAutoOrAlias, prog, call.at, "iterator or array type cannot be auto or alias")
        
        var iterType = clone_iterator_type(call.arguments[0]._type)
        var res = qmacro($c(predName)($e(call.arguments[0]), $e(call.arguments[1]), $(_ : $t(iterType)) => $e(call.arguments[2])))
        
        (((res as ExprCall).arguments[2] as ExprMakeBlock)._block as ExprBlock).arguments[0].flags |= VariableFlags.can_shadow
        res.force_at(call.at)
        return res
    }
}

[call_macro(name="_sequence_equal_by")]
class private LinqPred3 : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "sequence_equal_by"
}

[call_macro(name="_except_by")]
class private LinqExceptBy : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "except_by"
}

[call_macro(name="_except_by_to_array")]
class private LinqExceptByToArray : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "except_by_to_array"
}

[call_macro(name="_intersect_by")]
class private LinqIntersectBy : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "intersect_by"
}

[call_macro(name="_intersect_by_to_array")]
class private LinqIntersectByToArray : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "intersect_by_to_array"
}

[call_macro(name="_union_by")]
class private LinqUnionBy : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "union_by"
}

class private AstCallMacro_LinqContainsFlip : AstCallMacro {
    
    
    
    
    
    
    
    
    
    
    
    
    opName = "_in"
    negated = false
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        macro_verify(call.arguments |> length == 2, prog, call.at, "expecting {opName}(element, subquery)")
        assume subquery = call.arguments[1]
        assume subqueryType = subquery._type
        macro_verify(subqueryType != null, prog, call.at, "subquery argument is not inferred yet")
        macro_verify(subqueryType.isIterator || subqueryType.isGoodArrayType, prog, call.at, "expecting iterator or array as the subquery argument")
        macro_verify(!subqueryType.firstType.isAutoOrAlias, prog, call.at, "subquery element type cannot be auto or alias")
        var res : Expression?
        if (negated) {
            res = qmacro(!contains($e(subquery), $e(call.arguments[0])))
        } else {
            res = qmacro(contains($e(subquery), $e(call.arguments[0])))
        }
        res.force_at(call.at)
        return res
    }
}

[call_macro(name="_in")]
class private LinqIn : AstCallMacro_LinqContainsFlip {
    
    
    
    
    
    override opName = "_in"
    override negated = false
}

[call_macro(name="_not_in")]
class private LinqNotIn : AstCallMacro_LinqContainsFlip {
    
    
    
    
    
    
    
    
    override opName = "_not_in"
    override negated = true
}

struct private EquiJoinParts {
    
    ok : bool
    keya_body : Expression?
    keyb_body : Expression?
    larg_name : string
    rarg_name : string
}

def private parse_equi_join_on(var on_pred : Expression?; prog : ProgramPtr; at : LineInfo) : EquiJoinParts {
    
    
    
    
    
    
    
    
    
    
    var parts : EquiJoinParts
    if (on_pred == null || !(on_pred is ExprMakeBlock)) {
        macro_error(prog, at, "equi-join `on` predicate must be a 2-arg lambda `(l, r) => l.X == r.Y`")
        return parts
    }
    var mkblk = on_pred as ExprMakeBlock
    if (mkblk._block == null || !(mkblk._block is ExprBlock)) {
        macro_error(prog, on_pred.at, "equi-join `on` predicate must be a 2-arg lambda `(l, r) => l.X == r.Y`")
        return parts
    }
    var blk = mkblk._block as ExprBlock
    if (blk.arguments |> length != 2 || blk.list |> length != 1 || !(blk.list[0] is ExprReturn)) {
        macro_error(prog, on_pred.at, "equi-join `on` predicate must be a 2-arg lambda with a single `return l.X == r.Y`")
        return parts
    }
    var ret = blk.list[0] as ExprReturn
    if (ret.subexpr == null || !(ret.subexpr is ExprOp2)) {
        macro_error(prog, on_pred.at, "equi-join `on` predicate body must be a single `==` comparison `l.X == r.Y`")
        return parts
    }
    var op2 = ret.subexpr as ExprOp2
    if (op2.op != "==") {
        macro_error(prog, on_pred.at, "equi-join `on` predicate must use `==` — theta joins and `&&`-chained multi-key equality are not supported; use raw SQL instead")
        return parts
    }
    parts.ok = true
    parts.keya_body = op2.left
    parts.keyb_body = op2.right
    parts.larg_name = string(blk.arguments[0].name)
    parts.rarg_name = string(blk.arguments[1].name)
    return parts
}

def private rename_var_in_expr(var src : Expression?; from_name, to_name : string) : Expression? {
    
    
    var res = clone_expression(src)
    var rules : Template
    rules |> renameVariable(from_name, to_name)
    apply_template(rules, res.at, res)
    return res
}

class private AstCallMacro_LinqJoinBase : AstCallMacro {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    fnName = "join"
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        macro_verify(call.arguments |> length == 4, prog, call.at, "expecting {fnName}(srca, srcb, on, into) — 4 arguments")
        assume srcaType = call.arguments[0]._type
        assume srcbType = call.arguments[1]._type
        macro_verify(srcaType != null, prog, call.at, "first argument is not inferred yet")
        macro_verify(srcbType != null, prog, call.at, "second argument is not inferred yet")
        macro_verify(srcaType.isIterator || srcaType.isGoodArrayType, prog, call.at, "first argument must be an iterator or array")
        macro_verify(srcbType.isIterator || srcbType.isGoodArrayType, prog, call.at, "second argument must be an iterator or array")
        macro_verify(!srcaType.firstType.isAutoOrAlias, prog, call.at, "first argument element type cannot be auto or alias")
        macro_verify(!srcbType.firstType.isAutoOrAlias, prog, call.at, "second argument element type cannot be auto or alias")
        var parts = parse_equi_join_on(call.arguments[2], prog, call.at)
        if (!parts.ok) {
            return null
        }
        var iterTypeA = clone_iterator_type(srcaType)
        var iterTypeB = clone_iterator_type(srcbType)
        let la_fresh = "__la__"
        let lb_fresh = "__lb__"
        var keya_body = rename_var_in_expr(parts.keya_body, parts.larg_name, la_fresh)
        var keyb_body = rename_var_in_expr(parts.keyb_body, parts.rarg_name, lb_fresh)
        var res = qmacro($c(fnName)(
            $e(call.arguments[0]),
            $e(call.arguments[1]),
            $($i(la_fresh) : $t(iterTypeA)) => $e(keya_body),
            $($i(lb_fresh) : $t(iterTypeB)) => $e(keyb_body),
            $e(call.arguments[3])
        ))
        res.force_at(call.at)
        return res
    }
}

[call_macro(name="_join")]
class private LinqJoin : AstCallMacro_LinqJoinBase {
    
    
    
    
    
    
    
    
    override fnName = "join"
}

[call_macro(name="_left_join")]
class private LinqLeftJoin : AstCallMacro_LinqJoinBase {
    
    
    
    
    
    
    
    
    
    
    override fnName = "left_join"
}

[call_macro(name="_group_by_lazy")]
class private LinqGroupByLazy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    
    
    
    
    override predName = "group_by_lazy"
}

[call_macro(name="_group_by")]
class private LinqGroupBy : AstCallMacro_LinqPred2 {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    override predName = "group_by_lazy"
}

[call_macro(name="_group_by_to_array")]
class private LinqGroupByToArray : AstCallMacro_LinqPred2 {
    
    
    
    
    
    override predName = "group_by_lazy_to_array"
}

[call_macro(name="_group_by_lazy_to_array")]
class private LinqGroupByLazyToArray : AstCallMacro_LinqPred2 {
    
    
    
    override predName = "group_by_lazy_to_array"
}

[call_macro(name="_having")]
class private LinqHaving : AstCallMacro_LinqPred2 {
    
    
    
    
    
    
    
    
    
    
    
    
    override predName = "having_"
}

[call_macro(name="_having_to_array")]
class private LinqHavingToArray : AstCallMacro_LinqPred2 {
    
    
    override predName = "having_to_array"
}

[call_macro(name="_union_by_to_array")]
class private LinqUnionByToArray : AstCallMacro_LinqPredII2 {
    
    
    
    
    
    override predName = "union_by_to_array"
}

def private is_call_or_generic(var expr : Expression?, name, moduleName : string) : ExprCall? {
    if (expr is ExprCall) {
        var call = expr as ExprCall
        if (call.func.name == name && call.func._module.name == moduleName) {
            return call
        } elif (call.func.fromGeneric != null && call.func.fromGeneric.name == name && call.func.fromGeneric._module.name == moduleName) {
            return call
        }
    }
    return null
}

def private is_call_or_generic_arg0(var expr : Expression?, name, moduleName : string) : Expression? {
    
    var call = expr.is_call_or_generic(name, moduleName)
    return call.arguments[0] if (call != null)
    return null
}

def private fold_linq_cond(var expr : Expression?; argName : string) : Expression? {
    
    
    
    if (expr is ExprMakeBlock) {
        var mblk = expr as ExprMakeBlock
        var blk = mblk._block as ExprBlock
        if (blk.arguments |> length == 1 && blk.list |> length == 1 && blk.list[0] is ExprReturn) {
            var ret = blk.list[0] as ExprReturn
            if (ret.subexpr != null) {
                var res = clone_expression(ret.subexpr)
                var rules : Template
                rules |> renameVariable(string(blk.arguments[0].name), argName)
                apply_template(rules, res.at, res)
                return res
            }
        }
    }
    return qmacro(invoke($e(expr), $i(argName)))
}

struct private LinqCall {
    
    name : string
    moduleName : string = "linq"
    skip : bool = false             
    inplace : bool = false          
    recursive : array<int>          
}

var private linqCalls = {

    "where_" => LinqCall(name = "where_"),
    "where_to_array" => LinqCall(name = "where_"),

    "select" => LinqCall(name = "select"),
    "select_to_array" => LinqCall(name = "select"),
    "select_many" => LinqCall(name = "select_many"),
    "select_many_to_array" => LinqCall(name = "select_many"),
    "zip" => LinqCall(name = "zip", recursive = [1, 2]),
    "zip_to_array" => LinqCall(name = "zip", recursive = [1, 2]),

    "reverse" => LinqCall(name = "reverse", inplace = true),
    "reverse_to_array" => LinqCall(name = "reverse", inplace = true),
    "order" => LinqCall(name = "order", inplace = true),
    "order_to_array" => LinqCall(name = "order", inplace = true),
    "order_descending" => LinqCall(name = "order_descending", inplace = true),
    "order_descending_to_array" => LinqCall(name = "order_descending", inplace = true),
    "order_by" => LinqCall(name = "order_by", inplace = true),
    "order_by_to_array" => LinqCall(name = "order_by", inplace = true),
    "order_by_descending" => LinqCall(name = "order_by_descending", inplace = true),
    "order_by_descending_to_array" => LinqCall(name = "order_by_descending", inplace = true),

    "count" => LinqCall(name = "count"),
    "long_count" => LinqCall(name = "long_count"),
    "average" => LinqCall(name = "average"),
    "min" => LinqCall(name = "min"),
    "min_by" => LinqCall(name = "min_by"),
    "max" => LinqCall(name = "max"),
    "max_by" => LinqCall(name = "max_by"),
    "min_max" => LinqCall(name = "min_max"),
    "min_max_by" => LinqCall(name = "min_max_by"),
    "min_max_average" => LinqCall(name = "min_max_average"),
    "min_max_average_by" => LinqCall(name = "min_max_average_by"),
    "aggregate" => LinqCall(name = "aggregate"),
    "sum" => LinqCall(name = "sum"),

    "skip" => LinqCall(name = "skip", inplace = true),
    "skip_to_array" => LinqCall(name = "skip", inplace = true),
    "skip_while" => LinqCall(name = "skip_while"),
    "skip_while_to_array" => LinqCall(name = "skip_while"),
    "take" => LinqCall(name = "take", inplace = true),
    "take_to_array" => LinqCall(name = "take", inplace = true),
    "take_while" => LinqCall(name = "take_while"),
    "take_while_to_array" => LinqCall(name = "take_while"),
    "skip_last" => LinqCall(name = "skip_last", inplace = true),
    "skip_last_to_array" => LinqCall(name = "skip_last", inplace = true),
    "take_last" => LinqCall(name = "take_last", inplace = true),
    "take_last_to_array" => LinqCall(name = "take_last", inplace = true),
    "chunk" => LinqCall(name = "chunk"),
    "chunk_to_array" => LinqCall(name = "chunk"),

    "concat" => LinqCall(name = "concat", recursive = [1], inplace = true),
    "concat_to_array" => LinqCall(name = "concat", recursive = [1], inplace = true),
    "prepend" => LinqCall(name = "prepend", inplace = true),
    "prepend_to_array" => LinqCall(name = "prepend", inplace = true),
    "append" => LinqCall(name = "append", inplace = true),
    "append_to_array" => LinqCall(name = "append", inplace = true),

    "distinct" => LinqCall(name = "distinct", inplace = true),
    "distinct_to_array" => LinqCall(name = "distinct", inplace = true),
    "distinct_by" => LinqCall(name = "distinct_by", inplace = true),
    "distinct_by_to_array" => LinqCall(name = "distinct_by", inplace = true),
    "union" => LinqCall(name = "union", recursive = [1]),
    "union_to_array" => LinqCall(name = "union", recursive = [1]),
    "union_by" => LinqCall(name = "union_by", recursive = [1]),
    "union_by_to_array" => LinqCall(name = "union_by", recursive = [1]),
    "except" => LinqCall(name = "except", recursive = [1]),
    "except_to_array" => LinqCall(name = "except", recursive = [1]),
    "except_by" => LinqCall(name = "except_by", recursive = [1]),
    "except_by_to_array" => LinqCall(name = "except_by", recursive = [1]),
    "intersect" => LinqCall(name = "intersect", recursive = [1]),
    "intersect_to_array" => LinqCall(name = "intersect", recursive = [1]),
    "intersect_by" => LinqCall(name = "intersect_by", recursive = [1]),
    "intersect_by_to_array" => LinqCall(name = "intersect_by", recursive = [1]),
    "unique" => LinqCall(name = "unique", inplace = true),
    "unique_to_array" => LinqCall(name = "unique", inplace = true),
    "unique_by" => LinqCall(name = "unique_by", inplace = true),
    "unique_by_to_array" => LinqCall(name = "unique_by", inplace = true),

    "element_at" => LinqCall(name = "element_at"),
    "element_at_or_default" => LinqCall(name = "element_at_or_default"),
    "first" => LinqCall(name = "first"),
    "first_or_default" => LinqCall(name = "first_or_default"),
    "last" => LinqCall(name = "last"),
    "last_or_default" => LinqCall(name = "last_or_default"),
    "single" => LinqCall(name = "single"),
    "single_or_default" => LinqCall(name = "single_or_default"),

    "join" => LinqCall(name = "join", recursive = [1]),
    "join_to_array" => LinqCall(name = "join", recursive = [1]),
    "left_join" => LinqCall(name = "left_join", recursive = [1]),
    "left_join_to_array" => LinqCall(name = "left_join", recursive = [1]),
    "group_join" => LinqCall(name = "group_join", recursive = [1]),
    "group_join_to_array" => LinqCall(name = "group_join", recursive = [1]),
    "group_by" => LinqCall(name = "group_by"),
    "group_by_to_array" => LinqCall(name = "group_by"),
    "group_by_lazy" => LinqCall(name = "group_by_lazy"),
    "group_by_lazy_to_array" => LinqCall(name = "group_by_lazy"),
    "having_" => LinqCall(name = "having_"),
    "having_to_array" => LinqCall(name = "having_"),

    "any" => LinqCall(name = "any"),
    "all" => LinqCall(name = "all"),
    "contains" => LinqCall(name = "contains"),

    "to_table" => LinqCall(name = "to_table"),
    "to_array" => LinqCall(name = "to_array", moduleName = "builtin", skip = true),
    "to_sequence" => LinqCall(name = "to_sequence", skip = true),
}

[macro_function]
def private is_linq_call(var expr : Expression?) : bool {
    if (expr is ExprCall) {
        var call = expr as ExprCall
        var funcName = string(call.func.name)
        while (call.func.fromGeneric != null) {
            call.func = call.func.fromGeneric
            funcName = string(call.func.name)
        }
        if (linqCalls.key_exists(funcName)) {
            let linqCall & = unsafe(linqCalls?[funcName] ?? default<LinqCall>)
            if (linqCall.moduleName == call.func._module.name) {
                return true
            }
        }
    }
    return false
}

[macro_function]
def private flatten_linq(var expr : Expression?)  {
    var top = expr
    var calls : array<tuple<ExprCall?; LinqCall?>>
    while (top != null) {
        if (top is ExprCall) {
            var topCall = top as ExprCall
            var topFunc = topCall.func
            while (topFunc.fromGeneric != null) {
                topFunc = topFunc.fromGeneric
            }
            let funcName = string(topFunc.name)
            if (!linqCalls.key_exists(funcName)) {
                break
            }
            var linqCall & = unsafe(linqCalls?[funcName] ?? default<LinqCall>)
            if (linqCall.moduleName != topFunc._module.name) {
                break
            }
            if (!linqCall.skip) {
                calls.push((topCall, unsafe(addr(linqCall))))
            }
            top = topCall.arguments[0]
        } else {
            break
        }
    }
    calls.reverse_inplace()
    
    return <- (top, calls)
}

struct private FoldSequence {
    
    calls : array<string>
    folder : function<(
        argIndex : int;
        var topValue : Expression?;
        var blk : ExprBlock?;
        var calls : array<tuple<ExprCall?; LinqCall?>>
    ) : Expression?>
}

var private g_foldSeq = [               

    FoldSequence(
        calls = ["order", "distinct" ],
        folder = @@fold_order_distinct
    ),
    FoldSequence(
        calls = ["distinct", "order" ],
        folder = @@fold_order_distinct
    ),

    FoldSequence(
        calls = ["where_", "select" ],
        folder = @@fold_where_select
    ),
    FoldSequence(
        calls = ["select", "where_"],
        folder = @@fold_select_where
    ),
    FoldSequence(
        calls = ["where_"],
        folder = @@fold_where
    ),
    FoldSequence(
        calls = ["select"],
        folder = @@fold_select
    ),
]

[macro_function]
def private append_comprehension(argIndex : int; var topValue : Expression?; var comprehension : Expression?; var blk : ExprBlock?; at : LineInfo) : Expression? {
    comprehension.force_at(at)
    comprehension.force_generated(true)
    let newArgName = "pass_{argIndex}"
    blk.list |> emplace_new <| qmacro_expr() {
        var $i(newArgName) <- $e(comprehension)
    }
    (blk.list.back() as ExprLet).variables[0].flags |= VariableFlags.can_shadow
    if (argIndex != 0) {
        blk.list |> emplace_new <| qmacro_expr() {
            delete $e(topValue)
        }
    }
    return qmacro($i(newArgName))
}

[macro_function]
def private fold_order_distinct(argIndex : int; var topValue : Expression?; var blk : ExprBlock?; var calls : array<tuple<ExprCall?; LinqCall?>>) : Expression? {
    
    if (argIndex == 0) {
        var comprehension = qmacro(order_unique_folded($e(topValue)))
        return append_comprehension(argIndex, topValue, comprehension, blk, calls[0]._0.at)
    } else {
        blk.list |> emplace_new <| qmacro(order_unique_folded_inplace($e(topValue)))
        return clone_expression(topValue)
    }
}

[macro_function]
def private fold_where_select(argIndex : int; var topValue : Expression?; var blk : ExprBlock?; var calls : array<tuple<ExprCall?; LinqCall?>>) : Expression? {
    
    var eWhere = calls[0]._0
    var eSelect = calls[1]._0
    var iterType = clone_type(eWhere.arguments[0]._type.firstType)
    var whereCond = fold_linq_cond(eWhere.arguments[1], "it")
    var selectExpr : Expression?
    if (eSelect != null) {
        selectExpr = fold_linq_cond(eSelect.arguments[1], "it")
    } else {
        selectExpr = new ExprVar(name := "it", at = topValue.at, _type := iterType)
    }
    var comprehension = qmacro([for (it in $e(topValue)); $e(selectExpr); where $e(whereCond)])
    return append_comprehension(argIndex, topValue, comprehension, blk, calls[0]._0.at)
}

[macro_function]
def private fold_where(argIndex : int; var topValue : Expression?; var blk : ExprBlock?; var calls : array<tuple<ExprCall?; LinqCall?>>) : Expression? {
    
    var eWhere = calls[0]._0
    var whereCond = fold_linq_cond(eWhere.arguments[1], "it")
    var comprehension = qmacro([for (it in $e(topValue)); it; where $e(whereCond)])
    return append_comprehension(argIndex, topValue, comprehension, blk, calls[0]._0.at)
}

[macro_function]
def private fold_select(argIndex : int; var topValue : Expression?; var blk : ExprBlock?; var calls : array<tuple<ExprCall?; LinqCall?>>) : Expression? {
    
    var eSelect = calls[0]._0
    var selectExpr = fold_linq_cond(eSelect.arguments[1], "it")
    var comprehension = qmacro([for (it in $e(topValue)); $e(selectExpr)])
    return append_comprehension(argIndex, topValue, comprehension, blk, calls[0]._0.at)
}

[macro_function]
def private fold_select_where(argIndex : int; var topValue : Expression?; var blk : ExprBlock?; var calls : array<tuple<ExprCall?; LinqCall?>>) : Expression? {
    
    
    var eWhere = calls[1]._0
    var eSelect = calls[0]._0
    var iterType = clone_type(eWhere.arguments[0]._type.firstType)
    var whereCond : Expression?
    let srcName = "`source`{argIndex}`{eSelect.at.line}`{eSelect.at.column}"
    let valName = "`value`{argIndex}`{eSelect.at.line}`{eSelect.at.column}"
    let itName = "`it`{argIndex}`{eSelect.at.line}`{eSelect.at.column}"
    let arrName = "`arr`{argIndex}`{eSelect.at.line}`{eSelect.at.column}"
    whereCond = fold_linq_cond(eWhere.arguments[1], valName)
    var selectExpr : Expression?
    if (eSelect != null) {
        selectExpr = fold_linq_cond(eSelect.arguments[1], itName)
    } else {
        selectExpr = new ExprVar(name := itName, at = topValue.at, _type := iterType)
    }
    var comprehension = qmacro(invoke($($i(srcName) : typedecl($e(topValue)) - const) {
            var $i(arrName) : array<$t(iterType)>
            for ($i(itName) in $i(srcName)) {
                static_if (typeinfo is_workhorse($e(selectExpr))) {
                    var $i(valName) = $e(selectExpr)
                    if ($e(whereCond)) {
                        $i(arrName).emplace($i(valName))
                    }
                } else {
                    var $i(valName) <- $e(selectExpr)
                    if ($e(whereCond)) {
                        $i(arrName).emplace($i(valName))
                    }
                }
            }
            return <- $i(arrName)
        }, $e(topValue)))
    return append_comprehension(argIndex, topValue, comprehension, blk, calls[0]._0.at)
}

[macro_function]
def private fold_linq_default(var expr : Expression?) : Expression? {
    
    
    
    
    
    
    
    
    
    
    
    
    var blk = new ExprBlock(at = expr.at)
    var (top, calls) = flatten_linq(expr)
    if (calls |> length == 0) {
        return null
    }
    var topExpr = clone_expression(top)
    var topExprType = clone_type(top._type)
    var topValue = qmacro(source)
    var argIndex = 0
    let argMax = length(calls)
    while (argIndex < argMax) {
        {
            var cll & = unsafe(calls[argIndex])
            let newArgName = "pass_{argIndex}"
            var callName = cll._1.name
            var inplace = false
            
            var found : FoldSequence?
            for (fs in g_foldSeq) {
                if (fs.calls |> length + argIndex - 1 < argMax) {
                    var match = true
                    for (i in 0 .. fs.calls |> length) {
                        if (fs.calls[i] != unsafe(calls[argIndex + i]._1.name)) {
                            match = false
                            break
                        }
                    }
                    if (match) {
                        found = unsafe(addr(fs))
                        break
                    }
                }
            }
            if (found != null) {
                var sub = subarray(calls, argIndex .. argIndex + found.calls |> length)
                topValue = found.folder(argIndex, topValue, blk, sub)
                argIndex += found.calls |> length
            } else {
                if (cll._0._type.isIterator || cll._0._type.isGoodArrayType) {
                    if (argIndex == 0 && top._type.isIterator) {
                        callName = "{callName}_to_array"
                    } elif (argIndex != 0 && cll._1.inplace) {
                        callName = "{callName}_inplace"
                        inplace = true
                    }
                }
                for (i in cll._1.recursive) {   
                    if (i >= 1 && i < cll._0.arguments |> length && is_linq_call(cll._0.arguments[i])) {
                        var argExpr = make_call(cll._0.at, "_fold")
                        (argExpr as ExprCallMacro).arguments |> emplace <| cll._0.arguments[i]
                        cll._0.arguments[i] = argExpr
                    }
                }
                var newCall = qmacro($c(callName)($e(topValue)))
                let numArgs = cll._0.arguments |> length
                for (i in 1..numArgs) {
                    (newCall as ExprCall).arguments |> emplace_new <| clone_expression(cll._0.arguments[i])
                }
                if (inplace) {
                    blk.list |> emplace(newCall)
                } else {
                    blk.list |> emplace_new <| qmacro_expr() {
                        var $i(newArgName) = $e(newCall)
                    }
                    (blk.list.back() as ExprLet).variables[0].flags |= VariableFlags.can_shadow
                    if (argIndex != 0) {
                        blk.list |> emplace_new <| qmacro_expr() {
                            delete $e(topValue)
                        }
                    }
                    topValue = qmacro($i(newArgName))
                }
                argIndex ++
            }
        }
    }
    if (expr._type.isIterator) {
        blk.list |> emplace_new <| qmacro_expr() {
            return <- $e(topValue).to_sequence_move()
        }
    } else {
        blk.list |> emplace_new <| qmacro_expr() {
            return <- $e(topValue)
        }
    }
    topExpr.genFlags |= ExprGenFlags.alwaysSafe
    var res = qmacro(invoke($(source : $t(topExprType)) { $e(blk); }, $e(topExpr)))
    (((res as ExprInvoke).arguments[0] as ExprMakeBlock)._block as ExprBlock).arguments[0].flags |= VariableFlags.can_shadow
    res.force_generated(true)
    return res
}

[call_macro(name="_fold")]
class private LinqFold : AstCallMacro {
    
    
    
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var call : ExprCallMacro?) : Expression? {
        
        macro_verify(call.arguments |> length == 1, prog, call.at, "expecting _fold(expression)")
        macro_verify(call.arguments[0]._type != null, prog, call.at, "expecting linq expression")
        var res : Expression? = fold_linq_default(call.arguments[0])
        if (res == null) {
            prog |> macro_error(call.at, "cannot fold LINQ expression\n{describe(call.arguments[0])}")
            return res
        }
        return res
    }
}

