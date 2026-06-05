options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options no_aot
options multiple_contexts
options strict_smart_pointers = true

module decs_boost shared private








require daslib/decs public
require daslib/ast_boost
require daslib/templates_boost
require daslib/strings_boost
require daslib/ast_block_to_loop
require daslib/defer
require daslib/decs_state
require daslib/macro_boost














[block_macro(name="REQUIRE")]
class DecsReq : AstBlockAnnotation {
    
}

[block_macro(name="REQUIRE_NOT")]
class DecsReqN : AstBlockAnnotation {
    
}

[structure_macro(name="decs_template")]
class DecsTemplate : AstStructureAnnotation {
    
    
    
    
    
    
    
    def override apply(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        if (length(st.fields) == 0) {
            errors := "expecting at least one field in the desc_template {st.name}"
            return false
        }
        let ppref = decs_prefix(args)
        let prefix = (ppref is yes) ? (ppref as yes) : "{st.name}_"
        var blkApply : array<ExpressionPtr>
        var blkErase : array<ExpressionPtr>
        for (fld in st.fields) {
            blkApply |> push(qmacro(decs::set(cmp, $v("{prefix}{fld.name}"), src.$f(fld.name))))
            blkErase |> push(qmacro(decs::remove(cmp, $v("{prefix}{fld.name}"))))
        }
        var fnApply = qmacro_function("apply_decs_template") $(var cmp : ComponentMap; var src : $t(st)) : void {
            $b(blkApply)
        }
        if (!(compiling_module() |> add_function(fnApply))) {
            panic("failed to add apply_decs_template, can't add function {fnApply.name}")
        }
        var fnErase = qmacro_function("remove_decs_template`{st.name}") $(var cmp : ComponentMap; var src : $t(st)) : void {
            $b(blkErase)
        }
        if (!(compiling_module() |> add_function(fnErase))) {
            panic("failed to add remove_decs_template, can't add function {fnErase.name}")
        }
        
        
        var blkArchSetup : array<ExpressionPtr>
        var blkArchWrite : array<ExpressionPtr>
        
        blkArchSetup |> push(qmacro(cache |> push(decs::find_component_index(arch, "eid"))))
        blkArchWrite |> push(qmacro(decs::set_direct_at(arch, cache[0], eidx, eid)))
        for (fld_idx, fld in iter_range(st.fields), st.fields) {
            let ci = fld_idx + 1
            blkArchSetup |> push(qmacro(cache |> push(decs::find_component_index(arch, $v("{prefix}{fld.name}")))))
            blkArchWrite |> push(qmacro(decs::set_direct_at(arch, cache[$v(ci)], eidx, src.$f(fld.name))))
        }
        var fnArch = qmacro_function("apply_decs_template_arch") $(var arch : Archetype; eidx : int; eid : EntityId; src : $t(st); var cache : array<int>) : void {
            pass
        }
        var blkA = unsafe(reinterpret<ExprBlock?> fnArch.body)
        blkA.list |> clear()
        blkA.list |> emplace_new <| qmacro_block() {
            if (length(cache) == 0) {
                $b(blkArchSetup)
            }
            $b(blkArchWrite)
        }
        if (!(compiling_module() |> add_function(fnArch))) {
            panic("failed to add apply_decs_template_arch, can't add function {fnArch.name}")
        }
        
        var fnBulk = qmacro_function("create_entities`{st.name}") $(count : int; user_blk : block<(eid : decs::EntityId; i : int; var entity : $t(st)) : void>) : void {
            pass
        }
        var blk = unsafe(reinterpret<ExprBlock?> fnBulk.body)
        blk.list |> clear()
        blk.list |> emplace_new <| qmacro_block() {
            var defval := default<$t(st)>
            var cmp : decs::ComponentMap
            apply_decs_template(cmp, defval)
            var cache : array<int>
            decs::create_entities_from_cmp(count, cmp) $(var arch : decs::Archetype; eidx : int; eid : decs::EntityId; i : int) {
                var entity := default<$t(st)>
                invoke(user_blk, eid, i, entity)
                apply_decs_template_arch(arch, eidx, eid, entity, cache)
            }
            delete cmp
        }
        if (!(compiling_module() |> add_function(fnBulk))) {
            panic("failed to add create_entities`{st.name}, can't add function {fnBulk.name}")
        }
        return true
    }
}

variant ItCheck {
    
    yes : string
    no  : bool
}

[macro_function]
def private decs_prefix(arg : AnnotationArgumentList) {
    let p = arg |> find_arg("prefix")
    if (p is tString) {
        return ItCheck(yes = p as tString)
    } elif (p is tBool) {
        return ItCheck(yes = "")
    } else {
        return ItCheck(no = true)
    }
}

