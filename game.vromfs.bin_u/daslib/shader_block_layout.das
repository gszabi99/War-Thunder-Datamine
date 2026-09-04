options gen2








module shader_block_layout shared public

require math
require daslib/ast




def public matrix_info(t : TypeDecl?) : tuple<ok : bool; width : int; cols : int> {
    if (t == null || t.baseType != Type.tHandle || t.annotation == null) return (ok = false, width = 0, cols = 0)
    let nm = "{t.annotation.name}"
    if (nm == "float4x4") return (ok = true, width = 4, cols = 4)
    if (nm == "float3x3") return (ok = true, width = 3, cols = 3)
    if (nm == "float3x4") return (ok = true, width = 3, cols = 4)
    return (ok = false, width = 0, cols = 0)
}




def public value_base_type(t : TypeDecl?) : Type {
    if (t == null) return Type.none
    if (t.isEnum && t.enumType != null) return t.enumType.baseType
    return t.baseType
}




def public lattice_small_type(bt : Type) : bool {
    return ((int(bt) >= int(Type.tFloat16) && int(bt) <= int(Type.tUByte16))
        || bt == Type.tInt8 || bt == Type.tUInt8 || bt == Type.tInt16 || bt == Type.tUInt16)
}




def public cpu_only_lattice_width(bt : Type) : bool {
    return (bt == Type.tHalf8
        || bt == Type.tShort8 || bt == Type.tUShort8
        || bt == Type.tByte8 || bt == Type.tByte16
        || bt == Type.tUByte8 || bt == Type.tUByte16)
}


def public scalar_class(bt : Type) : int {
    if (bt == Type.tInt || bt == Type.tInt2 || bt == Type.tInt3 || bt == Type.tInt4
            || bt == Type.tInt16 || bt == Type.tShort2 || bt == Type.tShort3 || bt == Type.tShort4
            || bt == Type.tInt8 || bt == Type.tByte2 || bt == Type.tByte3 || bt == Type.tByte4) return 0
    if (bt == Type.tUInt || bt == Type.tUInt2 || bt == Type.tUInt3 || bt == Type.tUInt4
            || bt == Type.tUInt16 || bt == Type.tUShort2 || bt == Type.tUShort3 || bt == Type.tUShort4
            || bt == Type.tUInt8 || bt == Type.tUByte2 || bt == Type.tUByte3 || bt == Type.tUByte4) return 1
    if (bt == Type.tFloat || bt == Type.tFloat2 || bt == Type.tFloat3 || bt == Type.tFloat4
            || bt == Type.tFloat16 || bt == Type.tHalf2 || bt == Type.tHalf3 || bt == Type.tHalf4) return 2
    return -1
}



def public scalar_width(bt : Type) : int {
    if (bt == Type.tFloat16 || bt == Type.tHalf2 || bt == Type.tHalf3 || bt == Type.tHalf4
            || bt == Type.tInt16 || bt == Type.tShort2 || bt == Type.tShort3 || bt == Type.tShort4
            || bt == Type.tUInt16 || bt == Type.tUShort2 || bt == Type.tUShort3 || bt == Type.tUShort4) return 16
    if (bt == Type.tInt8 || bt == Type.tByte2 || bt == Type.tByte3 || bt == Type.tByte4
            || bt == Type.tUInt8 || bt == Type.tUByte2 || bt == Type.tUByte3 || bt == Type.tUByte4) return 8
    if (scalar_class(bt) >= 0 || bt == Type.tBool) return 32
    return 0
}


def public component_count(bt : Type) : int {
    if (bt == Type.tInt || bt == Type.tUInt || bt == Type.tFloat || bt == Type.tBool) return 1
    if (bt == Type.tInt2 || bt == Type.tUInt2 || bt == Type.tFloat2) return 2
    if (bt == Type.tInt3 || bt == Type.tUInt3 || bt == Type.tFloat3) return 3
    if (bt == Type.tInt4 || bt == Type.tUInt4 || bt == Type.tFloat4) return 4
    if (bt == Type.tFloat16 || bt == Type.tInt8 || bt == Type.tUInt8 || bt == Type.tInt16 || bt == Type.tUInt16) return 1
    if (bt == Type.tHalf2 || bt == Type.tShort2 || bt == Type.tUShort2 || bt == Type.tByte2 || bt == Type.tUByte2) return 2
    if (bt == Type.tHalf3 || bt == Type.tShort3 || bt == Type.tUShort3 || bt == Type.tByte3 || bt == Type.tUByte3) return 3
    if (bt == Type.tHalf4 || bt == Type.tShort4 || bt == Type.tUShort4 || bt == Type.tByte4 || bt == Type.tUByte4) return 4
    return 0
}




def public numeric_info(bt : Type) : tuple<ok : bool; cls : int; width : int; lanes : int> {
    if (bt == Type.tInt64) return (ok = true, cls = 0, width = 64, lanes = 1)
    if (bt == Type.tUInt64) return (ok = true, cls = 1, width = 64, lanes = 1)
    if (bt == Type.tDouble) return (ok = true, cls = 2, width = 64, lanes = 1)
    let c = scalar_class(bt)
    if (c < 0) return (ok = false, cls = -1, width = 0, lanes = 0)
    return (ok = true, cls = c, width = scalar_width(bt), lanes = component_count(bt))
}


