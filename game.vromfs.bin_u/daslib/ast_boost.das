options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers

module ast_boost shared public










require daslib/rtti
require daslib/ast public
require strings
require daslib/strings_boost


typedef AnnotationDeclarationPtr = AnnotationDeclaration?

def isVectorType(typ : Type) {
    
    return (
        typ == Type.tInt2   || typ == Type.tInt3   || typ == Type.tInt4   ||
        typ == Type.tUInt2  || typ == Type.tUInt3  || typ == Type.tUInt4  ||
        typ == Type.tFloat2 || typ == Type.tFloat3 || typ == Type.tFloat4 ||
        typ == Type.tRange  || typ == Type.tURange || typ == Type.tRange64 ||
        typ == Type.tURange64
    )
}

def describe(list : AnnotationArgumentList) {
    
    return join([ for (arg in list); "{arg.name}={get_annotation_argument_value(arg)}" ], ",")
}

def describe(ann : AnnotationDeclaration) {
    
    if (ann.arguments |> length != 0) {
        return "{ann.annotation.name}({describe(ann.arguments)})"
    } else {
        return "{ann.annotation.name}"
    }
}

def describe(list : AnnotationList) {
    
    return join([ for (arg in list); describe(*arg) ], ",")
}

def describe(vvar : VariablePtr) {
    
    return vvar._type != null ? "{vvar.name}:{describe(vvar._type)}" : "{vvar.name}:null"
}

def describe_bitfield(bf; merger : string = "") {
    
    static_if (typeinfo is_bitfield(bf)) {
        var bftd = typeinfo ast_typedecl(bf)
        return join([ for (name, bit in bftd.argNames, range(32)); "[{name}]";
            where(int(bf) & (1 << bit)) != 0 ], merger)
    } else {
        concept_assert(false, "requires bitfield")
    }
}

def describe_function_short(func : FunctionPtr) {
    
    var args <- [for (x in func.arguments); "{x.name}:{describe(x._type,false)}" ]
    let res = "{func.name} ({join(args,";")}) : {describe(func.result,false)}"
    delete args
    return res
}

def isExpression(t : TypeDeclPtr; top : bool = true) : bool {
    
    if (t == null) {
        return false
    } elif (t.dim |> length != 0) {
        return false
    } elif (t.baseType == Type.tHandle) {
        if (t.annotation._module.name == "ast_core") {
            return starts_with("{t.annotation.name}", "Expr")
        } else {
            return false
        }
    } elif (t.baseType == Type.tPointer && top) {
        return isExpression(t.firstType, false)
    } else {
        return false
    }
}

def is_same_or_inherited(parent, child : Structure const?) {
    
    var ch = child
    while (ch != null) {
        if (parent == ch) {
            return true
        }
        ch = ch.parent
    }
    return false
}

def is_class_method(cinfo : StructurePtr; finfo : TypeDeclPtr) {
    
    if (finfo.baseType != Type.tFunction) {
        return false
    }
    if (finfo.dim |> length != 0) {
        return false
    }
    if (finfo.argTypes |> length == 0) {
        return false
    }
    if (finfo.argTypes[0].baseType != Type.tStructure) {
        return false
    }
    if (finfo.argTypes[0].dim |> length != 0) {
        return false
    }
    if (!is_same_or_inherited(finfo.argTypes[0].structType, cinfo)) {
        return false
    }
    return true
}

def emplace_new(var vec : dasvector`ptr`Expression; var ptr : Expression?) {
    
    emplace(vec, ptr)
}



def emplace_new(var vec : VectorTypeDeclPtr; var ptr : TypeDecl?) {
    
    emplace(vec, ptr)
}

def emplace_new(var vec : dasvector`ptr`Variable; var ptr : Variable?) {
    
    emplace(vec, ptr)
}

def emplace_new(var vec : array<VariablePtr>; var ptr : Variable?) {
    
    vec |> push(ptr)
}

def emplace_new(var vec : MakeStruct; var ptr : MakeFieldDecl?) {
    
    emplace(vec, ptr)
}

def override_method(var str : StructurePtr; name, funcName : string) : bool {
    
    for (fld in str.fields) {
        if (fld.name == name) {
            var vcast = new ExprCast(at = str.at,
                subexpr = new ExprAddr(at = str.at, target := funcName),
                castType = new TypeDecl(at = str.at, baseType = Type.autoinfer)
            )
            fld.init = vcast
            return true
        }
    }
    return false
}

class MacroMacro : AstFunctionAnnotation {
    
    def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        compiling_program().flags |= ProgramFlags.needMacroModule
        func.flags |= FunctionFlags.macroInit
        var blk = new ExprBlock(at = func.at)
        var ifm = new ExprCall(at = func.at, name := "is_compiling_macros")
        var ife = new ExprIfThenElse(at = func.at, cond = ifm, if_true = func.body)
        emplace(blk.list, ife)
        func.body = blk
        return true
    }
}

class TagFunctionAnnotation : AstFunctionAnnotation {
    
    def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        for (arg in args) {
            let val = get_annotation_argument_value(arg)
            if (!(val is tBool)) {
                errors := "tag_function annotation expects only tag names"
                return false
            }
        }
        return true
    }
}

class TagStructureAnnotation : AstStructureAnnotation {
    
    def override apply(var str : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        for (arg in args) {
            let val = get_annotation_argument_value(arg)
            if (!(val is tBool)) {
                errors := "tag_structure annotation expects only tag names"
                return false
            }
        }
        return true
    }
}

