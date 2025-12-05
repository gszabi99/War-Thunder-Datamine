options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options no_aot = true
options strict_smart_pointers = true

module jobque_boost shared public

require jobque public

require daslib/rtti
require daslib/ast
require daslib/ast_boost
require daslib/templates
require daslib/macro_boost

[tag_function(new_job_tag)]
def new_job(var l : lambda) {
    
    
    
    
    
    invoke(l)   
}

[tag_function(new_job_tag)]
def new_thread(var l : lambda) {
    
    
    
    
    
    invoke(l)   
}

[tag_function_macro(tag="new_job_tag")]
class private NewJobMacro : AstFunctionAnnotation {
    
    
    
    def override transform(var call : smart_ptr<ExprCallFunc>; var errors : das_string) : ExpressionPtr {
        macro_verify(call.arguments[0] is ExprAscend, compiling_program(), call.at, "expecting lambda declaration, ExprAscend")
        var asc = call.arguments[0] as ExprAscend
        macro_verify(asc.subexpr is ExprMakeStruct, compiling_program(), call.at, "expecting lambda declaration, ExprMakeStruct")
        var mks = asc.subexpr as ExprMakeStruct
        macro_verify(!(mks._type == null || mks._type.baseType != Type.tStructure), compiling_program(), call.at, "expecting lambda declaration, not a structure")
        
        var inscope stype <- clone_structure(mks._type.structType)
        stype.name := "{stype.name}_new_job_clone"
        var stype_ptr = get_ptr(stype)
        var inscope sttype <- new TypeDecl(at = call.at, baseType = Type.tStructure, structType = stype_ptr)
        for (fld in stype.fields) {
            fld._type.flags &= ~(TypeDeclFlags.constant)
            fld.flags &= ~(FieldDeclarationFlags.capturedConstant)
        }
        var inscope pclone <- make_clone_structure(stype_ptr)
        let const_clone = pclone.arguments[1]._type.flags.constant
        compiling_module() |> add_function(pclone)
        compiling_module() |> add_structure(stype)
        
        var inscope ftype <- new TypeDecl(at = call.at, baseType = Type.tFunction)
        move_new(ftype.firstType) <| new TypeDecl(at = call.at, baseType = Type.tVoid)
        ftype.argTypes |> emplace_new <| clone_type(sttype)
        ftype.argTypes |> emplace <| sttype
        if (const_clone) {
            ftype.argTypes[1].flags |= TypeDeclFlags.constant
        }
        
        var inscope ncall <- new ExprCall(at = call.at, name := "{call.name}_invoke")
        ncall.arguments |> emplace_new <| clone_expression(call.arguments[0])
        ncall.arguments |> emplace_new <| new ExprAddr(at = call.at, target := "clone", funcType <- ftype)
        ncall.arguments |> emplace_new <| new ExprConstInt(at = call.at, value = int(mks._type.sizeOf))
        return <- ncall
    }
}