[macro_function]
def private is_decs_template(v : VariablePtr) {
    if (v._type.baseType != Type.tStructure) {
        return ItCheck(no = true)
    }
    var p = v.annotation |> decs_prefix
    if (p is no) {
        for (ann in v._type.structType.annotations) {
            if (ann.annotation.name == "decs_template") {
                p = ann.arguments |> decs_prefix
                return p is yes ? p : ItCheck(yes = "{v._type.structType.name}_")
            }
        }
    }
    return p
}

[macro_function]
def build_req_from_args(qblk : ExprBlock?) : EcsRequest {
    var req : EcsRequest
    for (a in qblk.arguments) {
        if (a.init == null) {
            let detp = a |> is_decs_template
            if (detp is yes) {
                for (f in a._type.structType.fields) {
                    req.req |> push("{detp as yes}{f.name}")
                }
            } else {
                if (!(find_arg(a.annotation, "optional") ?as tBool ?? false)) {
                    req.req |> push(string(a.name))
                }
            }
        }
    }
    for (aa in qblk.annotations) {
        let isreq = aa.annotation.name == "REQUIRE"
        let isreqn = aa.annotation.name == "REQUIRE_NOT"
        if (isreq || isreqn) {
            for (ab in aa.arguments) {
                if (ab.basicType == Type.tBool && ab.bValue) {
                    (isreq ? req.req : req.reqn) |> push(string(ab.name))
                }
            }
        }
    }
    compile_request(req)
    return <- req
}

[macro_function]
def getter_name(a; const_parent : bool; can_be_optional : bool) {
    var getter = "get_ro"
    static_if (typeinfo stripped_typename(a) == "ast_core::FieldDeclaration") {
        if (a.init != null && can_be_optional) {
            getter = "get_default_ro"
        } elif (!const_parent) {
            getter = "get"
        }
    } else {
        if (find_arg(a.annotation, "optional") ?as tBool ?? false) {
            if (a.init != null) {
                macro_error(compiling_program(), a.at, "optional argument {a.name} can't have a default value")
                return ""
            } elif (!a._type.isPointer) {
                macro_error(compiling_program(), a.at, "optional argument {a.name} must be a pointer")
                return ""
            }
            getter = "get_optional"
        } elif (a.init != null && can_be_optional) {
            if (a._type.flags.ref || !a._type.flags.constant) {
                macro_error(compiling_program(), a.at, "argument {a.name} has default value, it can't be & or var")
                return ""
            }
            getter = "get_default_ro"
        } elif (a._type.isRef && !a._type.isRefType) {
            if (a._type.flags.constant) {
                macro_error(compiling_program(), a.at, "argument {a.name} is both & and constant")
                return ""
            }
            getter = "get"
        } elif (a._type.isRefType && !a._type.flags.constant) {
            getter = "get"
        }
    }
    return getter
}

[macro_function]
def private append_iterator(arch_name : string; var qloop : ExprFor?; a; prefix, suffix : string; const_parent : bool = false; can_be_optional : bool = true) {
    let qli = length(qloop.iterators)
    qloop.iterators |> resize(qli + 1)
    qloop.iterators[qli] := "{prefix}{a.name}{suffix}"
    qloop.iteratorsAka |> resize(qli + 1)
    if (typeinfo has_field<_aka>(a)) {
        qloop.iteratorsAka[qli] := a._aka
    } else {
        qloop.iteratorsAka[qli] := ""
    }
    qloop.iteratorsAt |> push(a.at)
    qloop.iteratorsTags |> resize(qli + 1)
    let getter = getter_name(a, const_parent, can_be_optional)
    if (empty(getter)) {
        return false
    }
    if (getter == "get_default_ro") {
        qloop.sources |> emplace_new <| qmacro($c(getter)($i(arch_name), $v("{prefix}{a.name}"), $e(a.init)))
    } else {
        var ftype = clone_type(a._type)
        ftype.flags &= ~TypeDeclFlags.constant
        ftype.flags &= ~TypeDeclFlags.ref
        var it = qmacro($c(getter)($i(arch_name), $v("{prefix}{a.name}"), unsafe(type<$t(ftype)>)))
        force_generated(it, true)
        qloop.sources |> emplace <| it
    }
    return true
}