enum public BlockLayoutRules {
    std140
    std430
}




def public arith_width_ok(cls, width : int) : bool {
    return width <= 32 || (width == 64 && cls == 2)
}




def public arith_class(bt : Type) : int {
    let ni = numeric_info(bt)
    return ni.ok && arith_width_ok(ni.cls, ni.width) ? ni.cls : -1
}

def public arith_lanes(bt : Type) : int {
    if (bt == Type.tBool) return 1
    let ni = numeric_info(bt)
    return ni.ok && arith_width_ok(ni.cls, ni.width) ? ni.lanes : 0
}



def public std140_align(bt : Type) : int {
    if (bt == Type.tInt64 || bt == Type.tUInt64) return 8
    let cc = component_count(bt)
    if (cc == 1) return 4
    if (cc == 2) return 8
    return 16
}

def public std140_size(bt : Type) : int {
    if (bt == Type.tInt64 || bt == Type.tUInt64) return 8
    return component_count(bt) * 4
}


def public block_scalar_size(bt : Type) : int {
    if (bt == Type.tInt64 || bt == Type.tUInt64) return 8
    return component_count(bt) * (scalar_width(bt) / 8)
}

def public block_scalar_align(bt : Type; rules : BlockLayoutRules) : int {
    if (rules == BlockLayoutRules.std140) return std140_align(bt)
    if (bt == Type.tInt64 || bt == Type.tUInt64) return 8
    let cc = component_count(bt)
    let lanes = cc == 1 ? 1 : (cc == 2 ? 2 : 4)
    return lanes * (scalar_width(bt) / 8)
}

def public round_up(off, a : int) : int {
    return ((off + a - 1) / a) * a
}


struct public BlockField {
    name              : string 
    offset            : int    
    size              : int    
    is_matrix         : bool   
    matrix_width      : int    
    matrix_cols       : int    
    is_array          : bool   
    array_count       : int    
    array_stride      : int    
    is_struct         : bool   
    is_composite      : bool   
}


def public block_array_element_stride(bt : Type; rules : BlockLayoutRules) : int {
    if (rules == BlockLayoutRules.std140) return round_up(std140_size(bt), 16)
    return round_up(block_scalar_size(bt), block_scalar_align(bt, rules))
}