def gather(ch : Channel?; blk : block<(arg : auto(TT)#) : void>) {
    
    
    _builtin_channel_gather(ch) <| $(var data : void?) {
        invoke(blk, *(unsafe(reinterpret<TT?#> data)))
    }
}

def gather_ex(ch : Channel?; blk : block<(arg : auto(TT)#; info : TypeInfo const?; var ctx : Context) : void>) {
    
    
    _builtin_channel_gather_ex(ch) <| $(var data : void?; info : TypeInfo const?; var ctx : Context) {
        invoke(blk, *(unsafe(reinterpret<TT?#> data)), info, ctx)
    }
}

def gather_and_forward(ch, toCh : Channel?; blk : block<(arg : auto(TT)#) : void>) {
    
    
    _builtin_channel_gather_and_forward(ch, toCh) <| $(var data : void?) {
        invoke(blk, *(unsafe(reinterpret<TT?#> data)))
    }
}

def peek(ch : Channel?; blk : block<(arg : auto(TT)#) : void>) {
    
    
    _builtin_channel_peek(ch) <| $(var data : void?) {
        invoke(blk, *(unsafe(reinterpret<TT?#> data)))
    }
}


[deprecated(message="use `for_each_clone` instead")]
def for_each(channel : Channel?; blk : block<(res : auto(TT)#) : void>) {
    
    
    
    while (true) {
        var void_data : void?
        _builtin_channel_pop(channel) <| $(vd) {
            void_data = vd
        }
        if (void_data == null) {
            break
        }
        unsafe {
            let typed_data = reinterpret<TT?#> void_data
            invoke(blk, *typed_data)
        }
    }
}

def for_each_clone(channel : Channel?; blk : block<(res : auto(TT)#) : void>) {
    
    
    
    while (true) {
        var temp : TT -# -& -const
        var any = false
        _builtin_channel_pop(channel) <| $(vd) {
            if (vd != null) {
                any = true
                temp := *(unsafe(reinterpret<TT -# -& -const?#> vd))
            }
        }
        if (!any) {
            break
        }
        invoke(blk, unsafe(reinterpret<TT -& -const#> temp))
        delete temp
    }
}

[deprecated(message="use `pop_and_clone_one` instead")]
def pop_one(channel : Channel?; blk : block<(res : auto(TT)#) : void>) {
    
    var void_data : void?
    _builtin_channel_pop(channel) <| $(vd) {
        void_data = vd
    }
    if (void_data == null) {
        return false
    }
    unsafe {
        let typed_data = reinterpret<TT?#> void_data
        invoke(blk, *typed_data)
        return true
    }
}

def pop_and_clone_one(channel : Channel?; blk : block<(res : auto(TT)#) : void>) {
    
    var any = false
    var temp : TT -# -& -const
    _builtin_channel_pop(channel) <| $(vd) {
        if (vd != null) {
            any = true
            temp := *(unsafe(reinterpret<TT -# -& -const?#> vd))
        }
    }
    if (!any) {
        return false
    }
    invoke(blk, unsafe(reinterpret<TT -& -const#> temp))
    delete temp
    return true
}

def push_clone(channel : Channel?; data : auto(TT)) {
    
    var heap_data = new TT
    *heap_data := data
    _builtin_channel_push(channel, heap_data)
}

def push(channel : Channel?; data : auto?) {
    
    _builtin_channel_push(channel, data)
}

def push_batch_clone(channel : Channel?; data : array<auto(TT)>) {
    
    var heap_data : array<TT?>
    for (d in data) {
        var tt = new TT
        *tt := d
        heap_data |> push(tt)
    }
    _builtin_channel_push(channel, heap_data)
    heap_data |> resize(0)
    unsafe {
        delete heap_data
    }
}

def push_batch(channel : Channel?; data : array<auto?>) {
    
    _builtin_channel_push_batch(channel, data)
}

def set(box : LockBox?; data : auto(TT)) {
    
    var heap_data = new TT
    *heap_data := data
    _builtin_lockbox_set(box, heap_data)
}

def set(box : LockBox?; data : auto?) {
    
    _builtin_lockbox_set(box, data)
}

def get(box : LockBox?; blk : block<(res : auto(TT)#) : void>) {
    
    var res = false
    _builtin_lockbox_get(box) <| $(void_data) {
        if (void_data != null) {
            let typed_data = unsafe(reinterpret<TT?#> void_data)
            invoke(blk, *typed_data)
            res = true
        }
    }
    return res
}

def update(box : LockBox?; blk : block<(var res : auto(TT)#) : void>) {
    
    _builtin_lockbox_update(box, unsafe(reinterpret<TypeInfo?>(typeinfo rtti_typeinfo(type<TT? -#>)))) <| $(var void_data : void?) {
        if (void_data != null) {
            var typed_data = unsafe(reinterpret<TT?#> void_data)
            invoke(blk, *typed_data)
            return void_data
        } else {
            var heap_data = new TT
            invoke(blk, *heap_data)
            return unsafe(reinterpret<void?> heap_data)
        }
    }
}

[template(type_)]
def clear(box : LockBox?; type_ : auto(TT)) {
    
    _builtin_lockbox_update(box, unsafe(reinterpret<TypeInfo?>(typeinfo rtti_typeinfo(type<TT? -#>)))) <| $(var void_data : void?) : void? {
        if (void_data != null) {
            var typed_data = unsafe(reinterpret<TT -const?> void_data)
            unsafe {
                delete typed_data
            }
        }
        return null
    }
}


[template(tinfo), deprecated(message="use `each_clone` instead")]
def each(var channel : Channel?; tinfo : auto(TT)) {
    
    
    
    unsafe {
        return <- generator<TT&#>() <| $() {
            while (true) {
                var void_data : void?
                _builtin_channel_pop(channel) <| $(vd) {
                    void_data = vd
                }
                if (void_data == null) {
                    break
                }
                unsafe {
                    yield *reinterpret<TT?#> void_data
                }
            }
            return false
        } finally {
            channel |> release
        }
    }
}

[unused_argument(tinfo)]
def each_clone(var channel : Channel?; tinfo : auto(TT)) {
    
    
    
    unsafe {
        return <- generator<TT&#>() <| $() {
            while (true) {
                var temp : TT -# -& -const
                var any = false
                _builtin_channel_pop(channel) <| $(vd) {
                    if (vd != null) {
                        any = true
                        temp := *(unsafe(reinterpret<TT -# -& -const?#> vd))
                    }
                }
                if (!any) {
                    break
                }
                yield unsafe(reinterpret<TT -& -const#> temp)
                delete temp
            }
            return false
        } finally {
            channel |> release
        }
    }
}

def public capture_jobque_channel(var ch : Channel?) : Channel? {
    
    ch |> add_ref
    return ch
}

def public capture_jobque_job_status(var js : JobStatus?) : JobStatus? {
    
    js |> add_ref
    return js
}

def public capture_jobque_lock_box(var js : LockBox?) : LockBox? {
    
    js |> add_ref
    return js
}

def public release_capture_jobque_channel(ch : Channel?) {
    
    if (ch != null) {
        panic("Channel has not been released. missing channel|>release or channel|>notify_and_release")
    }
}

def public release_capture_jobque_job_status(js : JobStatus?) {
    
    if (js != null) {
        panic("JobStatus has not been released. missing status|>release or status|>notify_and_release")
    }
}

def public release_capture_jobque_lock_box(js : LockBox?) {
    
    if (js != null) {
        panic("LockBox has not been released. missing status|>release or status|>notify_and_release")
    }
}


[macro_function]
def private isPtrToJQ(typ : TypeDeclPtr; jqt : string) : bool {
    if (!typ.isPointer) {
        return false
    }
    if (typ.firstType == null) {
        return false
    }
    if (!typ.firstType.isHandle) {
        return false
    }
    if (typ.firstType.annotation._module.name != "jobque") {
        return false
    }
    if (typ.firstType.annotation.name != jqt) {
        return false
    }
    return true
}

[capture_macro(name=channel_and_status_capture_macro)]
class private ChannelAndStatusCapture : AstCaptureMacro {
    def make_capture_call(expr : ExpressionPtr; name : string) : ExpressionPtr {
        var inscope pCall <- new ExprCall(at = expr.at, name := name)
        pCall.arguments |> emplace_new <| clone_expression(expr)
        return <- pCall
    }
    def make_release_call(fld : FieldDeclaration; name : string) : ExpressionPtr {
        var inscope pCall <- new ExprCall(at = fld.at, name := name)
        pCall.arguments |> emplace_new <| new ExprField(at = fld.at,
            value <- new ExprVar(at = fld.at, name := "__this"),
            name := fld.name,
            derefFlags = ExprFieldDerefFlags.ignoreCaptureConst
        )
        return <- pCall
    }
        
    
    def override captureExpression(prog : Program?; mod : Module?; expr : ExpressionPtr; typ : TypeDeclPtr) : ExpressionPtr {
        
        if (typ |> isPtrToJQ("Channel")) {
            return <- make_capture_call(expr, "jobque_boost::capture_jobque_channel")
        } elif (typ |> isPtrToJQ("JobStatus")) {
            return <- make_capture_call(expr, "jobque_boost::capture_jobque_job_status")
        } elif (typ |> isPtrToJQ("LockBox")) {
            return <- make_capture_call(expr, "jobque_boost::capture_jobque_lock_box")
        }
        return <- default<ExpressionPtr>
    }
    def override captureFunction(prog : Program?; mod : Module?; var lcs : Structure?; var fun : FunctionPtr) : void {
        
        if (fun.flags._generator) {
            return
        }
        for (fld in lcs.fields) {
            if (fld._type |> isPtrToJQ("Channel")) {
                var inscope pCall <- make_release_call(fld, "jobque_boost::release_capture_jobque_channel")
                (fun.body as ExprBlock).finalList |> emplace(pCall)
            } elif (fld._type |> isPtrToJQ("JobStatus")) {
                var inscope pCall <- make_release_call(fld, "jobque_boost::release_capture_jobque_job_status")
                (fun.body as ExprBlock).finalList |> emplace(pCall)
            } elif (fld._type |> isPtrToJQ("LockBox")) {
                var inscope pCall <- make_release_call(fld, "jobque_boost::release_capture_jobque_lock_box")
                (fun.body as ExprBlock).finalList |> emplace(pCall)
            }
        }
    }
}