def private for_each_tag_function(mod : Module?; tag : string; blk : block<(var func : FunctionPtr) : void>) {
    for_each_function(mod, "") $(func) {
        for (ann in func.annotations) {
            if (ann != null && ann.annotation.name == "tag_function") {
                for (t in ann.arguments) {
                    if (t.name == tag) {
                        invoke(blk, func)
                    }
                }
            }
        }
    }
    for_each_generic(mod, "") $(func) {
        for (ann in func.annotations) {
            if (ann != null && ann.annotation.name == "tag_function") {
                for (t in ann.arguments) {
                    if (t.name == tag) {
                        invoke(blk, func)
                    }
                }
            }
        }
    }
}

[deprecated]
def find_arg(argn : string; args : AnnotationArgumentList) : RttiValue {
    
    for (a in args) {
        if (a.name == argn) {
            return get_annotation_argument_value(a)
        }
    }
    return RttiValue_nothing()
}

def find_arg(args : AnnotationArgumentList; argn : string) : RttiValue {
    
    for (a in args) {
        if (a.name == argn) {
            return get_annotation_argument_value(a)
        }
    }
    return RttiValue_nothing()
}

def private apply_tag_annotation(tag : string; var ann : FunctionAnnotationPtr) {
    var funcs : array<FunctionPtr>
    for_each_tag_function(this_module(), tag) $(func) {
        funcs |> push(func)
    }
    for (func in funcs) {
        {
            var tagAnn = ann
            add_function_annotation(func, tagAnn)
        }
    }
}

def setup_tag_annotation(name, tag : string; var classPtr) {
    
    var ann = make_function_annotation(name, classPtr)
    apply_tag_annotation(tag, ann)
    this_module() |> add_function_annotation(ann)
}

def find_unique_function(mod : Module?; name : string; canfail : bool = false) {
    
    var res : FunctionPtr
    var count = 0
    for_each_function(mod, name) $(func) {
        res := func
        count ++
    }
    if (count > 1) {
        if (!canfail) {
            panic("more than one function encountered")
        }
        return <- default<FunctionPtr>
    }
    return <- res
}

def find_unique_generic(mod : Module?; name : string; canfail : bool = false) {
    
    var res : FunctionPtr
    var count = 0
    for_each_generic(mod, name) $(func) {
        res := func
        count ++
    }
    if (count > 1) {
        if (!canfail) {
            panic("more than one generic function encountered")
        }
        return <- default<FunctionPtr>
    }
    return <- res
}

def setup_call_list(name : string; at : LineInfo; subblock : block<(var fn : FunctionPtr) : void>) : ExprBlock? {
    
    var fn = compiling_module() |> find_unique_function(name)
    if (fn == null) {
        fn = new Function(at = at, atDecl = at, name := "{name}",
            flags = FunctionFlags.generated,
            result = new TypeDecl(baseType = Type.autoinfer, at = at)
        )
        var blk = new ExprBlock(at = at)
        var res = blk
        fn.body = blk
        invoke(subblock, fn)
        if (!(compiling_module() |> add_function(fn))) {
            panic("failed to setup macro, can't add function {fn.name}")
        }
        return res
    } elif (fn.body.__rtti != "ExprBlock") {
        panic("expecting func.ExprBlock")
    }
    return unsafe(reinterpret<ExprBlock?> fn.body)
}

def setup_call_list(name : string; at : LineInfo; isInit : bool = false; isPrivate : bool = true; isLateInit : bool = false) : ExprBlock? {
    
    return setup_call_list(name, at) $(fn) {
        if (isInit) {
            fn.flags |= FunctionFlags.init
            if (isLateInit) {
                fn.moreFlags |= MoreFunctionFlags.lateInit
            }
        }
        if (isPrivate) {
            fn.flags |= FunctionFlags.privateFunction
        }
    }
}

def setup_macro(name : string; at : LineInfo) : ExprBlock? {
    
    compiling_program().flags |= ProgramFlags.needMacroModule
    var fn = compiling_module() |> find_unique_function(name)
    if (fn == null) {
        fn = new Function(at = at, atDecl = at, name := "{name}",
            flags = FunctionFlags.generated | FunctionFlags.macroInit | FunctionFlags.privateFunction,
            result = new TypeDecl(baseType = Type.autoinfer, at = at)
        )
        var blk = new ExprBlock(at = at)
        var iblk = new ExprBlock(at = at)
        let res = iblk
        var ifm = new ExprCall(at = at, name := "is_compiling_macros_in_module")
        var ifmn = new ExprConstString(at = at, value := compiling_module().name)
        emplace(ifm.arguments, ifmn)
        var ife = new ExprIfThenElse(at = at, cond = ifm, if_true = iblk)
        emplace(blk.list, ife)
        fn.body = blk
        if (!(compiling_module() |> add_function(fn))) {
            panic("failed to setup macro, can't add function {fn.name}")
        }
        return unsafe(reinterpret<ExprBlock?> res)
    } else {
        if (fn.body.__rtti != "ExprBlock") {
            panic("expecting func.ExprBlock")
        }
        unsafe {
            var blk = reinterpret<ExprBlock?> fn.body
            if (blk.list |> length != 1 || blk.list[0].__rtti != "ExprIfThenElse") {
                panic("expecting is_compiling_macros")
            }
            var ife = reinterpret<ExprIfThenElse?> blk.list[0]
            if (ife.if_true.__rtti != "ExprBlock") {
                panic("expecting ife.if_true.ExprBlock")
            }
            return reinterpret<ExprBlock?> ife.if_true
        }
    }
}

class SetupAnyAnnotation : AstStructureAnnotation {
    
