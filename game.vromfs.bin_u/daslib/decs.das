options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options multiple_contexts
options strict_smart_pointers = true

module decs shared public

require daslib/templates

require daslib/rtti public
require daslib/algorithm

require daslib/functional
require daslib/archive public
require daslib/contracts
require math
require strings
require daslib/defer

typedef ComponentHash = uint64  
typedef TypeHash = uint64       

struct CTypeInfo {
    
    
    basicType : Type
    mangledName : string
    fullName : string
    hash : TypeHash
    size : uint
    eraser     : function<(var arr : array<uint8>) : void>
    clonner    : function<(var dst : array<uint8>; src : array<uint8>) : void>
    serializer : function<(var arch : Archive; var arr : array<uint8>; name : string) : void>
    dumper     : function<(elem : void?) : string>
    mkTypeInfo : function<() : TypeInfo const?>
    gc         : function<(var src : array<uint8>) : lambda>
}

struct public Component {
    
    name : string
    hash : ComponentHash
    stride : int
    data : array<uint8>
    info : CTypeInfo
    gc_dummy : lambda           
}

struct public EntityId {
    
    id : uint
    generation : int
}

struct public Archetype {
    
    hash : ComponentHash
    components : array<Component>
    size : int
    eidIndex : int
}

struct public ComponentValue {
    
    name : string
    info : CTypeInfo
    data : float4[4]
}

typedef DeferEval = lambda<(var act : DeferAction) : void>

struct private DeferAction {
    eid : EntityId
    action : DeferEval
}

typedef ComponentMap = array<ComponentValue> 

struct EcsRequestPos {
    
    file : string
    line : uint
}

def EcsRequestPos(at : rtti::LineInfo) : EcsRequestPos {
    
    return EcsRequestPos(file = at.fileInfo != null ? string(at.fileInfo.name) : "", line = at.line)
}

struct public EcsRequest {
    
    
    hash : ComponentHash
    req : array<string>
    reqn : array<string>
    archetypes : array<int>     
    at : EcsRequestPos
}

struct public DecsState {
    
    
    archetypeLookup : table<ComponentHash; int>
    allArchetypes : array<Archetype>
    entityFreeList : array<EntityId>
    entityLookup : array<tuple<generation : int; archetype : ComponentHash; index : int>>
    componentTypeCheck : table<string; CTypeInfo>
    ecsQueries : array<EcsRequest>
    queryLookup : table<ComponentHash; int>
}

typedef PassFunction = function<() : void>  

struct public DecsPass {
    
    
    name : string
    calls : array<PassFunction>
}

var public decsState : DecsState    
var private deferActions : array<DeferAction>
var private decsPasses : array<DecsPass>
var private insideQuery : int

let INVALID_ENTITY_ID = decs::EntityId()  

def operator ==(a, b : decs::EntityId implicit) {
    
    return a.id == b.id && a.generation == b.generation
}

def operator !=(a, b : decs::EntityId implicit) {
    
    return a.id != b.id || a.generation != b.generation
}

def public describe(info : CTypeInfo) {
    
    return "{info.fullName} {info.basicType} MNH={info.mangledName} hash={info.hash} size={info.size}"
}

def public operator .(var cmp : ComponentMap; name : string) : ComponentValue& {
    
    
    
    
    let idx = lower_bound(cmp, ComponentValue(name = name)) <| $(x, y) => x.name < y.name
    if (!(idx < length(cmp) && cmp[idx].name == name)) {
        cmp |> push(ComponentValue(name = name), idx)
    }
    unsafe {
        return cmp[idx]
    }
}

def public set(var cv : ComponentValue; val : auto) {
    
    var cval = make_component(cv.name, val)
    assert(cv.info.hash == 0ul || cv.info.hash == cval.info.hash)
    cv = cval
}

def public operator :=(var cv : ComponentValue; val : EntityId)    { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : bool)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : range)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : urange)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : range64)     { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : urange64)    { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : string)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int)         { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int8)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int16)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int64)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int2)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int3)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : int4)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint)        { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint8)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint16)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint64)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint2)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint3)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : uint4)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float)       { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float2)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float3)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float4)      { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float3x3)    { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float3x4)    { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : float4x4)    { set(cv, val); }
def public operator :=(var cv : ComponentValue; val : double)      { set(cv, val); }