[macro_function]
def private append_index_lookup(arch_name : string; var qblock : ExprBlock?; a; prefix, suffix : string; const_parent : bool = false; can_be_optional : bool = true) {
    let getter = getter_name(a, const_parent, can_be_optional)
    if (empty(getter)) {
        return false
    }
    var iget : ExpressionPtr
    if (getter == "get_default_ro") {
        iget = clone_expression(a.init)
    } else {
        var ftype = clone_type(a._type)
        ftype.flags &= ~TypeDeclFlags.constant
        ftype.flags &= ~TypeDeclFlags.ref
        var getFn = qmacro($c(getter)($i(arch_name), $v("{prefix}{a.name}"), unsafe(type<$t(ftype)>)))
        getFn.genFlags |= ExprGenFlags.alwaysSafe
        iget = qmacro($e(getFn)[entity_index])
        force_generated(iget, true)
    }
    var vlet = new ExprLet(at = a.at, atInit = a.at)
    vlet.genFlags |= ExprGenFlags.alwaysSafe
    var vtype = clone_type(a._type)
    if (getter == "get_default_ro") {
        vtype.flags |= TypeDeclFlags.constant
    } elif (getter == "get_ro") {
        vtype.flags |= TypeDeclFlags.constant
        
        vtype.flags |= TypeDeclFlags.ref
    } else {
        
        vtype.flags |= TypeDeclFlags.ref
    }
        
        
        
    vlet.variables |> emplace_new() <| new Variable(at = a.at,
        name := "{prefix}{a.name}{suffix}",
        _type <- vtype,
        init <- iget,
        flags = VariableFlags.can_shadow | VariableFlags.generated
        )
    qblock.list |> emplace(vlet)
    return true
}

enum private DecsQueryType {
    
    query
    eid_query
    find_query
}