[macro_function]
def public compute_block_layout(sname : string; st : Structure?; var fields : array<BlockField>; var errors : array<string>; rules : BlockLayoutRules = BlockLayoutRules.std140) : tuple<ok : bool; size : int; align : int> {
    fields |> clear
    if (st == null || empty(st.fields)) {
        errors |> push("interface block '{sname}' must be a struct with at least one field")
        return (ok = false, size = 0, align = 0)
    }
    var off = 0
    var max_align = 0
    for (fld in st.fields) {
        
        let mi = matrix_info(fld._type)
        if (mi.ok) {
            off = round_up(off, 16)
            fields |> emplace(BlockField(name := string(fld.name), offset = off, size = 16 * mi.cols,
                is_matrix = true, matrix_width = mi.width, matrix_cols = mi.cols))
            off += 16 * mi.cols
            max_align = max(max_align, 16)
            continue
        }
        
        if (fld._type != null && fld._type.baseType == Type.tStructure && fld._type.structType != null) {
            var inner : array<BlockField>
            let inner_layout = compute_block_layout("{sname}.{fld.name}", fld._type.structType, inner, errors, rules)
            delete inner
            if (!inner_layout.ok) {
                fields |> clear
                return (ok = false, size = 0, align = 0)
            }
            let struct_align = rules == BlockLayoutRules.std140 ? round_up(inner_layout.align, 16) : inner_layout.align
            off = round_up(off, struct_align)
            let struct_size = round_up(inner_layout.size, struct_align)
            fields |> emplace(BlockField(name := string(fld.name), offset = off, size = struct_size,
                is_matrix = false, matrix_width = 0, matrix_cols = 0,
                is_array = false, array_count = 0, array_stride = 0,
                is_struct = true, is_composite = true))
            off += struct_size
            max_align = max(max_align, struct_align)
            continue
        }
        
        if (fld._type != null && fld._type.baseType == Type.tFixedArray && fld._type.firstType != null) {
            let et = fld._type.firstType
            let nelem = fld._type.fixedDim
            if (nelem <= 0) {
                errors |> push("interface block '{sname}' field '{fld.name}': array must have positive count (got {nelem})")
                fields |> clear
                return (ok = false, size = 0, align = 0)
            }
            
            if (et.baseType != Type.tStructure && et.baseType != Type.tFixedArray && !matrix_info(et).ok) {
                let ebt = et.baseType
                if (scalar_class(ebt) < 0 || (rules == BlockLayoutRules.std140 && scalar_width(ebt) != 32)) {
                    errors |> push("interface block '{sname}' field '{fld.name}': array element type {ebt} is not supported (only 32-bit int/uint/float scalars, their vectors, or nested structs of those)")
                    fields |> clear
                    return (ok = false, size = 0, align = 0)
                }
                let stride = block_array_element_stride(ebt, rules)
                let abase = rules == BlockLayoutRules.std140 ? 16 : block_scalar_align(ebt, rules)
                off = round_up(off, abase)     
                let total = stride * nelem
                fields |> emplace(BlockField(name := string(fld.name), offset = off, size = total,
                    is_matrix = false, matrix_width = 0, matrix_cols = 0,
                    is_array = true, array_count = nelem, array_stride = stride,
                    is_struct = false, is_composite = true))
                off += total
                max_align = max(max_align, abase)
                continue
            }
            
            if (et.baseType == Type.tStructure && et.structType != null) {
                var inner : array<BlockField>
                let inner_layout = compute_block_layout("{sname}.{fld.name}[]", et.structType, inner, errors, rules)
                delete inner
                if (!inner_layout.ok) {
                    fields |> clear
                    return (ok = false, size = 0, align = 0)
                }
                let struct_align = rules == BlockLayoutRules.std140 ? round_up(inner_layout.align, 16) : inner_layout.align
                let stride = round_up(inner_layout.size, struct_align)
                off = round_up(off, struct_align)
                let total = stride * nelem
                fields |> emplace(BlockField(name := string(fld.name), offset = off, size = total,
                    is_matrix = false, matrix_width = 0, matrix_cols = 0,
                    is_array = true, array_count = nelem, array_stride = stride,
                    is_struct = true, is_composite = true))
                off += total
                max_align = max(max_align, struct_align)
                continue
            }
            errors |> push("interface block '{sname}' field '{fld.name}': array element type {et.baseType} is not supported (only scalar/vector or nested-struct elements; matrix-of-array and array-of-array are out of scope)")
            fields |> clear
            return (ok = false, size = 0, align = 0)
        }
        
        let fbt = fld._type.baseType
        let is_int64 = fbt == Type.tInt64 || fbt == Type.tUInt64
        if (!is_int64 && (scalar_class(fbt) < 0 || (rules == BlockLayoutRules.std140 && scalar_width(fbt) != 32))) {
            errors |> push("interface block '{sname}' field '{fld.name}': type {fbt} is not supported (only 32-bit int/uint/float scalars, their vectors, matrices, fixed-arrays of those, 64-bit int64/uint64 scalars, and nested structs of those; bool has no physical interface-block layout in Vulkan)")
            fields |> clear
            return (ok = false, size = 0, align = 0)
        }
        let falign = block_scalar_align(fbt, rules)
        off = round_up(off, falign)
        fields |> emplace(BlockField(name := string(fld.name), offset = off, size = block_scalar_size(fbt),
            is_matrix = false, matrix_width = 0, matrix_cols = 0))
        off += block_scalar_size(fbt)
        max_align = max(max_align, falign)
    }
    return (ok = true, size = off, align = max_align)
}


[macro_function]
def public std140_block_is_packable(st : Structure?) : bool {
    var fields : array<BlockField>
    var errors : array<string>
    let layout = compute_block_layout("", st, fields, errors)
    delete fields
    delete errors
    return layout.ok
}


struct public Std140Write {
    offset : int             
    access : ExpressionPtr   
}


[macro_function]
def public std140_block_writes(st : Structure?; access : ExpressionPtr; baseOffset : int; var out : array<Std140Write>) {
    var fields : array<BlockField>
    var errors : array<string>
    compute_block_layout("", st, fields, errors)
    for (i in range(length(fields))) {
        let f = fields[i]
        let ftype = st.fields[i]._type
        let off = baseOffset + f.offset
        var faccess = new ExprField(at = access.at, value <- clone_expression(access), name := st.fields[i].name)
        if (f.is_matrix && f.matrix_width != 4) {
            out |> reserve(length(out) + f.matrix_cols)
            for (c in range(f.matrix_cols)) {
                var col = new ExprAt(at = access.at, subexpr <- clone_expression(faccess),
                    index <- new ExprConstInt(at = access.at, value = c))
                out |> push(Std140Write(offset = off + c * 16, access = col))
            }
        } elif (f.is_array && f.is_struct) {
            for (e in range(f.array_count)) {
                var el = new ExprAt(at = access.at, subexpr <- clone_expression(faccess),
                    index <- new ExprConstInt(at = access.at, value = e))
                std140_block_writes(ftype.firstType.structType, el, off + e * f.array_stride, out)
            }
        } elif (f.is_array) {
            out |> reserve(length(out) + f.array_count)
            for (e in range(f.array_count)) {
                var el = new ExprAt(at = access.at, subexpr <- clone_expression(faccess),
                    index <- new ExprConstInt(at = access.at, value = e))
                out |> push(Std140Write(offset = off + e * f.array_stride, access = el))
            }
        } elif (f.is_struct) {
            std140_block_writes(ftype.structType, faccess, off, out)
        } else {
            out |> push(Std140Write(offset = off, access = faccess))
        }
    }
    delete fields
    delete errors
}