    annotation_function_call : string = ""
    name : string
    def setup_call(var st : StructurePtr; var cll : ExprCall?) {
        
        emplace_new(cll.arguments, new ExprConstString(at = st.at, value := name))
    }
    def override apply(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        let argName = args |> find_arg("name")
        if (argName is nothing) {
            name = "{st.name}"
        } elif (!(argName is tString)) {
            errors := "name must be string"
            return false
        } else {
            name = argName as tString
        }
        var blk <- setup_macro("__setup_macros", st.at)
        var cll = new ExprCall(at = st.at, name := annotation_function_call)
        self->setup_call(st, cll)
        var nee = new ExprNew(at = st.at, initializer = true,
            typeexpr = new TypeDecl(baseType = Type.tStructure, structType = st, at = st.at)
        )
        emplace(cll.arguments, nee)
        emplace(blk.list, cll)
        return true
    }
}

class SetupFunctionAnnotation : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_function_annotation"
}

class SetupBlockAnnotation : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_block_annotation"
}

class SetupStructureAnnotation : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_structure_annotation"
}

class SetupEnumerationAnnotation : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_enumeration_annotation"
}

class SetupContractAnnotation : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_contract_annotation"
}

class SetupReaderMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_reader_macro"
}

class SetupCommentReader : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_comment_reader"
}

class SetupVariantMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_variant_macro"
}

class SetupForLoopMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_for_loop_macro"
}

class SetupCaptureMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_capture_macro"
}

class SetupTypeMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_type_macro"
}

class SetupSimulateMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_simulate_macro"
}

class SetupCallMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_call_macro"
}

class SetupTypeInfoMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_typeinfo_macro"
}

class SetupInferMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_infer_macro"
}

class SetupDirtyInferMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_dirty_infer_macro"
}

class SetupLintMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_lint_macro"
}

class SetupGlobalLintMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_global_lint_macro"
}

class SetupOptimizationMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "add_new_optimization_macro"
}

class TagFunctionMacro : SetupAnyAnnotation {
    