[call_macro(name="query")]
class DecsQueryMacro : AstCallMacro {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    def override preVisit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : void {
        let totalArgs = length(expr.arguments)
        if (totalArgs != 1 && totalArgs != 2) {
            return
        }
        let block_arg_index = totalArgs - 1
        if (!(expr.arguments[block_arg_index] is ExprMakeBlock)) {
            return
        }
        var mblk = expr.arguments[block_arg_index] as ExprMakeBlock
        var qblk = mblk._block as ExprBlock
        for (arg in qblk.arguments) {
            if (arg._type != null) {
                if (!arg._type.flags.constant) {
                    arg._type.flags |= TypeDeclFlags.ref
                }
            }
        }
    }
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        let totalArgs = length(expr.arguments)
        macro_verify(totalArgs == 1 || totalArgs == 2, prog, expr.at, "expecting query($(block_with_arguments)) or query(eid,$(block_with_arguments))")
        let qt = totalArgs == 2 ? DecsQueryType.eid_query : DecsQueryType.query
        let block_arg_index = totalArgs - 1
        return <- self->implement(expr, block_arg_index, qt)
    }
    def implement(var expr : ExprCallMacro?; block_arg_index : int; qt : DecsQueryType) : ExpressionPtr {
        for (arg in expr.arguments) {
            macro_verify(!arg._type.isAutoOrAlias, compiling_program(), expr.at, "argument types are not fully inferred")
        }
        macro_verify(expr.arguments[block_arg_index] is ExprMakeBlock, compiling_program(), expr.at, "expecting $(block_with_arguments)")
        let mblk = expr.arguments[block_arg_index] as ExprMakeBlock
        let qblk = mblk._block as ExprBlock
        macro_verify(length(qblk.arguments) != 0, compiling_program(), expr.at, "expecting query($(block_with_arguments)), arguments are missing")
        let prefix = "__{expr.at.line}_desc"
        let arch_name = "{prefix}_arch"
        var req <- build_req_from_args(qblk)
        req.at = EcsRequestPos(expr.at)
        let vreq = verify_request(req)
        macro_verify(vreq.ok, compiling_program(), expr.at, "incorrect query, {vreq.error}")
        
        var erq_fun = qmacro() @@ {
            return <- $v(req)
        }
        var kaboom : array<tuple<string; string; string>>
        var qtop : ExpressionPtr
        if (qt == DecsQueryType.eid_query) {
            var qlbody = new ExprBlock(at = qblk.at)
            for (a in qblk.arguments) {
                let detp = a |> is_decs_template
                if (detp is yes) {
                    kaboom |> push <| (string(a.name), detp as yes, "_{a.name}")
                    for (f in a._type.structType.fields) {
                        if (!append_index_lookup(arch_name, qlbody, f, detp as yes, "_{a.name}", a._type.flags.constant, false)) {
                            return null
                        }
                    }
                } else {
                    if (!append_index_lookup(arch_name, qlbody, a, "", "")) {
                        return null
                    }
                }
            }
            for (l in qblk.list) {
                qlbody.list |> push(clone_expression(l))
            }
            for (fl in qblk.finalList) {
                qlbody.finalList |> push(clone_expression(fl))
            }
            convert_block_to_loop(qlbody, true, false, false)
            qtop = qlbody
        } else {
            
            var qloop = new ExprFor(at = qblk.at, visibility = qblk.at)
            qloop.allowIteratorOptimization = true
            qloop.canShadow = true
            for (a in qblk.arguments) {
                let detp = a |> is_decs_template
                if (detp is yes) {
                    kaboom |> push <| (string(a.name), detp as yes, "_{a.name}")
                    for (f in a._type.structType.fields) {
                        if (!append_iterator(arch_name, qloop, f, detp as yes, "_{a.name}", a._type.flags.constant, false)) {
                            return null
                        }
                    }
                } else {
                    if (!append_iterator(arch_name, qloop, a, "", "")) {
                        return null
                    }
                }
            }
            var qlbody = new ExprBlock(at = qblk.at)
            for (l in qblk.list) {
                qlbody.list |> push(clone_expression(l))
            }
            for (fl in qblk.finalList) {
                qlbody.finalList |> push(clone_expression(fl))
            }
            if (qt == DecsQueryType.query) {
                convert_block_to_loop(qlbody, false, true, false)
            } else {
                convert_block_to_loop(qlbody, false, true, true)
            }
            qloop.body = qlbody
            qtop = qloop
        }
        apply_template(qtop) $(rules) {
            for (kb in kaboom) {
                rules |> kaboomVarField(kb._0, kb._1, kb._2)
            }
        }
        if (length(kaboom) > 0) {
            apply_template(qtop) $(rules) {
                for (kb in kaboom) {
                    rules |> replaceVariable(kb._0) <| make_static_assert_false("decs_template variables can only be accessed by fields", expr.at)
                }
            }
        }
        var qblock : ExpressionPtr
        unsafe {
            if (qt == DecsQueryType.eid_query) {
                qblock = quote() {
                    for_eid_archetype(tag_eid, tag_req, tag_erq) $(tag_arch, entity_index) {
                        tag_loop
                    }
                }
            } elif (qt == DecsQueryType.find_query) {
                qblock = quote() {
                    for_each_archetype_find(tag_req, tag_erq) $(tag_arch) {
                        tag_loop
                        return false
                    }
                }
            } elif (qt == DecsQueryType.query) {
                qblock = quote() {
                    for_each_archetype(tag_req, tag_erq) $(tag_arch) {
                        tag_loop
                    }
                }
            } else {
                macro_error(compiling_program(), expr.at, "internal error. unsupported query type")
                return null
            }
        }
        qblock |> force_at(expr.at)
        apply_template(qblock) $(rules) {
            if (qt == DecsQueryType.eid_query) {
                rules |> replaceVariable("tag_eid") <| clone_expression(expr.arguments[0])
            }
            rules |> replaceVariable("tag_erq") <| add_ptr_ref(erq_fun)
            rules |> replaceBlockArgument("tag_arch") <| arch_name
            rules |> replaceVariable("tag_req") <| new ExprConstUInt64(at = expr.at, value = req.hash)
            rules |> replaceVariable("tag_loop") <| add_ptr_ref(qtop)
        }
        var qres = move_unquote_block(qblock)
        assert(length(qres.list) == 1 && length(qres.finalList) == 0)
        var rqres = qres.list[0]
        qres := null
        rqres.genFlags.alwaysSafe = true
        return rqres
    }
}

[call_macro(name="find_query")]
class DecsFindQueryMacro : DecsQueryMacro {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        macro_verify(length(expr.arguments) == 1, prog, expr.at, "expecting find_query($(block_with_arguments))")
        return <- self->implement(expr, 0, DecsQueryType.find_query)
    }
}

