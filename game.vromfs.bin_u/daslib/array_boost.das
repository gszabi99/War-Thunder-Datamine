options gen2
options indenting = 4

options strict_smart_pointers

module array_boost shared public







require daslib/templates
require daslib/contracts

[unsafe_operation, template(a), unused_argument(a)]
def private array_helper(var arr : auto implicit ==const; a : auto(TT)) : array<TT -const -#> {
    
    var res : array<TT -const -#>
    static_if (typeinfo is_array(arr)) {
        let lenA = _::long_length(arr)
        if (lenA >= 1_l) {
            unsafe {
                _builtin_make_temp_array_i64(res, addr(arr[0]), lenA)
            }
        }
    } else {
        let lenA = _::length(arr)
        if (lenA >= 1) {
            unsafe {
                _builtin_make_temp_array(res, addr(arr[0]), lenA)
            }
        }
    }
    return <- res
}

[unsafe_operation, template(a), unused_argument(a)]
def private array_helper(arr : auto implicit ==const; a : auto(TT)) : array<TT -const -#> {
    
    var res : array<TT -const -#>
    static_if (typeinfo is_array(arr)) {
        let lenA = _::long_length(arr)
        if (lenA >= 1_l) {
            unsafe {
                _builtin_make_temp_array_i64(res, addr(arr[0]), lenA)
            }
        }
    } else {
        let lenA = _::length(arr)
        if (lenA >= 1) {
            unsafe {
                _builtin_make_temp_array(res, addr(arr[0]), lenA)
            }
        }
    }
    return <- res
}

[unsafe_operation]
def public temp_array(var arr : auto implicit ==const) {
    
    
    
    
    
    
    unsafe {
        return <- array_helper(arr, decltype(arr[0]))
    }
}

[unsafe_operation]
def public temp_array(arr : auto implicit ==const) {
    
    
    
    
    
    
    unsafe {
        return <- array_helper(arr, decltype(arr[0]))
    }
}

[expect_any_array(v)]
def empty(v : auto(VecT)) {
    
    return _::length(v) == 0
}

[unsafe_operation, template(a), unused_argument(a)]
def public temp_array(var data : auto? ==const; lenA : int | int64; a : auto(TT)) : array<TT -const -#> {
    
    
    
    
    
    
    var res : array<TT -const -#>
    static_if (typeinfo is_int(lenA)) {
        if (lenA >= 1) {
            unsafe(_builtin_make_temp_array(res, data, lenA))
        }
    } else {
        if (lenA >= 1_l) {
            unsafe(_builtin_make_temp_array_i64(res, data, lenA))
        }
    }
    return <- res
}

[unsafe_operation, template(a), unused_argument(a)]
def public temp_array(data : auto? ==const; lenA : int | int64; a : auto(TT)) : array<TT -const -#> const {
    
    
    
    
    
    
    var res : array<TT -const -#>
    static_if (typeinfo is_int(lenA)) {
        if (lenA >= 1) {
            unsafe(_builtin_make_temp_array(res, data, lenA))
        }
    } else {
        if (lenA >= 1_l) {
            unsafe(_builtin_make_temp_array_i64(res, data, lenA))
        }
    }
    return <- res
}