def public clone(var dst : Component; src : Component) {
    
    dst.name := src.name
    dst.hash = src.hash
    dst.stride = src.stride
    dst.info := src.info
    if (src.info.clonner != null) {
        invoke(src.info.clonner, dst.data, src.data)
    } else {
        dst.data := src.data
    }
}

def public serialize(var arch : Archive; var src : Component) {
    
    arch |> serialize(src.name)
    arch |> serialize(src.hash)
    arch |> serialize(src.stride)
    arch |> serialize(src.info)
    if (src.info.serializer != null) {
        invoke(src.info.serializer, arch, src.data, src.name)
    } else {
        panic("decs: unable to serialize component '{src.name}'")
    }
}

def public register_decs_stage_call(name : string; pcall : PassFunction) {
    
    var dpass <- DecsPass(name = name)
    let idx = lower_bound(decsPasses, dpass) <| $(x, y) => x.name < y.name
    if (idx < length(decsPasses) && decsPasses[idx].name == name) {
        decsPasses[idx].calls |> push(pcall)
    } else {
        dpass.calls |> push(pcall)
        decsPasses |> emplace(dpass, idx)    
    }
}

def public decs_stage(name : string) {
    
    
    commit()
    let idx = lower_bound(decsPasses, DecsPass(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(decsPasses) && decsPasses[idx].name == name) {
        for (cll in decsPasses[idx].calls) {
            invoke(cll)
        }
    }
    commit()
}

def operator delete(var cmp : Component) {
    
    if (cmp.info.eraser != null) {
        invoke(cmp.info.eraser, cmp.data)
    }
    delete cmp.data
    delete cmp.info
}

def public restart {
    
    if (insideQuery != 0) {
        panic("decs: can't call `restart` from inside query")
    }
    delete deferActions
    delete decsState
}

def private new_entity_id() {
    var eid : EntityId
    if (!empty(decsState.entityFreeList)) {
        eid = decsState.entityFreeList[length(decsState.entityFreeList) - 1]
        decsState.entityFreeList |> pop
    } else {
        eid.id = uint(length(decsState.entityLookup))
        decsState.entityLookup |> push((0, 0ul, 0))
    }
    eid.generation ++
    return eid
}

def public before_gc {
    
    
    if (insideQuery != 0) {
        panic("decs: can't call 'before_gc' from inside query")
    }
    for (arch in decsState.allArchetypes) {
        if (arch.size > 0) {
            for (comp in arch.components) {
                if (comp.info.gc != null) {
                    comp.gc_dummy <- invoke(comp.info.gc, comp.data)
                }
            }
        }
    }
}

def public after_gc {
    
    
    if (insideQuery != 0) {
        panic("decs: can't call 'after_gc' from inside query")
    }
    for (arch in decsState.allArchetypes) {
        if (arch.size > 0) {
            for (comp in arch.components) {
                if (comp.gc_dummy != null) {
                    delete comp.gc_dummy
                }
            }
        }
    }
}

def public debug_dump {
    
    for (arch in decsState.allArchetypes) {
        to_log(LOG_DEBUG, "archtype {arch.hash} : {arch.size}\n")
        
        for (index in range(arch.size)) {
            to_log(LOG_DEBUG, "\tentity[{index}]\n")
            for (c in arch.components) {
                if (c.info.dumper != null) {
                    let dump = build_string() <| $(wr) {
                        for (x in range(arch.size)) {
                            if (x != 0) {
                                wr |> write(", ")
                            }
                            let offset = x * c.stride
                            unsafe {
                                let txt = invoke(c.info.dumper, addr(c.data[offset]))
                                wr |> write(txt)
                            }
                        }
                    }
                    to_log(LOG_DEBUG, "\t\t{c.name} : {describe(c.info)}\n\t\t\t{dump}\n")
                } else {
                    to_log(LOG_DEBUG, "\t\t{c.name} : {describe(c.info)}\n")
                }
            }
        }
    }
    for (erq in decsState.ecsQueries) {
        to_log(LOG_DEBUG, "query {erq.hash}\n")
        to_log(LOG_DEBUG, "\treq = {erq.req}\n\treqn = {erq.reqn}\n\tarchetypes = {erq.archetypes}\nat = {erq.at.file}:{int(erq.at.line)}\n")
    }
}

def private with_archetype(hash : ComponentHash; blk : block<(var arch : Archetype; idx : int; isNew : bool) : void>) {
    var afound & = unsafe(decsState.archetypeLookup[hash])
    if (afound == 0) {
        decsState.allArchetypes |> emplace(Archetype(hash = hash))
        afound = length(decsState.allArchetypes)
        ++insideQuery; invoke(blk, decsState.allArchetypes[afound - 1], afound - 1, true); --insideQuery
    } else {
        ++insideQuery; invoke(blk, decsState.allArchetypes[afound - 1], afound - 1, false); --insideQuery
    }
}

def private create_archetype(var arch : Archetype; cmp : ComponentMap; idx : int) {
    assert(length(arch.components) == 0)
    arch.eidIndex = -1
    for (kv, kvi in cmp, count()) {
        var ct & = unsafe(decsState.componentTypeCheck[kv.name])
        if (ct.hash != 0ul) {
            if (kv.info.hash != ct.hash) {
                panic("decs: component {kv.name} type mismatch {ct} vs {kv.info}")
            }
        } else {
            ct = kv.info
        }
        let chash = hash(kv.name)
        arch.components |> emplace <| Component(
            name = kv.name,
            hash = chash,
            stride = int(kv.info.size),
            info = kv.info
        )
        if (kv.name == "eid") {
            assert(arch.eidIndex == -1)
            arch.eidIndex = kvi
        }
    }
    assert(arch.eidIndex != -1)
    for (erq in decsState.ecsQueries) {
        if (erq |> can_process_request(arch)) {
            erq.archetypes |> push(idx)
        }
    }
}

def private get_eid(var arch : Archetype; index : int) : EntityId& {
    unsafe {
        var ceid & = arch.components[arch.eidIndex]
        return *(reinterpret<EntityId?> addr(ceid.data[index * ceid.stride]))
    }
}

def private create_entity(var arch : Archetype; eid : EntityId; cmp : ComponentMap) {
    let eidx = arch.size++
    for (c, comp in arch.components, cmp) {
        c.data |> resize(length(c.data) + c.stride)
        unsafe {
            memcpy(addr(c.data[eidx * c.stride]), addr(comp.data), c.stride)
        }
    }
    return eidx
}

def private remove_entity(var arch : Archetype; di : int) {
    arch.size --
    if (di != arch.size) {
        var eid_last_id = get_eid(arch, arch.size).id
        decsState.entityLookup[eid_last_id].index = di
        for (c in arch.components) {
            unsafe {
                memcpy(addr(c.data[di * c.stride]), addr(c.data[arch.size * c.stride]), c.stride)
            }
        }
    }
    for (c in arch.components) {
        c.data |> resize(arch.size * c.stride)
    }
}

def private cmp_archetype_hash(cmp : ComponentMap) {
    var ahash : ComponentHash
    for (kv in cmp) {
        ahash = (ahash <<< 2ul) ^ hash(kv.name)
    }
    return ahash
}

def private req_hash(erq : EcsRequest) {
    var ahash : ComponentHash
    for (kv in erq.req) {
        ahash = (ahash <<< 2ul) ^ hash(kv)
    }
    for (kv in erq.reqn) {
        ahash = (ahash <<< 2ul) ^ ~hash(kv)
    }
    return ahash
}

def public has(arch : Archetype; name : string) {
    
    return arch.components |> binary_search(Component(name = name)) <| $(x, y) => x.name < y.name
}

def private can_process_request(var erq : EcsRequest; var arch : Archetype) {
    if (erq.hash == arch.hash) {
        return true
    }
    for (r in erq.req) {
        if (!arch |> has(r)) {
            return false
        }
    }
    for (r in erq.reqn) {
        if (arch |> has(r)) {
            return false
        }
    }
    return true
}

def public verify_request(var erq : EcsRequest) : tuple<ok : bool; error : string> {
    
    if (erq.hash == 0ul || (empty(erq.req) && empty(erq.reqn))) {
        return (true, "")     
    }
    for (N in erq.reqn) {
        if (erq.req |> binary_search(N)) {
            return (false, "duplicate req and neq {N}")
        }
    }
    return (true, "")
}

def public compile_request(var erq : EcsRequest) {
    
    sort_unique(erq.req)
    sort_unique(erq.reqn)
    erq.hash = req_hash(erq)
}

def public lookup_request(var erq : EcsRequest) {
    
    if (erq.hash == 0ul) {
        compile_request(erq)
    }
    var ql & = unsafe(decsState.queryLookup[erq.hash])
    if (ql == 0) {
        for (arch, archi in decsState.allArchetypes, count()) {
            if (erq |> can_process_request(arch)) {
                erq.archetypes |> push(archi)
            }
        }
        decsState.ecsQueries |> push_clone(erq)
        ql = length(decsState.ecsQueries)
    }
    return ql - 1
}

def public for_each_archetype(var erq : EcsRequest; blk : block<(arch : Archetype) : void>) {
    
    let qi = lookup_request(erq)
    var inscope aclone := decsState.ecsQueries[qi].archetypes
    for (aidx in aclone) {
        var arch & = unsafe(decsState.allArchetypes[aidx])
        if (arch.size > 0) {
            ++insideQuery; invoke(blk, arch); --insideQuery
        }
    }
}

def public for_eid_archetype(eid : EntityId implicit; hash : ComponentHash; var erq : function<() : EcsRequest>; blk : block<(arch : Archetype; index : int) : void>) {
    
    
    var lookup = decsState.entityLookup[eid.id]
    if (lookup.generation != eid.generation) {
        return false
    }
    var qi = -1
    decsState.queryLookup |> get(hash) <| $(ql) {
        qi = ql - 1
    }
    if (qi == -1) {
        qi = lookup_request(invoke(erq))
    }
    let aidx = decsState.archetypeLookup[lookup.archetype]
    if (aidx == 0) {
        return false
    }
    if (binary_search(decsState.ecsQueries[qi].archetypes, aidx - 1)) {
        var arch & = unsafe(decsState.allArchetypes[aidx - 1])
        assert(arch.size > 0)
        ++insideQuery; invoke(blk, arch, lookup.index); -- insideQuery
        return true
    } else {
        return false
    }
}

def public for_each_archetype(hash : ComponentHash; var erq : function<() : EcsRequest>; blk : block<(arch : Archetype) : void>) {
    
    
    var qi = -1
    decsState.queryLookup |> get(hash) <| $(ql) {
        qi = ql - 1
    }
    if (qi == -1) {
        qi = lookup_request(invoke(erq))
    }
    var inscope aclone := decsState.ecsQueries[qi].archetypes
    for (aidx in aclone) {
        var arch & = unsafe(decsState.allArchetypes[aidx])
        if (arch.size > 0) {
            ++insideQuery; invoke(blk, arch); --insideQuery
        }
    }
}

def public for_each_archetype_find(hash : ComponentHash; var erq : function<() : EcsRequest>; blk : block<(arch : Archetype) : bool>) {
    
    
    
    var qi = -1
    decsState.queryLookup |> get(hash) <| $(ql) {
        qi = ql - 1
    }
    if (qi == -1) {
        qi = lookup_request(invoke(erq))
    }
    var inscope aclone := decsState.ecsQueries[qi].archetypes
    for (aidx in aclone) {
        var arch & = unsafe(decsState.allArchetypes[aidx])
        if (arch.size > 0) {
            ++insideQuery; let res = invoke(blk, arch); --insideQuery
            if (res) {
                return true
            }
        }
    }
    return false
}


def decs_array(atype : auto(TT); src : array<uint8>; capacity : int) {
    
    assert(length(src) > 0)
    static_if (typeinfo is_dim(atype)) {
        var dest : array<TT[typeinfo dim(atype)] -const -& -#>
        unsafe {
            _builtin_make_temp_array(dest, addr(src[0]), capacity)
            return <- dest
        }
    } else {
        var dest : array<TT -const -& -#>
        unsafe {
            _builtin_make_temp_array(dest, addr(src[0]), capacity)
            return <- dest
        }
    }
}

def public get(arch : Archetype; name : string; value : auto(TT)) {
    
    
    let idx = arch.components |> lower_bound(Component(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(arch.components)) {
        let comp & = unsafe(arch.components[idx])
        if (comp.name == name) {
            unsafe {
                var cvinfo : TypeInfo const?
                static_if (typeinfo is_dim(value)) {
                    cvinfo  = addr(typeinfo rtti_typeinfo(type<TT[typeinfo dim(value)] -const -& -#>))
                } else {
                    cvinfo  = addr(typeinfo rtti_typeinfo(type<TT -const -& -#>))
                }
                if (comp.info.hash != cvinfo.hash) {
                    panic("decs: component array {name} type mismatch, expecting {describe(comp.info)} vs {describe(cvinfo)} MNH={get_mangled_name(cvinfo)} hash={cvinfo.hash} size={cvinfo.size}")
                }
                static_if (typeinfo is_dim(value)) {
                    return <- decs_array(type<TT[typeinfo dim(value)]>, comp.data, arch.size)
                } else {
                    return <- decs_array(type<TT>, comp.data, arch.size)
                }
            }
        }
    }
    panic("decs: component array {name} not found")
    unsafe {
        static_if (typeinfo is_dim(value)) {
            return <- array<TT[typeinfo dim(value)] -const -& -#>()
        } else {
            return <- array<TT -const -& -#>()
        }
    }
}

[expect_dim(value)]
def public get_ro(arch : Archetype; name : string; value : auto(TT)[]) : array<TT[typeinfo sizeof(value)] -const -& -#> const {
    
    unsafe {
        return <- get(arch, name, value)
    }
}

[!expect_dim(value)]
def public get_ro(arch : Archetype; name : string; value : auto(TT)) : array<TT -const -& -#> const {
    
    unsafe {
        return <- get(arch, name, value)
    }
}

def public get_default_ro(arch : Archetype; name : string; value : auto(TT)) : iterator<TT const&> {
    
    
    let idx = arch.components |> lower_bound(Component(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(arch.components)) {
        let comp & = unsafe(arch.components[idx])
        if (comp.name == name) {
            unsafe {
                var cvinfo : TypeInfo const?
                static_if (typeinfo is_dim(value)) {
                    cvinfo  = addr(typeinfo rtti_typeinfo(type<TT[typeinfo dim(value)] -const -& -#>))
                } else {
                    cvinfo  = addr(typeinfo rtti_typeinfo(type<TT -const -& -#>))
                }
                if (comp.info.hash != cvinfo.hash) {
                    panic("decs: component array {name} type mismatch, expecting {describe(comp.info)} vs {describe(cvinfo)} MNH={get_mangled_name(cvinfo)} hash={cvinfo.hash} size={cvinfo.size}")
                }
                static_if (typeinfo is_dim(value)) {
                    var it : iterator<TT[typeinfo dim(value)] const&>
                    _builtin_make_fixed_array_iterator(it, addr(comp.data[0]), arch.size, comp.stride)
                    return <- it
                } else {
                    var it : iterator<TT const&>
                    _builtin_make_fixed_array_iterator(it, addr(comp.data[0]), arch.size, comp.stride)
                    return <- it
                }
            }
        }
    }
    return <- repeat_ref(value, arch.size)
}

def public get_optional(arch : Archetype; name : string; value : auto(TT)?) : iterator<TT -const -& -#?> {
    
    
    let idx = arch.components |> lower_bound(Component(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(arch.components)) {
        let comp & = unsafe(arch.components[idx])
        if (comp.name == name) {
            unsafe {
                let cvinfo = addr(typeinfo rtti_typeinfo(type<TT -const -& -#>))
                if (comp.info.hash != cvinfo.hash) {
                    panic("decs: component array {name} type mismatch, expecting {describe(comp.info)} vs {describe(cvinfo)} MNH={get_mangled_name(cvinfo)} hash={cvinfo.hash} size={cvinfo.size}")
                }
            }
            var it : iterator<TT -const -& -#?>
            unsafe {
                _builtin_make_fixed_array_iterator(it, addr(comp.data[0]), arch.size, comp.stride)
            }
            return <- it
        }
    }
    return <- repeat(default<TT -const -& -#?>, arch.size)
}

def private update_entity_imm(eid : EntityId; blk : lambda<(eid : EntityId; var cmp : ComponentMap) : void>) {
    var lookup = decsState.entityLookup[eid.id]
    if (lookup.generation != eid.generation) {
        return
    }
    var cmp : ComponentMap
    let arch_index = unsafe(decsState.archetypeLookup[lookup.archetype]) - 1
    let eidx = decsState.entityLookup[eid.id].index
    var old_ahash = 0ul
    if (true) {
        var arch & = unsafe(decsState.allArchetypes[arch_index])
        cmp |> reserve(length(arch.components))
        for (c in arch.components) {
            var value = ComponentValue(name = c.name, info = c.info)
            unsafe {
                memcpy(addr(value.data), addr(c.data[eidx * c.stride]), c.stride)
            }
            cmp |> push(value)
        }
        old_ahash = arch.hash
    }
    invoke(blk, eid, cmp)
    cmp |> set("eid", eid)  
    var new_ahash = cmp_archetype_hash(cmp)
    if (old_ahash == new_ahash) {
        for (c, comp in decsState.allArchetypes[arch_index].components, cmp) {
            unsafe {
                memcpy(addr(c.data[eidx * c.stride]), addr(comp.data), c.stride)
            }
        }
    } else {
        remove_entity(decsState.allArchetypes[arch_index], eidx)
        with_archetype(new_ahash) <| $(var narch; idx; isNew) {
            if (isNew) {
                narch |> create_archetype(cmp, idx)
            }
            let neidx = narch |> create_entity(eid, cmp)
            decsState.entityLookup[eid.id] =  (eid.generation, new_ahash, neidx)
        }
    }
    delete cmp
}

def private create_entity_imm(eid : EntityId; blk : lambda<(eid : EntityId; var cmp : ComponentMap) : void>) {
    var cmp : ComponentMap
    cmp |> push <| make_component("eid", eid)
    invoke(blk, eid, cmp)
    cmp |> set("eid", eid)       
    var ahash = cmp_archetype_hash(cmp)
    with_archetype(ahash) <| $(var arch; idx; isNew) {
        if (isNew) {
            arch |> create_archetype(cmp, idx)
        }
        let eidx = arch |> create_entity(eid, cmp)
        decsState.entityLookup[eid.id] =  (eid.generation, ahash, eidx)
    }
    delete cmp
}

def private delete_entity_imm(eid : EntityId) {
    var lookup = decsState.entityLookup[eid.id]
    if (lookup.generation == eid.generation) {
        let di = decsState.entityLookup[eid.id].index
        decsState.entityLookup[eid.id].generation = 0
        decsState.entityFreeList |> push(eid)
        remove_entity(decsState.allArchetypes[unsafe(decsState.archetypeLookup[lookup.archetype]) - 1], di)
    }
}

def public update_entity(entityid : EntityId implicit; var blk : lambda<(eid : EntityId; var cmp : ComponentMap) : void>) {
    
    var deval <- @  capture(<- blk) (var act : DeferAction) {
        update_entity_imm(act.eid, blk)
    }
    deferActions |> emplace(DeferAction(action <- deval, eid = entityid))
}

def public create_entity(var blk : lambda<(eid : EntityId; var cmp : ComponentMap) : void>) {
    
    var deval <- @  capture(<- blk) (var act : DeferAction) {
        create_entity_imm(act.eid, blk)
    }
    var eid = new_entity_id()
    deferActions |> emplace(DeferAction(action <- deval, eid = eid))
    return eid
}

def public delete_entity(entityid : EntityId implicit) {
    
    var deval <- @(var act : DeferAction) {
        delete_entity_imm(act.eid)
    }
    deferActions |> emplace(DeferAction(action <- deval, eid = entityid))
}

def public commit {
    
    if (insideQuery != 0) {
        panic("decs: can't call `commit` from inside query")
    }
    var actions <- deferActions
    for (da in actions) {
        da.action |> invoke(da)
    }
    delete actions
}

def public get(var cmp : ComponentMap; name : string; var value : auto(TT)) {
    
    
    let idx = lower_bound(cmp, ComponentValue(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(cmp) && cmp[idx].name == name) {
        unsafe {
            var cvinfo : TypeInfo const?
            static_if (typeinfo is_dim(value)) {
                cvinfo = addr(typeinfo rtti_typeinfo(type<TT[typeinfo dim(value)] -const -& -#>))
            } else {
                cvinfo = addr(typeinfo rtti_typeinfo(type<TT -const -& -#>))
            }
            if (cmp[idx].info.hash != cvinfo.hash) {
                panic("decs: get component {name} type mismatch, expecting {describe(cmp[idx].info)} vs {describe(cvinfo)} MNH={get_mangled_name(cvinfo)} hash={cvinfo.hash} size={cvinfo.size}")
            }
            memcpy(addr(value), addr(cmp[idx].data), typeinfo sizeof(type<TT const -&>))
        }
    }
    return value
}

def private make_callbacks(var cv : ComponentValue; value : auto(TT)) {
    cv.info.mkTypeInfo = @@() : TypeInfo const? {
        static_if (typeinfo is_dim(value)) {
            return unsafe(addr(typeinfo rtti_typeinfo(type<array<TT[typeinfo dim(value)] -const -& -#>>)))
        } else {
            return unsafe(addr(typeinfo rtti_typeinfo(type<array<TT -const -& -#>>)))
        }
    }
    cv.info.dumper = @@(elem : void?) {
        if (elem == null) {
            return ""
        }
        unsafe {
            static_if (typeinfo is_dim(value)) {
                var pTT = reinterpret<TT[typeinfo dim(value)] -const -& -#?> elem
                return "{*pTT}"
            } else {
                var pTT = reinterpret<TT -const -& -#?> elem
                return "{*pTT}"
            }
        }
    }
    cv.info.gc = @@(var src : array<uint8>) : lambda {
        
        
        
        
        static_if (typeinfo is_dim(value)) {
            var gc_dummy : array<TT[typeinfo dim(value)] -const -& -#>
            let stride = typeinfo sizeof(type<TT[typeinfo dim(value)] -const -& -#>)
            let size = length(src) / stride
            unsafe {
                _builtin_make_temp_array(gc_dummy, addr(src[0]), size)
            }
            var lmb <- @  capture(<- gc_dummy) {
                pass
            } finally {
                memzero(gc_dummy)
            }
            return <- lmb
        } else {
            var gc_dummy : array<TT -const -& -#>
            let stride = typeinfo sizeof(type<TT -const -& -#>)
            let size = length(src) / stride
            unsafe {
                _builtin_make_temp_array(gc_dummy, addr(src[0]), size)
            }
            var lmb <- @  capture(<- gc_dummy) {
                pass
            } finally {
                memzero(gc_dummy)
            }
            return <- lmb
        }
    }
    cv.info.clonner = @@(var dst : array<uint8>; src : array<uint8>) {
        if (length(src) == 0) {
            return
        }
        static_if (typeinfo is_dim(value)) {
            let stride = typeinfo sizeof(type<TT[typeinfo dim(value)] -const -& -#>)
            dst |> resize(length(src))
            let size = length(src) / stride
            var dsrc, ssrc : array<TT[typeinfo dim(value)] -const -& -#>
            unsafe {
                _builtin_make_temp_array(dsrc, addr(dst[0]), size)
                _builtin_make_temp_array(ssrc, addr(src[0]), size)
            }
            for (d, s in dsrc, ssrc) {
                d := s
            }
        } else {
            let stride = typeinfo sizeof(type<TT -const -& -#>)
            dst |> resize(length(src))
            let size = length(src) / stride
            var dsrc, ssrc : array<TT -const -& -#>
            unsafe {
                _builtin_make_temp_array(dsrc, addr(dst[0]), size)
                _builtin_make_temp_array(ssrc, addr(src[0]), size)
            }
            for (d, s in dsrc, ssrc) {
                d := s
            }
        }
    }
    cv.info.serializer = @@(var arch : Archive; var src : array<uint8>; name : string) {
        static_if (typeinfo is_dim(value)) {
            var stride = typeinfo sizeof(type<TT[typeinfo dim(value)] -const -& -#>)
            if (arch.reading) {
                var wasStride : int
                arch |> _::serialize(wasStride)
                if (wasStride != stride) {
                    panic("decs: component '{name}' stride mismatch, expecting {stride}, got {wasStride}")
                } else {
                    var temp : array<TT[typeinfo dim(value)] -const -& -#>
                    arch |> _::serialize(temp)
                    let size = length(temp)
                    src |> resize(size * stride)
                    if (size > 0) {
                        unsafe {
                            memcpy(addr(src[0]), addr(temp[0]), size * stride)
                        }
                    }
                }
            } else {
                arch |> _::serialize(stride)
                var ssrc : array<TT -const -& -#>
                let size = length(src) / stride
                unsafe {
                    if (length(src) > 0) {
                        _builtin_make_temp_array(ssrc, addr(src[0]), size)
                    }
                }
                arch |> serialize(ssrc)
            }
        } else {
            var stride : int = typeinfo sizeof(type<TT -const -& -#>)
            if (arch.reading) {
                var wasStride : int
                arch |> _::serialize(wasStride)
                if (wasStride != stride) {
                    panic("decs: component '{name}' stride mismatch, expecting {stride}, got {wasStride}")
                } else {
                    var temp : array<TT -const -& -#>
                    arch |> _::serialize(temp)
                    let size = length(temp)
                    src |> resize(size * stride)
                    if (size > 0) {
                        unsafe {
                            memcpy(addr(src[0]), addr(temp[0]), size * stride)
                        }
                    }
                }
            } else {
                arch |> _::serialize(stride)
                var ssrc : array<TT -const -& -#>
                let size = length(src) / stride
                unsafe {
                    if (length(src) > 0) {
                        _builtin_make_temp_array(ssrc, addr(src[0]), size)
                    }
                }
                arch |> serialize(ssrc)
            }
        }
    }
    static_if (typeinfo can_delete(type<TT -const -& -#>)) {
        cv.info.eraser = @@(var arr : array<uint8>) {
            if (length(arr) == 0) {
                return
            }
            static_if (typeinfo is_dim(value)) {
                let stride = typeinfo sizeof(type<TT[typeinfo dim(value)] -const -& -#>)
                for (i in range(length(arr) / stride)) {
                    let offset = i * stride
                    unsafe {
                        var adel = reinterpret<TT[typeinfo dim(value)] -const -& -#?> addr(arr[offset])
                        delete * adel
                    }
                }
            } else {
                let stride = typeinfo sizeof(type<TT -const -& -#>)
                for (i in range(length(arr) / stride)) {
                    let offset = i * stride
                    unsafe {
                        var adel = reinterpret<TT -const -& -#?> addr(arr[offset])
                        delete * adel
                    }
                }
            }
        }
    }
}

def private make_component(name : string; value : auto(TT)) {
    var cv = ComponentValue(name = name)
    unsafe {
        var tinfo : TypeInfo const?
        var tname : string
        static_if (typeinfo is_dim(value)) {
            tinfo = addr(typeinfo rtti_typeinfo(type<TT[typeinfo dim(value)] -const -& -#>))
            tname = typeinfo fulltypename(type<TT[typeinfo dim(value)] -const -& -#>)
        } else {
            tinfo = addr(typeinfo rtti_typeinfo(type<TT -const -& -#>))
            tname = typeinfo fulltypename(type<TT -const -& -#>)
        }
        cv.info = CTypeInfo(basicType = tinfo.basicType, mangledName = get_mangled_name(tinfo),
            fullName = tname, hash = tinfo.hash, size = tinfo.size)
        make_callbacks(cv, value)
        memcpy(addr(cv.data), addr(value), typeinfo sizeof(value))
    }
    return cv
}

def public set(var cmp : ComponentMap; name : string; value : auto(TT)) {
    
    
    concept_assert(typeinfo sizeof(value) <= typeinfo sizeof(cmp[0].data), "unsupported component type {typeinfo typename(value)} (its too big)")
    let cv = make_component(name, value)
    let idx = lower_bound(cmp, ComponentValue(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(cmp) && cmp[idx].name == name) {
        if (cmp[idx].info.hash != cv.info.hash) {
            panic("decs: set component {name} type mismatch, expecting {describe(cmp[idx].info)} vs vs {describe(cv.info)} MNH={cv.info.mangledName} hash={cv.info.hash} size={cv.info.size}")
        }
        cmp[idx] = cv           
    } else {
        cmp |> push(cv, idx)    
    }
}

def public has(var cmp : ComponentMap; name : string) {
    return binary_search(cmp, ComponentValue(name = name)) <| $(x, y) => x.name < y.name
}

def public remove(var cmp : ComponentMap; name : string) {
    
    let idx = lower_bound(cmp, ComponentValue(name = name)) <| $(x, y) => x.name < y.name
    if (idx < length(cmp) && cmp[idx].name == name) {
        cmp |> erase(idx)
    }
}