    override annotation_function_call : string = "setup_tag_annotation"
    tag : string
    def override setup_call(var st : StructurePtr; var cll : ExprCall?) {
        
        emplace_new(cll.arguments, new ExprConstString(at = st.at, value := name))
        emplace_new(cll.arguments, new ExprConstString(at = st.at, value := tag))
    }
    def override apply(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        let argTag = args |> find_arg("tag")
        if (argTag is nothing) {
            errors := "missing tag argument"
            return false
        } elif (!(argTag is tString)) {
            errors := "tag must be string"
            return false
        }
        tag = argTag as tString
        return SetupAnyAnnotation`apply(cast<SetupAnyAnnotation> self, st, group, args, errors)
    }
}

def public panic_expr_as : void ? {
    
    panic("invalid 'as' expression or null pointer dereference")
    return null
}

def private makeAsOrSafeAs(expr; var enull : Expression?) {
    var vdr = new ExprField(at = expr.at, name := "__rtti", value = clone_expression(expr.value))
    var cna = new ExprConstString(at = expr.at, value := expr.name)
    var cond = new ExprOp2(at = expr.at, op := "==", left = vdr, right = cna)
    var ctype = new TypeDecl(at = expr.at,
        baseType = Type.tPointer,
        firstType = new TypeDecl(at = expr.at, baseType = Type.alias, alias := expr.name)
    )
    var esub = clone_expression(expr.value)
    if (expr.value._type.baseType == Type.tPointer) {
        var neqz = new ExprOp2(at = expr.at, op := "!=",
            left = clone_expression(expr.value),
            right = new ExprConstPtr(at = expr.at)
        )
        var nand = new ExprOp2(at = expr.at, op := "&&",
            left = neqz,
            right = cond
        )
        cond = nand
    } else {
        var nsub = new ExprRef2Ptr(at = expr.at,
            subexpr = esub,
            genFlags = ExprGenFlags.alwaysSafe
        )
        esub = nsub
    }
    var vcast = new ExprCast(at = expr.at,
        subexpr = esub,
        castType <- ctype,
        castFlags = ExprCastFlags.reinterpretCast,
        genFlags = ExprGenFlags.alwaysSafe
    )
    var tri = new ExprOp3(at = expr.at, op := "?",
        subexpr = cond,
        left = vcast,
        right = enull
    )
    tri.genFlags = expr.genFlags
    return tri
}



class BetterRttiVisitor : AstVariantMacro {
    
    def override visitExprIsVariant(prog : ProgramPtr; mod : Module?; expr : ExprIsVariant?) : Expression? {
        
        if (isExpression(expr.value._type)) {
            var vdr = new ExprField(at = expr.at, name := "__rtti", value = clone_expression(expr.value))
            var cna = new ExprConstString(at = expr.at, value := expr.name)
            var veq = new ExprOp2(at = expr.at, op := "==", left = vdr, right = cna)
            return veq
        }
        return null
    }
    def override visitExprAsVariant(prog : ProgramPtr; mod : Module?; expr : ExprAsVariant?) : Expression? {
        
        if (isExpression(expr.value._type)) {
            return makeAsOrSafeAs(expr, new ExprCall(at = expr.at, name := "panic_expr_as"))
        }
        return null
    }
    def override visitExprSafeAsVariant(prog : ProgramPtr; mod : Module?; expr : ExprSafeAsVariant?) : Expression? {
        
        if (isExpression(expr.value._type)) {
            return makeAsOrSafeAs(expr, new ExprConstPtr(at = expr.at))
        }
        return null
    }
}

def operator is BuiltInFunction(anything) {
    
    return false
}

def operator is BuiltInFunction(foo : Function?) {
    
    return foo.flags.builtIn
}

def operator as BuiltInFunction(foo : Function?) {
    
    verify(foo is BuiltInFunction)
    return unsafe(reinterpret<BuiltInFunction?>(foo));
}

def operator is ExternalFnBase(anything) {
    
    return false
}

def operator is ExternalFnBase(foo : Function?) {
    
    return foo.moreFlags.propertyFunction && foo.flags.builtIn
}

def operator as ExternalFnBase(foo : Function?) {
    
    verify(foo is ExternalFnBase)
    return unsafe(reinterpret<ExternalFnBase?>(foo));
}

def operator is FunctionAnnotation(anything) {
    
    return false
}

def operator is FunctionAnnotation(foo : Annotation?) {
    
    return foo.isFunctionAnnotation
}

def operator as FunctionAnnotation(foo : Annotation?) {
    
    verify(foo is FunctionAnnotation)
    return unsafe(reinterpret<FunctionAnnotation?>(foo));
}


def operator is StructureAnnotation(anything) {
    
    return false
}

def operator is StructureAnnotation(foo : Annotation?) {
    
    return foo.isStructureAnnotation
}

def operator as StructureAnnotation(foo : Annotation?) {
    
    verify(foo is StructureAnnotation)
    return unsafe(reinterpret<StructureAnnotation?>(foo));
}

def private walk_and_convert_array(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    let total = any_array_size(data)
    if (total != 0) {
        let stride = info.firstType.sizeOf
        var mkArr = new ExprMakeArray(at = at, makeType = clone_type(info.firstType))
        any_array_foreach(data, stride) $(value) {
            emplace_new(mkArr.values) <| walk_and_convert(value, info.firstType, at)
        }
        push(mkArr.makeType.dim, total)
        var mkToArrayMove = new ExprCall(at = at, name := "to_array_move")
        emplace(mkToArrayMove.arguments, mkArr)
        return mkToArrayMove
    } else {
        return new ExprMakeStruct(at = at, makeType = clone_type(info))
    }
}

def private walk_and_convert_dim(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    let stride = info.baseSizeOf
    let total = info.countOf
    var einfo = clone_type(info)
    clear(einfo.dim)
    var mkArr = new ExprMakeArray(at = at, makeType = clone_type(info))
    for (x in range(total)) {
        unsafe {
            var elem = walk_and_convert(data + stride * x, einfo, at)
            emplace(mkArr.values, elem)
        }
    }
    return mkArr
}

def private walk_and_convert_pointer(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    unsafe {
        let pdata = *(reinterpret<uint8 const ??> data)
        var elem = walk_and_convert(pdata, info.firstType, at)
        var mkAsc = new ExprAscend(at = at, subexpr = elem)
        return mkAsc
    }
}

def private walk_and_convert_tuple(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    var mkArr = new ExprMakeTuple(at = at, recordType = clone_type(info))
    for (idx in range(info.argTypes |> length)) {
        let offset = get_tuple_field_offset(info, idx)
        unsafe {
            var elem = walk_and_convert(data + offset, info.argTypes[idx], at)
            emplace(mkArr.values, elem)
        }
    }
    return mkArr
}

def private walk_and_convert_structure(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    var mkStruct = new ExprMakeStruct(at = at, makeType = clone_type(info))
    let stype = info.structType
    var mkS = new MakeStruct(uninitialized)
    for (x in stype.fields) {
        if (x.annotation |> find_arg("do_not_convert") is nothing) {
            unsafe {
                let fdata = data + x.offset
                var elem = walk_and_convert(fdata, x._type, at)
                var mkF = new MakeFieldDecl(at = at, name := x.name, value = elem)
                if (!x._type.canCopy) {
                    mkF.flags = MakeFieldDeclFlags.moveSemantics
                }
                emplace_new(*mkS, mkF)
            }
        }
    }
    emplace(mkStruct.structs, mkS)
    return mkStruct
}

def private walk_and_convert_variant(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    unsafe {
        let vindex = *reinterpret<int?> data
        let offset = get_variant_field_offset(info, vindex)
        var mkVariant = new ExprMakeVariant(at = at, makeType = clone_type(info))
        var elem = walk_and_convert(data + offset, info.argTypes[vindex], at)
        var mkS = new MakeFieldDecl(at = at, name := info.argNames[vindex], value = elem)
        if (!info.argTypes[vindex].canCopy) {
            mkS.flags = MakeFieldDeclFlags.moveSemantics
        }
        emplace(mkVariant.variants, mkS)
        return mkVariant
    }
}

def private walk_and_convert_table(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    let total = any_table_size(data)
    if (total != 0) {
        var tupT = new TypeDecl(baseType = Type.tTuple, at = at)
        tupT.argTypes |> push(clone_type(info.firstType))
        tupT.argTypes |> push(clone_type(info.secondType))
        var mkArr = new ExprMakeArray(at = at, makeType = clone_type(tupT))
        let key_stride = info.firstType.sizeOf
        let value_stride = info.secondType.sizeOf
        any_table_foreach(data, key_stride, value_stride) $(pkey, pvalue) {
            var key = walk_and_convert(pkey, info.firstType, at)
            var value = walk_and_convert(pvalue, info.secondType, at)
            var mkTup = new ExprMakeTuple(at = at, recordType = clone_type(tupT), isKeyValue = true)
            emplace(mkTup.values, key)
            emplace(mkTup.values, value)
            emplace(mkArr.values, mkTup)
        }
        push(mkArr.makeType.dim, total)
        var mkToTableMove = new ExprCall(at = at, name := "to_table_move")
        emplace(mkToTableMove.arguments, mkArr)
        return mkToTableMove
    } else {
        return new ExprMakeStruct(at = at, makeType = clone_type(info))
    }
}

def private walk_and_convert_basic(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    unsafe {
        if (info.baseType == Type.tInt8) {
            return new ExprConstInt8(at = at, value = *reinterpret<int8?> data)
        } elif (info.baseType == Type.tInt16) {
            return new ExprConstInt16(at = at, value = *reinterpret<int16?> data)
        } elif (info.baseType == Type.tInt) {
            return new ExprConstInt(at = at, value = *reinterpret<int?> data)
        } elif (info.baseType == Type.tInt64) {
            return new ExprConstInt64(at = at, value = *reinterpret<int64?> data)
        } elif (info.baseType == Type.tUInt8) {
            return new ExprConstUInt8(at = at, value = *reinterpret<uint8?> data)
        } elif (info.baseType == Type.tUInt16) {
            return new ExprConstUInt16(at = at, value = *reinterpret<uint16?> data)
        } elif (info.baseType == Type.tUInt) {
            return new ExprConstUInt(at = at, value = *reinterpret<uint?> data)
        }  elif (info.baseType == Type.tUInt64) {
            return new ExprConstUInt64(at = at, value = *reinterpret<uint64?> data)
        } elif (info.baseType == Type.tFloat) {
            return new ExprConstFloat(at = at, value = *reinterpret<float?> data)
        } elif (info.baseType == Type.tDouble) {
            return new ExprConstDouble(at = at, value = *reinterpret<double?> data)
        } elif (info.baseType == Type.tBool) {
            return new ExprConstBool(at = at, value = *reinterpret<bool?> data)
        } elif (info.baseType == Type.tRange) {
            return new ExprConstRange(at = at, value = *reinterpret<range?> data)
        } elif (info.baseType == Type.tURange) {
            return new ExprConstURange(at = at, value = *reinterpret<urange?> data)
        } elif (info.baseType == Type.tRange64) {
            return new ExprConstRange64(at = at, value = *reinterpret<range64?> data)
        } elif (info.baseType == Type.tURange64) {
            return new ExprConstURange64(at = at, value = *reinterpret<urange64?> data)
        } elif (info.baseType == Type.tString) {
            return new ExprConstString(at = at, value := *reinterpret<string?> data)
        } elif (info.baseType == Type.tBitfield8
                || info.baseType == Type.tBitfield16
                || info.baseType == Type.tBitfield
                || info.baseType == Type.tBitfield64) {
            return new ExprConstBitfield(at = at, value = *reinterpret<bitfield?> data, bitfieldType = clone_type(info))
        } else {
            panic("unsupported {info.baseType}")
            return null
        }
    }
}

def private walk_and_convert_enumeration(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    var eval = 0l
    if (info.baseType == Type.tEnumeration) {
        eval = int64(*unsafe(reinterpret<int?> data))
    } elif (info.baseType == Type.tEnumeration8) {
        eval = int64(*data)
    } elif (info.baseType == Type.tEnumeration16) {
        eval = int64(*unsafe(reinterpret<int16?> data))
    } elif (info.baseType == Type.tEnumeration64) {
        eval = *unsafe(reinterpret<int64?> data)
    } else {
        panic("unsupported enumeration")
    }
    let name = info.enumType |> find_enum_name(eval)
    panic("can't find name of enum value {eval} in {describe(info)}") if (name == "")
    return new ExprConstEnumeration(
        enumType := unsafe(reinterpret<Enumeration?> info.enumType),
        value := name)
}

def walk_and_convert(data : uint8 const?; info : TypeDeclPtr; at : LineInfo) : Expression? {
    
    
    if (info.dim |> length != 0) {
        return walk_and_convert_dim(data, info, at)
    } elif (info.baseType == Type.tArray) {
        return walk_and_convert_array(data, info, at)
    } elif (info.baseType == Type.tPointer) {
        unsafe {
            if (*reinterpret<uint8 const ??> data == null) {
                return new ExprConstPtr(at = at)
            } elif (info.firstType == null || info.firstType.isVoid) {
                return new ExprConstPtr(at = at)
            } else {
                return walk_and_convert_pointer(data, info, at)
            }
        }
    } elif (info.baseType == Type.tStructure) {
        return walk_and_convert_structure(data, info, at)
    } elif (info.baseType == Type.tVariant) {
        return walk_and_convert_variant(data, info, at)
    } elif (info.baseType == Type.tTuple) {
        return walk_and_convert_tuple(data, info, at)
    } elif (info.baseType == Type.tTable) {
        return walk_and_convert_table(data, info, at)
    } elif (info.baseType == Type.tEnumeration8 || info.baseType == Type.tEnumeration16 || info.baseType == Type.tEnumeration64 || info.baseType == Type.tEnumeration) {
        return walk_and_convert_enumeration(data, info, at)
    } else {
        return walk_and_convert_basic(data, info, at)
    }
}

def convert_to_expression(var value : auto& ==const; at : LineInfo) {
    
    var info = typeinfo ast_typedecl(value)
    unsafe {
        let pval = addr(value)
        return walk_and_convert(reinterpret<uint8 const?> pval, info, at)
    }
}

def convert_to_expression(value : auto ==const; at : LineInfo) {
    
    var info = typeinfo ast_typedecl(value)
    unsafe {
        let pval = addr(value)
        return walk_and_convert(reinterpret<uint8 const?> pval, info, at)
    }
}

def convert_to_expression(var value : auto ==const) {
    
    return <- convert_to_expression(value, LineInfo())
}

def convert_to_expression(value : auto ==const) {
    
    return <- convert_to_expression(value, LineInfo())
}

def find_annotation(mod_name, ann_name : string) : Annotation const? {
    
    var mod = find_compiling_module(mod_name)
    if (mod == null) {
        return null
    }
    var ann : Annotation const?
    module_for_each_annotation(mod) $(value) {
        if (value.name == ann_name) {
            unsafe {
                ann = addr(value)
            }
        }
    }
    return ann
}

def append_annotation(mod_name, ann_name : string; args : array< tuple<argname : string; argvalue : RttiValue> >) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = new AnnotationDeclaration(uninitialized)
    unsafe { decl.annotation = reinterpret<Annotation?>(ann); }
    for (argP in args) {
        let argName & = argP.argname
        let arg & = argP.argvalue
        if (arg is tBool) {
            decl.arguments |> add_annotation_argument(argName, arg as tBool)
        } elif (arg is tInt) {
            decl.arguments |> add_annotation_argument(argName, arg as tInt)
        } elif (arg is tFloat) {
            decl.arguments |> add_annotation_argument(argName, arg as tFloat)
        } elif (arg is tString) {
            decl.arguments |> add_annotation_argument(argName, arg as tString)
        } else {
            panic("Invalid rtti value {arg} for annotation argument {argName}")
        }
    }
    return decl
}

def append_annotation(mod_name, ann_name : string) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = new AnnotationDeclaration(uninitialized)
    unsafe { decl.annotation = reinterpret<Annotation?>(ann); }
    return decl
}

def append_annotation(var func : FunctionPtr; mod_name, ann_name : string) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name)
    add_function_annotation(func, decl)
}

def append_annotation(var blk : ExprBlock?; mod_name, ann_name : string) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name)
    add_block_annotation(blk, decl)
}

def append_annotation(var st : Structure?; mod_name, ann_name : string) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name)
    add_structure_annotation(st, decl)
}

def append_annotation(var func : FunctionPtr; mod_name, ann_name : string; args : array< tuple<argname : string; argvalue : RttiValue> >) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name, args)
    add_function_annotation(func, decl)
}

def append_annotation(var blk : ExprBlock?; mod_name, ann_name : string; args : array< tuple<argname : string; argvalue : RttiValue> >) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name, args)
    add_block_annotation(blk, decl)
}

def append_annotation(var st : Structure?; mod_name, ann_name : string; args : array< tuple<argname : string; argvalue : RttiValue> >) {
    
    var ann = find_annotation(mod_name, ann_name)
    assert(ann != null)
    var decl = append_annotation(mod_name, ann_name, args)
    add_structure_annotation(st, decl)
}

def add_annotation_argument(var arguments : AnnotationArgumentList; argName : string; val : bool) {
    
    let argIdx = arguments |> add_annotation_argument(argName)
    arguments[argIdx].basicType = Type.tBool
    arguments[argIdx].bValue = val
    return argIdx
}

def add_annotation_argument(var arguments : AnnotationArgumentList; argName : string; val : int) {
    
    let argIdx = arguments |> add_annotation_argument(argName)
    arguments[argIdx].basicType = Type.tInt
    arguments[argIdx].iValue = val
    return argIdx
}

def add_annotation_argument(var arguments : AnnotationArgumentList; argName : string; val : float) {
    
    let argIdx = arguments |> add_annotation_argument(argName)
    arguments[argIdx].basicType = Type.tFloat
    arguments[argIdx].fValue = val
    return argIdx
}

def add_annotation_argument(var arguments : AnnotationArgumentList; argName : string; val : string) {
    
    let argIdx = arguments |> add_annotation_argument(argName)
    arguments[argIdx].basicType = Type.tString
    arguments[argIdx].sValue := val
    return argIdx
}

def add_annotation_argument(var arguments : AnnotationArgumentList; ann : rtti::AnnotationArgument) {
    
    let argIdx = arguments |> add_annotation_argument(string(ann.name))
    arguments[argIdx].basicType = ann.basicType
    if (ann.basicType == Type.tBool) {
        arguments[argIdx].bValue = ann.bValue
    } elif (ann.basicType == Type.tInt) {
        arguments[argIdx].iValue = ann.iValue
    } elif (ann.basicType == Type.tFloat) {
        arguments[argIdx].fValue = ann.fValue
    } elif (ann.basicType == Type.tString) {
        arguments[argIdx].sValue := ann.sValue
    } else {
        assert(false, "unsupported annotation type, add more types")
    }
    return argIdx
}

def get_for_source_index(expr : ExprFor?; svar : VariablePtr) {
    
    for (v, t in expr.iteratorVariables, count()) {
        if (v == svar) {
            return t
        }
    }
    return -1
}

def get_for_source_index(expr : ExprFor?; source : Expression?) {
    
    for (s, t in expr.sources, count()) {
        if (s == source) {
            return t
        }
    }
    return -1
}

[macro_function]
def make_static_assert_false(text : string; at : LineInfo) {
    
    var esa = new ExprStaticAssert(at = at)
    esa.arguments |> emplace_new <| new ExprConstBool(at = at, value = false)
    esa.arguments |> emplace_new <| new ExprConstString(at = at, value := text)
    return esa
}

[_macro]
def private setup {
    if (is_compiling_macros_in_module("ast_boost")) {
        add_new_function_annotation("macro", new MacroMacro())
        add_new_function_annotation("tag_function", new TagFunctionAnnotation())
        add_new_structure_annotation("function_macro", new SetupFunctionAnnotation())
        add_new_structure_annotation("block_macro", new SetupBlockAnnotation())
        add_new_structure_annotation("structure_macro", new SetupStructureAnnotation())
        add_new_structure_annotation("enumeration_macro", new SetupEnumerationAnnotation())
        add_new_structure_annotation("contract", new SetupContractAnnotation())
        add_new_structure_annotation("reader_macro", new SetupReaderMacro())
        add_new_structure_annotation("comment_reader", new SetupCommentReader())
        add_new_structure_annotation("call_macro", new SetupCallMacro())
        add_new_structure_annotation("typeinfo_macro", new SetupTypeInfoMacro())
        add_new_structure_annotation("variant_macro", new SetupVariantMacro())
        add_new_structure_annotation("for_loop_macro", new SetupForLoopMacro())
        add_new_structure_annotation("capture_macro", new SetupCaptureMacro())
        add_new_structure_annotation("type_macro", new SetupTypeMacro())
        add_new_structure_annotation("simulate_macro", new SetupSimulateMacro())
        add_new_structure_annotation("tag_structure", new TagStructureAnnotation())
        add_new_structure_annotation("tag_function_macro", new TagFunctionMacro())
        add_new_structure_annotation("infer_macro", new SetupInferMacro())
        add_new_structure_annotation("dirty_infer_macro", new SetupDirtyInferMacro())
        add_new_structure_annotation("optimization_macro", new SetupOptimizationMacro())
        add_new_structure_annotation("lint_macro", new SetupLintMacro())
        add_new_structure_annotation("global_lint_macro", new SetupGlobalLintMacro())
        add_new_variant_macro("better_rtti_in_expr", new BetterRttiVisitor())
    }
}


def public function_to_type(fn : FunctionPtr) : TypeDeclPtr {
    
    var td = new TypeDecl(baseType = Type.tFunction,
        firstType = fn.result != null ? clone_type(fn.result) : new TypeDecl(baseType = Type.autoinfer)
    )
    td.argNames |> resize(length(fn.arguments))
    for (arg, argi in fn.arguments, count()) {
        td.argTypes |> push(clone_type(arg._type))
        td.argNames[argi] := arg.name
    }
    return <- td
}



def public isCMRES(fun : FunctionPtr) : bool {
    
    return fun.flags.copyOnReturn || fun.flags.moveOnReturn
}

def public isMakeLocal(expr : Expression?) {
    
    return ((expr.__rtti == "ExprMakeLocal")
        ||  (expr.__rtti == "ExprMakeStruct")
        ||  (expr.__rtti == "ExprMakeVariant")
        ||  (expr.__rtti == "ExprMakeArray")
        ||  (expr.__rtti == "ExprMakeTuple"))
}

def public isExprCallFunc(expr : Expression?) {
    
    return ((expr.__rtti == "ExprCallFunc")
        ||  (expr.__rtti == "ExprOp")
        ||  (expr.__rtti == "ExprNew")
        ||  (expr.__rtti == "ExprCall"))
}

def public get_workhorse_types {
    
    return fixed_array(
        Type.tBool,
        Type.tString,           Type.tPointer,
        Type.tFloat,            Type.tDouble,
        Type.tEnumeration,      Type.tEnumeration8,     Type.tEnumeration16,    Type.tEnumeration64,
        Type.tBitfield,         Type.tBitfield8,        Type.tBitfield16,       Type.tBitfield64,
        Type.tInt,              Type.tInt8,             Type.tInt16,            Type.tInt64,
        Type.tUInt,             Type.tUInt8,            Type.tUInt16,           Type.tUInt64,
        Type.tInt2,             Type.tInt3,             Type.tInt4,
        Type.tUInt2,            Type.tUInt3,            Type.tUInt4,
        Type.tFloat2,           Type.tFloat3,           Type.tFloat4,
        Type.tRange,            Type.tRange64,
        Type.tURange,           Type.tURange64,
    )
}

def public find_argument_index(typ : TypeDeclPtr; name : string) {
    
    for (a, ai in typ.argNames, count()) {
        if (a == name) {
            return ai
        }
    }
    return -1
}

def public isCMRESType(blockT : TypeDeclPtr) {
    
    return blockT != null && blockT.isRefType && !blockT.flags.ref
}

bitfield DebugExpressionFlags {
    
    refCount,
    lineInfo
}

def private debug_expression_impl(var writer : StringBuilderWriter; expr : Expression?; deFlags : DebugExpressionFlags; tabs : int) {
    if (expr == null) {
        writer |> write("null")
        return
    }
    if (empty(expr.__rtti)) {
        writer |> write("[NO RTTI]")
        return
    }
    writer |> write("({expr.__rtti}")
    if (deFlags.refCount) {
        writer |> write("<>")
    }
    if (deFlags.lineInfo) {
        let e = expr
        writer |> write(" at={int(e.at.line)}:{int(e.at.column)}-{int(e.at.last_line)}:{int(e.at.last_column)}")
        if (e.at.fileInfo != null) {
            writer |> write(" file=\"{e.at.fileInfo.name}\"")
        }
        if (string(e.__rtti) == "ExprCall" || string(e.__rtti) == "ExprInvoke") { 
            let enc = unsafe(reinterpret<ExprLooksLikeCall?> e)
            if (int(enc.atEnclosure.line) != 0 || int(enc.atEnclosure.last_line) != 0) {
                writer |> write(" atEnclosure={int(enc.atEnclosure.line)}:{int(enc.atEnclosure.column)}-{int(enc.atEnclosure.last_line)}:{int(enc.atEnclosure.last_column)}")
            }
        }
    }
    if (string(expr.__rtti) |> starts_with("ExprConst")) {
        writer |> write(" {describe(expr)})")
        return
    }
    var ann = unsafe(reinterpret<BasicStructureAnnotation?> get_expression_annotation(expr))
    if (ann == null) {
        writer |> write(")")
        return
    }
    for_each_field(*ann) $(name, cppName, xtype, offset) {
        if (offset != -1u) {
            let tstr = describe(xtype)
            var p8 : int8?
            unsafe {
                p8 = (reinterpret<int8?> expr) + int(offset)
            }
            if (tstr == "ast_core::Expression?") {
                let pv = unsafe(reinterpret<Expression ??> p8)
                let ts = repeat("  ", tabs + 2)
                writer |> write("\n{ts}({name} ")
                debug_expression_impl(writer, *pv, deFlags, tabs + 2)
                writer |> write(")")
            } elif (tstr == "$::das_string") {
                let pv = unsafe(reinterpret<das_string?> p8)
                writer |> write(" {name}=\"{*pv}\"")
            } elif (tstr == "int") {
                let pv = unsafe(reinterpret<int?> p8)
                writer |> write(" {name}={*pv}")
            } elif (tstr == "uint") {
                let pv = unsafe(reinterpret<uint?> p8)
                writer |> write(" {name}={*pv}")
            } elif (tstr == "int64") {
                let pv = unsafe(reinterpret<int64?> p8)
                writer |> write(" {name}={*pv}")
            } elif (tstr == "uint64") {
                let pv = unsafe(reinterpret<uint64?> p8)
                writer |> write(" {name}={*pv}")
            } elif (tstr == "bool") {
                let pv = unsafe(reinterpret<bool?> p8)
                writer |> write(" {name}={*pv}")
            } else {
                pass
            }
        }
    }
                
    for_each_field(*ann) $(name, cppName, xtype, offset) {
        if (offset != -1u) {
            let tstr = describe(xtype)
            var p8 : int8?
            unsafe {
                p8 = (reinterpret<int8?> expr) + int(offset)
            }
            if (tstr == "$::dasvector`ptr`Expression") {
                let pv = unsafe(reinterpret<dasvector`ptr`Expression?> p8)
                if (length(*pv) != 0) {
                    let ts = repeat("  ", tabs + 2)
                    writer |> write("\n{ts}[{name}\n")
                    for (l, i in *pv, count()) {
                        writer |> write("{ts}  ")
                        debug_expression_impl(writer, l, deFlags, tabs + 2)
                        if (i != length(*pv) - 1) {
                            writer |> write("\n")
                        }
                    }
                    writer |> write("]")
                }
            } elif (tstr == "$::dasvector`ptr`Variable") {
                let pv = unsafe(reinterpret<dasvector`ptr`Variable?> p8)
                if (length(*pv) != 0) {
                    let ts = repeat("  ", tabs + 2)
                    writer |> write("\n{ts}[{name}\n")
                    for (l, i in *pv, count()) {
                        writer |> write("{ts}  ")
                        writer |> write("{l.name}:{describe(l._type)}")
                        if (l.init != null) {
                            writer |> write(" = ")
                            debug_expression_impl(writer, l.init, deFlags, tabs + 2)
                        }
                        if (i != length(*pv) - 1) {
                            writer |> write("\n")
                        }
                    }
                    writer |> write("]")
                }
            }
        }
    }
    writer |> write(")")
}

def public debug_expression(expr : Expression?; deFlags : DebugExpressionFlags = bitfield(0)) {
    
    return build_string() $(writer) {
        debug_expression_impl(writer, expr, deFlags, 0)
    }
}




def getVectorElementCount(bt : Type) {
    
    return 2 if (bt == Type.tFloat2 || bt == Type.tInt2 || bt == Type.tUInt2 || bt == Type.tRange || bt == Type.tURange || bt == Type.tRange64 || bt == Type.tURange64)
    return 3 if (bt == Type.tFloat3 || bt == Type.tInt3 || bt == Type.tUInt3)
    return 4 if (bt == Type.tFloat4 || bt == Type.tInt4 || bt == Type.tUInt4)
    return 0
}

def getVectorElementSize(bt : Type) {
    
    return 8 if (bt == Type.tRange64 || bt == Type.tURange64)
    return 4
}

def getVectorElementType(bt : Type) {
    
    return Type.tFloat if (bt == Type.tFloat2 || bt == Type.tFloat3 || bt == Type.tFloat4)
    return Type.tInt if (bt == Type.tInt2 || bt == Type.tInt3 || bt == Type.tInt4 || bt == Type.tRange)
    return Type.tUInt if (bt == Type.tUInt2 || bt == Type.tUInt3 || bt == Type.tUInt4 || bt == Type.tURange)
    return Type.tInt64 if (bt == Type.tRange64)
    return Type.tUInt64 if (bt == Type.tURange64)
    return Type.tVoid
}

def getVectorOffset(bt : Type; ident : string) {
    
    var ofs = -1
    if (ident == "x" || ident == "X" || ident == "r" || ident == "R") {
        ofs = 0
    } elif (ident == "y" || ident == "Y" || ident == "g" || ident == "G") {
        ofs = 1
    } elif (ident == "z" || ident == "Z" || ident == "b" || ident == "B") {
        ofs = 2
    } elif (ident == "w" || ident == "W" || ident == "a" || ident == "A") {
        ofs = 3
    }
    let count = getVectorElementCount(bt)
    return ofs >= count ? -1 : ofs
}