[function_macro(name="decs")]
class DecsEcsMacro : AstFunctionAnnotation {
    
    
    
    
    
    
    
    
    def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        let argPass = find_arg(args, "stage")
        if (!(argPass is tString)) {
            errors := "need to specify stage"
            return false
        }
        let passName = argPass as tString
        let passFuncName = "decs`pass`{passName}"
        var blk <- setup_call_list(passFuncName, func.at, false, true)
        if (length(blk.list) == 0) {
            var reg <- setup_call_list("register`decs`passes", func.at, true, true)
            reg.list |> push(qmacro(decs::register_decs_stage_call($v(passName), @@$c(passFuncName))))
        }
        func.flags |= FunctionFlags.privateFunction
        blk.list |> push(qmacro($c("_::{func.name}")()))
        var fblk = new ExprBlock(at = func.body.at)                
        var cqq = make_call(func.at, "query")
        var cquery = cqq as ExprCallMacro
        var qblk = new ExprBlock(at = func.body.at)                
        qblk.blockFlags |= ExprBlockFlags.isClosure
        qblk.returnType = new TypeDecl(baseType = Type.tVoid, at = func.at)
        var req, nreq : array<string>
        for (arg in args) {
            if (arg.basicType == Type.tString) {
                if (arg.name == "REQUIRE") {
                    req |> push("{arg.sValue}")
                }
                if (arg.name == "REQUIRE_NOT") {
                    nreq |> push("{arg.sValue}")
                }
            }
        }
        if (!req |> empty) {
            var decl = new AnnotationDeclaration(uninitialized)
            var ann = find_annotation("decs_boost", "REQUIRE")
            unsafe {
                decl.annotation = reinterpret<Annotation?>(ann)
            }
            for (rq in req) {
                decl.arguments |> add_annotation_argument(rq, true)
            }
            qblk.annotations |> emplace(decl)
        }
        if (!nreq |> empty) {
            var decl = new AnnotationDeclaration(uninitialized)
            var ann = find_annotation("decs_boost", "REQUIRE_NOT")
            unsafe {
                decl.annotation = reinterpret<Annotation?>(ann)
            }
            for (rq in nreq) {
                decl.arguments |> add_annotation_argument(rq, true)
            }
            qblk.annotations |> emplace(decl)
        }
        var fnbody = func.body as ExprBlock
        for (el in fnbody.list) {
            qblk.list |> push(clone_expression(el))
        }
        for (ef in fnbody.finalList) {
            fblk.finalList |> push(clone_expression(ef))
        }
        for (arg in func.arguments) {
            qblk.arguments |> emplace_new <| new Variable(at = arg.at,
                name := arg.name,
                _type = clone_type(arg._type),
                init = clone_expression(arg.init)
            )
        }
        func.arguments |> clear
        cquery.arguments |> emplace_new <| new ExprMakeBlock(_block <- qblk, at = func.at)
        fblk.list |> emplace(cqq)
        func.body = fblk
        return true
    }
}

[call_macro(name="from_decs")]
class FromDecsMacro : AstCallMacro {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        macro_verify(length(expr.arguments) == 1, prog, expr.at, "expecting from_decs($(block_with_arguments))")
        macro_verify(expr.arguments[0] is ExprMakeBlock, prog, expr.at, "expecting from_decs($(block_with_arguments))")
        let mblk = expr.arguments[0] as ExprMakeBlock
        let qblk = mblk._block as ExprBlock
        macro_verify(length(qblk.arguments) != 0, prog, expr.at, "expecting from_decs($(block_with_arguments)), arguments are missing")
        for (arg in qblk.arguments) {
            macro_verify(!arg._type.isAutoOrAlias, prog, expr.at, "argument types are not fully inferred")
        }
        
        var tupleType = new TypeDecl(baseType = Type.tTuple, at = expr.at)
        tupleType.argNames.resize(qblk.arguments.length())
        for (arg, idx in qblk.arguments, count()) {
            tupleType.argTypes |> emplace_new(clone_type(arg._type))
            tupleType.argTypes[idx].flags &= ~TypeDeclFlags.ref
            tupleType.argTypes[idx].flags &= ~TypeDeclFlags.constant
            tupleType.argNames[idx] := arg.name

        }
        
        var mkTuple = new ExprMakeTuple(at = expr.at)
        mkTuple.recordNames.resize(qblk.arguments.length())
        for (arg, idx in qblk.arguments, count()) {
            mkTuple.values |> push(new ExprVar(at = arg.at, name := arg.name))
            mkTuple.recordNames[idx] := arg.name
        }
        
        var qblock = qmacro(${
            res |> push($e(mkTuple))
        })
        var qba = qblock as ExprMakeBlock
        var qbb = qba._block as ExprBlock
        qbb.blockFlags |= ExprBlockFlags.isClosure
        for (arg, idx in qblk.arguments, count()) {
            qbb.arguments |> emplace_new <| new Variable(at = arg.at,
                name := arg.name,
                _type = clone_type(arg._type),
                init = clone_expression(arg.init)
            )
            qbb.arguments[idx]._type.flags &= ~TypeDeclFlags.ref
            qbb.arguments[idx]._type.flags |= TypeDeclFlags.constant
        }
        
        var callquery = make_call(expr.at, "query")
        (callquery as ExprCallMacro).arguments |> push(clone_expression(qblock))
        
        return qmacro(
            invoke(${
                var res : array<$t(tupleType)>
                $e(callquery)
                return res.to_sequence()
            })
        )
    }
}