def array_view(bytes : array<auto(TT)> ==const; offset, length : int | int64; blk : block<(view : array<TT>#) : void>) {
    
    unsafe {
        static_if (typeinfo is_int(offset)) {
            
            if (offset < 0 || length < 0 || uint(offset) + uint(length) > uint(_::length(bytes))) {
                panic("array_view: out of range")
            }
            __builtin_array_lock_mutable(bytes)
            var res : array<TT>#
            _builtin_make_temp_array(res, addr(bytes[offset]), length)
            invoke(blk, res)
            __builtin_array_unlock_mutable(bytes)
        } else {
            if (offset < 0_l || length < 0_l || uint64(offset) + uint64(length) > uint64(_::long_length(bytes))) {
                panic("array_view: out of range")
            }
            __builtin_array_lock_mutable(bytes)
            var res : array<TT>#
            _builtin_make_temp_array_i64(res, addr(bytes[offset]), length)
            invoke(blk, res)
            __builtin_array_unlock_mutable(bytes)
        }
    }
}

def array_view(var bytes : array<auto(TT)> ==const; offset, length : int | int64; blk : block<(var view : array<TT>#) : void>) {
    
    unsafe {
        static_if (typeinfo is_int(offset)) {
            if (offset < 0 || length < 0 || uint(offset) + uint(length) > uint(_::length(bytes))) {
                panic("array_view: out of range")
            }
            __builtin_array_lock(bytes)
            var res : array<TT>#
            _builtin_make_temp_array(res, addr(bytes[offset]), length)
            invoke(blk, res)
            __builtin_array_unlock(bytes)
        } else {
            if (offset < 0_l || length < 0_l || uint64(offset) + uint64(length) > uint64(_::long_length(bytes))) {
                panic("array_view: out of range")
            }
            __builtin_array_lock(bytes)
            var res : array<TT>#
            _builtin_make_temp_array_i64(res, addr(bytes[offset]), length)
            invoke(blk, res)
            __builtin_array_unlock(bytes)
        }
    }
}

def array_view(bytes : array<auto(TT)>#; offset, length : int | int64; blk : block<(view : array<TT>#) : void>) {
    
    unsafe {
        static_if (typeinfo is_int(offset)) {
            if (offset < 0 || length < 0 || uint(offset) + uint(length) > uint(_::length(bytes))) {
                panic("array_view: out of range")
            }
            var res : array<TT>#
            if (length > 0) {
                _builtin_make_temp_array(res, addr(bytes[offset]), length)
            }
            invoke(blk, res)
        } else {
            if (offset < 0_l || length < 0_l || uint64(offset) + uint64(length) > uint64(_::long_length(bytes))) {
                panic("array_view: out of range")
            }
            var res : array<TT>#
            if (length > 0_l) {
                _builtin_make_temp_array_i64(res, addr(bytes[offset]), length)
            }
            invoke(blk, res)
        }
    }
}

[template(t), unused_argument(t)]
def array_view(
               bytes : array<uint8> ==const;
               byte_offset, length : int | int64;
               t : type<auto(TT)>;
               blk : block<(view : array<TT>#) : void>
               ) {
    
    static_if (typeinfo is_int(byte_offset)) {
        array_view(bytes, 0, _::length(bytes)) $(view : array<uint8>#) {
            array_view(view, byte_offset, length, type<TT>, blk)
        }
    } else {
        array_view(bytes, 0_l, _::long_length(bytes)) $(view : array<uint8>#) {
            array_view(view, byte_offset, length, type<TT>, blk)
        }
    }
}

[template(t), unused_argument(t)]
def array_view(
               bytes : array<uint8>#;
               byte_offset, length : int | int64;
               t : type<auto(TT)>;
               blk : block<(view : array<TT>#) : void>
               ) {
    
    concept_assert(typeinfo is_pod(type<TT>), "typed array_view requires a POD element type")
    concept_assert(typeinfo sizeof(type<TT>) > 0, "typed array_view requires a non-empty element type")
    let element_size = typeinfo sizeof(type<TT>)
    let element_align = typeinfo alignof(type<TT>)
    unsafe {
        static_if (typeinfo is_int(byte_offset)) {
            if (byte_offset < 0 || length < 0 || byte_offset > _::length(bytes)
                    || uint(length) > (uint(_::length(bytes)) - uint(byte_offset)) / uint(element_size)) {
                panic("array_view: out of range")
            }
            var res : array<TT -const>#
            if (length > 0) {
                let data = addr<TT -const?>(bytes[byte_offset])
                if (intptr(reinterpret<void?>(data)) % uint64(element_align) != 0_ul) {
                    panic("array_view: unaligned typed view")
                }
                _builtin_make_temp_array(res, data, length)
            }
            invoke(blk, res)
        } else {
            if (byte_offset < 0_l || length < 0_l || byte_offset > _::long_length(bytes)
                    || uint64(length) > (uint64(_::long_length(bytes)) - uint64(byte_offset)) / uint64(element_size)) {
                panic("array_view: out of range")
            }
            var res : array<TT -const>#
            if (length > 0_l) {
                let data = addr<TT -const?>(bytes[byte_offset])
                if (intptr(reinterpret<void?>(data)) % uint64(element_align) != 0_ul) {
                    panic("array_view: unaligned typed view")
                }
                _builtin_make_temp_array_i64(res, data, length)
            }
            invoke(blk, res)
        }
    }
}

[unused_argument(witness)]
def private pod_view_impl(bytes : array<uint8>#; byte_offset : int | int64; witness : auto(TT)) : TT {
    concept_assert(typeinfo is_pod(type<TT>), "pod_view requires a POD element type")
    concept_assert(typeinfo is_raw(type<TT>), "pod_view requires a raw POD element type (no pointers)")
    concept_assert(typeinfo sizeof(type<TT>) > 0, "pod_view requires a non-empty element type")
    let element_size = typeinfo sizeof(type<TT>)
    var result : TT
    unsafe {
        var view : array<uint8>#
        _builtin_make_temp_array(view, addr<uint8?>(result), element_size)
        static_if (typeinfo is_int(byte_offset)) {
            if (byte_offset < 0 || byte_offset > _::length(bytes) - element_size) {
                panic("pod_view: out of range")
            }
            for (i in range(element_size)) {
                view[i] = bytes[byte_offset + i]
            }
        } else {
            if (byte_offset < 0_l || byte_offset > _::long_length(bytes) - int64(element_size)) {
                panic("pod_view: out of range")
            }
            for (i in range(element_size)) {
                view[i] = bytes[byte_offset + int64(i)]
            }
        }
    }
    return result
}

[template(t), unused_argument(t)]
def pod_view(bytes : array<uint8>#; byte_offset : int | int64; t : type<auto(TT)>) : TT {
    
    
    concept_assert(typeinfo is_pod(type<TT>) && typeinfo is_raw(type<TT>), "pod_view requires a raw POD element type (no pointers)")
    let result : TT
    return pod_view_impl(bytes, byte_offset, result)
}

[template(t), unused_argument(t)]
def pod_view(bytes : array<uint8> ==const; byte_offset : int | int64; t : type<auto(TT)>) : TT {
    
    concept_assert(typeinfo is_pod(type<TT>) && typeinfo is_raw(type<TT>), "pod_view requires a raw POD element type (no pointers)")
    var result : TT
    static_if (typeinfo is_int(byte_offset)) {
        array_view(bytes, 0, _::length(bytes)) $(view : array<uint8>#) {
            result = pod_view_impl(view, byte_offset, result)
        }
    } else {
        array_view(bytes, 0_l, _::long_length(bytes)) $(view : array<uint8>#) {
            result = pod_view_impl(view, byte_offset, result)
        }
    }
    return result
}
