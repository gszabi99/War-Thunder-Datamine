options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module linq shared public






















































































[skip_lock_check]
def to_sequence(a : array<auto(TT)>) : iterator<TT -const -&> {
    
    var b := a
    return to_sequence_move(b)
}

[skip_lock_check]
def to_sequence_move(var a : array<auto(TT)>) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- a) () <| $ {
        for (it in a) {
            yield <- it
        }
        delete a
        return false
    }
}

[skip_lock_check, unused_argument(tt)]
def private to_table_impl(var a; tt : auto(TT); key : block<(v : TT -&) : auto>; elementSelector : block<(v : TT -&) : auto>) : table<typedecl(_::unique_key(type<TT>)) -const -&, typedecl(elementSelector(type<TT>)) -const -&> {
    var result : table<typedecl(_::unique_key(type<TT>)) -const -&, typedecl(elementSelector(type<TT>)) -const -&>
    for (it in a) {
        let k = key(it)
        unsafe(result[_::unique_key(k)]) := elementSelector(it)
    }
    return <- result
}

[skip_lock_check, unused_argument(tt)]
def private to_table_impl_const(a : auto(ARGT); tt : auto(TT); key : block<(v : TT -&) : auto>; elementSelector : block<(v : TT -&) : auto>) : table<typedecl(_::unique_key(type<TT>)) -const -&, typedecl(elementSelector(type<TT>)) -const -&> {
    return <- to_table_impl(unsafe(reinterpret<ARGT -const>(a)), type<TT -const -&>, key, elementSelector)
}

[skip_lock_check]
def to_table(var a : iterator<auto(TT)>; key : block<(v : TT -&) : auto>; elementSelector : block<(v : TT -&) : auto>) : table<typedecl(_::unique_key(type<TT>)) -const -&, typedecl(elementSelector(type<TT>)) -const -&> {
    return <- to_table_impl(a, type<TT -const -&>, key, elementSelector)
}

[skip_lock_check]
def to_table(a : array<auto(TT)>; key : block<(v : TT -&) : auto>; elementSelector : block<(v : TT -&) : auto>) : table<typedecl(_::unique_key(type<TT>)) -const -&, typedecl(elementSelector(type<TT>)) -const -&> {
    return <- to_table_impl_const(a, type<TT -const -&>, key, elementSelector)
}

[skip_lock_check, unused_argument(tt)]
def private concat_impl(var a; var b; tt : auto(TT); reserveSize : int) : array<TT -const -&> {
    
    var c : array<TT -const -&>
    static_if (typeinfo need_lock_check(c)) {
        unsafe(set_verify_array_locks(c, false))
    }
    if (reserveSize > 0) {
        c.reserve(reserveSize)
    }
    for (it in a) {
        c.push_clone(it)
    }
    for (it in b) {
        c.push_clone(it)
    }
    static_if (typeinfo need_lock_check(c)) {
        unsafe(set_verify_array_locks(c, true))
    }
    return <- c
}

[skip_lock_check, unused_argument(tt)]
def private concat_impl_const(a : auto(ARGT); b : auto(ARGU); tt : auto(TT); reserveSize : int) : array<TT -const -&> {
    return <- concat_impl(unsafe(reinterpret<ARGT -const>(a)), unsafe(reinterpret<ARGU -const>(b)), type<TT -const -&>, reserveSize)
}

[skip_lock_check]
def concat(a, b : array<auto(TT)>) : array<TT -const -&> {
    return <- concat_impl_const(a, b, type<TT -const -&>, length(a) + length(b))
}

[skip_lock_check]
def concat_to_array(var a, b : iterator<auto(TT)>) : array<TT -const -&> {
    return <- concat_impl(a, b, type<TT -const -&>, 0)
}

[skip_lock_check]
def concat(var a, b : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- a, <- b) () <| $ {
        for (itA in a) {
            static_if (typeinfo can_copy(itA)) {
                yield itA
            } else {
                yield <- clone_to_move(itA)
            }
        }
        for (itB in b) {
            static_if (typeinfo can_copy(itB)) {
                yield itB
            } else {
                yield <- clone_to_move(itB)
            }
        }
        return false
    }
}

[skip_lock_check]
def concat_inplace(var a : array<auto(TT)>, b : array<auto(TT)>) {
    
    static_if (typeinfo need_lock_check(a)) {
        _builtin_verify_locks(a)
        unsafe(set_verify_array_locks(a, false))
    }
    a.reserve(length(a) + length(b))
    for (it in b) {
        a.push_clone(it)
    }
    static_if (typeinfo need_lock_check(a)) {
        unsafe(set_verify_array_locks(a, true))
    }
}

[skip_lock_check]
def reverse_inplace(var buffer : array<auto(TT)>) {
    
    static_if (typeinfo need_lock_check(buffer)) {
        _builtin_verify_locks(buffer)
        unsafe(set_verify_array_locks(buffer, false))
    }
    let l = length(buffer)
    let half = l / 2
    let lm1 = l - 1
    for (i in range(half)) {
        var t : TT -& <- buffer[i]
        buffer[i] <- buffer[lm1 - i]
        buffer[lm1 - i] <- t
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
}

[skip_lock_check]
def reverse(a : array<auto(TT)>) : array<TT -const -&> {
    
    var b := a
    reverse_inplace(b)
    return <- b
}

[skip_lock_check]
def reverse(var a : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- a) () <| $ {
        var inscope buffer : array<TT -const -&>
        static_if (typeinfo need_lock_check(buffer)) {
            unsafe(set_verify_array_locks(buffer, false))
        }
        for (it in a) {
            buffer.push_clone(it)
        }
        let len = buffer.length()
        for (i in 0..len) {
            yield <- buffer[len - i - 1]
        }
        static_if (typeinfo need_lock_check(buffer)) {
            unsafe(set_verify_array_locks(buffer, true))
        }
        return false
    }
}

[skip_lock_check]
def reverse_to_array(var a : iterator<auto(TT)>) : array<TT -const -&> {
    
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in a) {
        buffer.push_clone(it)
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    reverse_inplace(buffer)
    return <- buffer
}

[skip_lock_check]
def order_inplace(var buffer : array<auto(TT)>) {
    
    sort(buffer, $(a, b) => _::unique_key(a) < _::unique_key(b))
}

[skip_lock_check]
def order(var a : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(a, b) => _::unique_key(a) < _::unique_key(b))
    return to_sequence_move(arr)
}

[skip_lock_check]
def order(arr : array<auto(TT)>) : array<TT -const -&> {
    
    var brr := arr
    sort(brr, $(a, b) => _::unique_key(a) < _::unique_key(b))
    return <- brr
}

[skip_lock_check]
def order_to_array(var a : iterator<auto(TT)>) : array<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(a, b) => _::unique_key(a) < _::unique_key(b))
    return <- arr
}

[skip_lock_check]
def order_inplace(var buffer : array<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) {
    
    sort(buffer, fun)
}

[skip_lock_check]
def order(var a : iterator<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : iterator<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => fun(v1, v2))
    return to_sequence_move(arr)
}

[skip_lock_check]
def order(a : array<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : array<TT -const -&> {
    
    var b := a
    sort(b, fun)
    return <- b
}

[skip_lock_check]
def order_to_array(var a : iterator<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : array<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, fun)
    return <- arr
}

[skip_lock_check]
def order_descending_inplace(var buffer : array<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) {
    
    sort(buffer, $(v1, v2) => fun(v2, v1))
}

[skip_lock_check]
def order_descending(var a : iterator<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : iterator<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => fun(v2, v1))
    return to_sequence_move(arr)
}

[skip_lock_check]
def order_descending(a : array<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : array<TT -const -&> {
    
    var b := a
    sort(b, $(v1, v2) => fun(v2, v1))
    return <- b
}

[skip_lock_check]
def order_descending_to_array(var a : iterator<auto(TT)>; fun : block<(v1 : TT -&, v2 : TT -&) : bool>) : array<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => fun(v2, v1))
    return <- arr
}

def less(a, b) : bool {
    return a < b
}

def less(a, b : tuple<auto(TT)>) : bool {
    return a._0 < b._0
}

def less(a, b : tuple<auto(TT), auto(UU)>) : bool {
    return true if (a._0 < b._0)
    return false if (a._0 > b._0)
    return a._1 < b._1
}

def less(a, b : tuple<auto(TT), auto(UU), auto(VV)>) : bool {
    return true if (a._0 < b._0)
    return false if (a._0 > b._0)
    return true if (a._1 < b._1)
    return false if (a._1 > b._1)
    return a._2 < b._2
}

def less(a, b : tuple<auto(TT), auto(UU), auto(VV), auto(WW)>) : bool {
    return true if (a._0 < b._0)
    return false if (a._0 > b._0)
    return true if (a._1 < b._1)
    return false if (a._1 > b._1)
    return true if (a._2 < b._2)
    return false if (a._2 > b._2)
    return a._3 < b._3
}

[skip_lock_check]
def order_by_inplace(var buffer : array<auto(TT)>; key) {
    
    sort(buffer, $(v1, v2) => _::less(key(v1), key(v2)))
}

[skip_lock_check]
def order_by(var a : iterator<auto(TT)>; key) : iterator<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => _::less(key(v1), key(v2)))
    return to_sequence_move(arr)
}

[skip_lock_check]
def order_by(a : array<auto(TT)>; key) : array<TT -const -&> {
    
    var b := a
    sort(b, $(v1, v2) => _::less(key(v1), key(v2)))
    return <- b
}

[skip_lock_check]
def order_by_to_array(var a : iterator<auto(TT)>; key) : array<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => _::less(key(v1), key(v2)))
    return <- arr
}

[skip_lock_check]
def order_by_descending_inplace(var buffer : array<auto(TT)>; key) {
    
    sort(buffer, $(v1, v2) => _::less(key(v2), key(v1)))
}

[skip_lock_check]
def order_by_descending(var a : iterator<auto(TT)>; key) : iterator<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => _::less(key(v2), key(v1)))
    return to_sequence_move(arr)
}

[skip_lock_check]
def order_by_descending(a : array<auto(TT)>; key) : array<TT -const -&> {
    
    var b := a
    sort(b, $(v1, v2) => _::less(key(v2), key(v1)))
    return <- b
}

[skip_lock_check]
def order_by_descending_to_array(var a : iterator<auto(TT)>; key) : array<TT -const -&> {
    
    var arr <- to_array(a)
    sort(arr, $(v1, v2) => _::less(key(v2), key(v1)))
    return <- arr
}

def unique_key(a) {
    
    static_if (typeinfo is_workhorse(a)) {
        return a
    } else {
        return "{a}"
    }
}

[skip_lock_check]
def private distinct_impl(var a; tt : auto(TT)) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(type<TT>))>
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in a) {
        let k = _::unique_key(it)
        if (!seen.key_exists(k)) {
            buffer.push_clone(it)
            seen.insert(k)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check]
def private distinct_impl_const(a : auto(ARGT); tt : auto(TT)) : array<TT -const -&> {
    return <- distinct_impl(unsafe(reinterpret<ARGT -const>(a)), type<TT -const -&>)
}

[skip_lock_check]
def distinct(a : array<auto(TT)>) : array<TT -const -&> {
    
    return <- distinct_impl_const(a, type<TT -const -&>)
}

[skip_lock_check]
def distinct_to_array(var a : iterator<auto(TT)>) : array<TT -const -&> {
    
    return <- distinct_impl(a, type<TT -const -&>)
}

[skip_lock_check]
def distinct_inplace(var a : array<auto(TT)>) {
    
    var to_index = 0
    var inscope seen : table<typedecl(_::unique_key(type<TT>))>
    static_if (typeinfo need_lock_check(a)) {
        _builtin_verify_locks(a)
        set_verify_array_locks(a, false)
    }
    for (from_index in 0 .. length(a)) {
        var it & = unsafe(a[from_index])
        let k = _::unique_key(it)
        if (!seen.key_exists(k)) {
            if (to_index != from_index) {
                a[to_index] <- it
            }
            to_index ++
            seen.insert(k)
        }
    }
    a.resize(to_index)
    static_if (typeinfo need_lock_check(a)) {
        set_verify_array_locks(a, true)
    }
}

[skip_lock_check]
def distinct(var a : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- a) () <| $ {
        var inscope seen : table<typedecl(_::unique_key(type<TT>))>
        for (it in a) {
            let k = _::unique_key(it)
            if (!seen.key_exists(k)) {
                static_if (typeinfo can_copy(it)) {
                    yield it
                } else {
                    yield <- clone_to_move(it)
                }
                seen.insert(k)
            }
        }
        return false
    }
}

[skip_lock_check, unused_argument(tt)]
def private distinct_by_impl(var a; tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(key(type<TT>)))>
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in a) {
        let k = _::unique_key(key(it))
        if (!seen.key_exists(k)) {
            buffer.push_clone(it)
            seen.insert(k)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private distinct_by_impl_const(a : auto(ARGT); tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    return <- distinct_by_impl(unsafe(reinterpret<ARGT -const>(a)), type<TT -const -&>, key)
}

[skip_lock_check]
def distinct_by(a : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- distinct_by_impl_const(a, type<TT -const -&>, key)
}

[skip_lock_check]
def distinct_by_to_array(var a : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- distinct_by_impl(a, type<TT -const -&>, key)
}

[skip_lock_check]
def distinct_by(var a : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : iterator<TT -const -&> {
    
    
    return <- distinct_by_impl(a, type<TT -const -&>, key).to_sequence_move()
}

[skip_lock_check]
def distinct_by_inplace(var a : array<auto(TT)>; key : block<(arg : TT -&) : auto>) {
    
    var to_index = 0
    var inscope seen : table<typedecl(_::unique_key(key(type<TT>)))>
    static_if (typeinfo need_lock_check(a)) {
        _builtin_verify_locks(a)
        set_verify_array_locks(a, false)
    }
    for (from_index in 0 .. length(a)) {
        var it & = unsafe(a[from_index])
        let k = _::unique_key(key(it))
        if (!seen.key_exists(k)) {
            if (to_index != from_index) {
                a[to_index] <- it
            }
            to_index ++
            seen.insert(k)
        }
    }
    a.resize(to_index)
    static_if (typeinfo need_lock_check(a)) {
        set_verify_array_locks(a, true)
    }
}

[skip_lock_check]
def unique(a : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    var inscope buffer <- to_array(a)
    unique_inplace(buffer)
    return to_sequence_move(buffer)
}

[skip_lock_check]
def unique(a : array<auto(TT)>) : array<TT -const -&> {
    
    var b := a
    unique_inplace(b)
    return <- b
}

[skip_lock_check]
def unique_to_array(a : iterator<auto(TT)>) : array<TT -const -&> {
    
    var inscope buffer <- to_array(a)
    unique_inplace(buffer)
    return <- buffer
}

[skip_lock_check]
def unique_inplace(var a : array<auto(TT)>) {
    
    static_if (typeinfo need_lock_check(a)) {
        _builtin_verify_locks(a)
        set_verify_array_locks(a, false)
    }
    var write_index = 1
    for (from_index in 1 .. length(a)) {
        if (_::unique_key(a[from_index]) != _::unique_key(a[write_index - 1])) {
            a[write_index++] <- a[from_index]
        }
    }
    a.resize(write_index)
    static_if (typeinfo need_lock_check(a)) {
        set_verify_array_locks(a, true)
    }
}

[skip_lock_check]
def unique_by(a : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : iterator<TT -const -&> {
    
    var inscope buffer <- to_array(a)
    unique_by_inplace(buffer, key)
    return to_sequence_move(buffer)
}

[skip_lock_check]
def unique_by(a : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var b := a
    unique_by_inplace(b, key)
    return <- b
}

[skip_lock_check]
def unique_by_to_array(a : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var inscope buffer <- to_array(a)
    unique_by_inplace(buffer, key)
    return <- buffer
}

[skip_lock_check]
def unique_by_inplace(var a : array<auto(TT)>; key : block<(arg : TT -&) : auto>) {
    
    static_if (typeinfo need_lock_check(a)) {
        _builtin_verify_locks(a)
        set_verify_array_locks(a, false)
    }
    var write_index = 1
    for (from_index in 1 .. length(a)) {
        if (key(a[from_index]) != key(a[write_index - 1])) {
            a[write_index++] <- a[from_index]
        }
    }
    a.resize(write_index)
    static_if (typeinfo need_lock_check(a)) {
        set_verify_array_locks(a, true)
    }
}

[skip_lock_check]
def count(var a : iterator<auto(TT)>) : int {
    
    var count = 0
    for (it in a) {
        count ++
    }
    return count
}

[skip_lock_check]
def count(a : array<auto(TT)>) : int {
    
    return length(a)
}

[skip_lock_check]
def long_count(var a : iterator<auto(TT)>) : int64 {
    
    var count = 0l
    for (it in a) {
        count ++
    }
    return count
}

[skip_lock_check]
def long_count(a : array<auto(TT)>) : int64 {
    
    return int64(length(a))
}

[skip_lock_check, unused_argument(tt)]
def private where_impl(var src; tt : auto(TT); len : int; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    buffer.reserve(len)
    for (x in src) {
        if (predicate(x)) {
            buffer.push_clone(x)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private where_impl_const(src : auto(ARGT); tt : auto(TT); len : int; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    return <- where_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -& -const>, len, predicate)
}

[skip_lock_check]
def where_(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : iterator<TT -& -const> {
    
    return <- where_impl(src, type<TT -& -const>, 0, predicate).to_sequence_move()
}

[skip_lock_check]
def where_(src : array<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- where_impl_const(src, type<TT -& -const>, length(src), predicate)
}

[skip_lock_check]
def where_to_array(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- where_impl(src, type<TT -& -const>, 0, predicate)
}

[skip_lock_check]
def skip(arr : array<auto(TT)>; var total : int) : array<TT -& -const> {
    
    let len = length(arr)
    let remaining = len - total
    if (remaining <= 0) {
        return <- default<array<TT -& -const>>
    }
    return <- subarray(arr, total..len)
}

[skip_lock_check]
def skip_inplace(var arr : array<auto(TT)>; var total : int) {
    
    static_if (typeinfo need_lock_check(arr)) {
        _builtin_verify_locks(arr)
        unsafe(set_verify_array_locks(arr, false))
    }
    let len = length(arr)
    let remaining = len - total
    if (remaining <= 0) {
        arr.clear()
        return
    }
    for (i in 0..remaining) {
        arr[i] <- arr[i + total]
    }
    arr.resize(remaining)
    static_if (typeinfo need_lock_check(arr)) {
        unsafe(set_verify_array_locks(arr, true))
    }
}

[skip_lock_check, unused_argument(tt)]
def private skip_impl(var src; tt : auto(TT); var total : int) : iterator<TT -& -const> {
    
    return <- generator<TT -& -const> capture(<- src) () <| $() {
        for (x in src) {
            if (total > 0) {
                total --
                continue
            }
            static_if (typeinfo can_copy(x)) {
                yield x
            } else {
                yield <- clone_to_move(x)
            }
        }
        return false
    }
}


[skip_lock_check]
def skip(var src : iterator<auto(TT)>; var total : int) : iterator<TT -& -const> {
    
    return skip_impl(src, type<TT -& -const>, total)
}

[skip_lock_check]
def skip_to_array(var src : iterator<auto(TT)>; var total : int) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (x in src) {
        if (total > 0) {
            total --
            continue
        }
        buffer.push_clone(x)
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private skip_while_impl(var src; tt : auto(TT); predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var skipping = true
    for (x in src) {
        if (skipping) {
            if (predicate(x)) {
                continue
            } else {
                skipping = false
            }
        }
        buffer.push_clone(x)
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private skip_while_impl_const(src : auto(ARGT); tt : auto(TT); predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    return <- skip_while_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -& -const>, predicate)
}

[skip_lock_check]
def skip_while(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : iterator<TT -& -const> {
    
    
    return <- skip_while_impl(src, type<TT -& -const>, predicate).to_sequence_move()
}

[skip_lock_check]
def skip_while(src : array<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- skip_while_impl_const(src, type<TT -& -const>, predicate)
}

[skip_lock_check]
def skip_while_to_array(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- skip_while_impl(src, type<TT -& -const>, predicate)
}

[skip_lock_check]
def take(arr : array<auto(TT)>; var total : int) : array<TT -& -const> {
    
    let len = length(arr)
    let taking = (total < len)  ? total : len
    return <- subarray(arr, 0..taking)
}

[skip_lock_check]
def take_inplace(var arr : array<auto(TT)>; var total : int) {
    
    let len = length(arr)
    let taking = (total < len)  ? total : len
    arr.resize(taking)
}

[skip_lock_check, unused_argument(tt)]
def private take_impl(var src; tt : auto(TT); var total : int) : iterator<TT -& -const> {
    
    return <- generator<TT -& -const> capture(<- src) () <| $() {
        for (x in src) {
            if (total <= 0) {
                break
            }
            total --
            static_if (typeinfo can_copy(x)) {
                yield x
            } else {
                yield <- clone_to_move(x)
            }
        }
        return false
    }
}

[skip_lock_check]
def take(var src : iterator<auto(TT)>; var total : int) : iterator<TT -& -const> {
    
    return take_impl(src, type<TT -& -const>, total)
}

[skip_lock_check]
def take_to_array(var src : iterator<auto(TT)>; var total : int) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (x in src) {
        if (total <= 0) {
            break
        }
        total --
        buffer.push_clone(x)
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check]
def take(var src : iterator<auto(TT)>; from : range) : iterator<TT -& -const> {
    
    return <- generator<TT -& -const> capture(<- src) () <| $() {
        var index = 0
        for (x in src) {
            if (index >= from.x) {
                if (index >= from.y) {
                    break
                }
                static_if (typeinfo can_copy(x)) {
                    yield x
                } else {
                    yield <- clone_to_move(x)
                }
            }
            index ++
        }
        return false
    }
}

[skip_lock_check]
def take(src : array<auto(TT)>; from : range) : array<TT -& -const> {
    
    let len = length(src)
    let start = (from.x < 0) ? 0 : ((from.x > len) ? len : from.x)
    var end = (from.y < 0) ? 0 : ((from.y > len) ? len : from.y)
    if (end < start) {
        end = start
    }
    return <- subarray(src, start..end)
}

[skip_lock_check]
def take_to_array(var src : iterator<auto(TT)>; from : range) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var index = 0
    for (x in src) {
        if (index >= from.x) {
            if (index >= from.y) {
                break
            }
            buffer.push_clone(x)
        }
        index ++
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check]
def take_inplace(var arr : array<auto(TT)>; from : range) {
    
    static_if (typeinfo need_lock_check(arr)) {
        _builtin_verify_locks(arr)
        unsafe(set_verify_array_locks(arr, false))
    }
    let len = length(arr)
    let start = (from.x < 0) ? 0 : ((from.x > len) ? len : from.x)
    var end = (from.y < 0) ? 0 : ((from.y > len) ? len : from.y)
    if (end < start) {
        end = start
    }
    let taking = end - start
    for (i in 0..taking) {
        arr[i] <- arr[start + i]
    }
    arr.resize(taking)
    static_if (typeinfo need_lock_check(arr)) {
        unsafe(set_verify_array_locks(arr, true))
    }
}

[skip_lock_check, unused_argument(tt)]
def private take_while_impl(var src; tt : auto(TT); predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    var buffer : array<TT -& -const>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var taking = true
    for (x in src) {
        if (taking) {
            if (predicate(x)) {
                buffer.push_clone(x)
            } else {
                taking = false
            }
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private take_while_impl_const(src : auto(ARGT); tt : auto(TT); predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    return <- take_while_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -& -const>, predicate)
}

[skip_lock_check]
def take_while(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) {
    
    return <- take_while_impl(src, type<TT -& -const>, predicate).to_sequence_move()
}

[skip_lock_check]
def take_while(src : array<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- take_while_impl_const(src, type<TT -& -const>, predicate)
}

[skip_lock_check]
def take_while_to_array(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : array<TT -& -const> {
    
    return <- take_while_impl(src, type<TT -& -const>, predicate)
}

[skip_lock_check, unused_argument(tt)]
def private min_impl(var src; tt : auto(TT)) : TT -& -const {
    var minn : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            first = false
        } elif (_::less(x, minn)) {
            minn := x
        }
    }
    return <- minn
}

[skip_lock_check, unused_argument(tt)]
def private min_impl_const(src : auto(ARGT); tt : auto(TT)) : TT -& -const {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -& -const>)
    } else {
        return <- min_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    }
}

[skip_lock_check]
def min(var src : iterator<auto(TT)>) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_impl(src, type<TT -const -&>)
    } else {
        return <- min_impl(src, type<TT -const -&>)
    }
}

[skip_lock_check]
def min(src : array<auto(TT)>) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_impl_const(src, type<TT -const -&>)
    } else {
        return <- min_impl_const(src, type<TT -const -&>)
    }
}

[skip_lock_check, unused_argument(tt)]
def private min_by_impl(var src; tt : auto(TT); key) : TT -& -const {
    var minn : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            first = false
        } elif (_::less(key(x), key(minn))) {
            minn := x
        }
    }
    return <- minn
}

[skip_lock_check, unused_argument(tt)]
def private min_by_impl_const(src : auto(ARGT); tt : auto(TT); key) : TT -& -const {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
    } else {
        return <- min_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
    }
}

[skip_lock_check]
def min_by(var src : iterator<auto(TT)>; key) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_by_impl(src, type<TT -const -&>, key)
    } else {
        return <- min_by_impl(src, type<TT -const -&>, key)
    }
}

[skip_lock_check]
def min_by(src : array<auto(TT)>; key) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_by_impl_const(src, type<TT -const -&>, key)
    } else {
        return <- min_by_impl_const(src, type<TT -const -&>, key)
    }
}

[skip_lock_check, unused_argument(tt)]
def private max_impl(var src; tt : auto(TT)) : TT -& -const {
    var maxx : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            maxx := x
            first = false
        } elif (_::less(maxx, x)) {
            maxx := x
        }
    }
    return <- maxx
}

[skip_lock_check, unused_argument(tt)]
def private max_impl_const(src : auto(ARGT); tt : auto(TT)) : TT -& -const {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    } else {
        return <- max_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    }
}

[skip_lock_check]
def max(var src : iterator<auto(TT)>) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_impl(src, type<TT -const -&>)
    } else {
        return <- max_impl(src, type<TT -const -&>)
    }
}

[skip_lock_check]
def max(src : array<auto(TT)>) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_impl_const(src, type<TT -const -&>)
    } else {
        return <- max_impl_const(src, type<TT -const -&>)
    }
}

[skip_lock_check, unused_argument(tt)]
def private max_by_impl(var src; tt : auto(TT); key) : TT -& -const {
    var maxx : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            maxx := x
            first = false
        } elif (_::less(key(maxx), key(x))) {
            maxx := x
        }
    }
    return <- maxx
}

[skip_lock_check, unused_argument(tt)]
def private max_by_impl_const(src : auto(ARGT); tt : auto(TT); key) : TT -& -const {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
    } else {
        return <- max_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
    }
}

[skip_lock_check]
def max_by(var src : iterator<auto(TT)>; key) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_by_impl(src, type<TT -const -&>, key)
    } else {
        return <- max_by_impl(src, type<TT -const -&>, key)
    }
}

[skip_lock_check]
def max_by(src : array<auto(TT)>; key) : TT -& -const {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return max_by_impl_const(src, type<TT -const -&>, key)
    } else {
        return <- max_by_impl_const(src, type<TT -const -&>, key)
    }
}

[skip_lock_check, unused_argument(tt)]
def private min_max_impl(var src; tt : auto(TT)) : tuple<TT -& -const, TT -& -const> {
    var minn : TT -& -const
    var maxx : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            maxx := x
            first = false
        } else {
            if (_::less(x, minn)) {
                minn := x
            } elif (_::less(maxx, x)) {
                maxx := x
            }
        }
    }
    return <- (minn, maxx)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_impl_const(src : auto(ARGT); tt : auto(TT)) : tuple<TT -& -const, TT -& -const> {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return min_max_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    } else {
        return <- min_max_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    }
}

[skip_lock_check]
def min_max(var src : iterator<auto(TT)>) : tuple<TT -& -const, TT -& -const> {
    
    return <- min_max_impl(src, type<TT -const -&>)
}

[skip_lock_check]
def min_max(src : array<auto(TT)>) : tuple<TT -& -const, TT -& -const> {
    
    return <- min_max_impl_const(src, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_by_impl(var src; tt : auto(TT); key) : tuple<TT -& -const, TT -& -const> {
    var minn : TT -& -const
    var maxx : TT -& -const
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            maxx := x
            first = false
        } else {
            if (_::less(key(x), key(minn))) {
                minn := x
            } elif (_::less(key(maxx), key(x))) {
                maxx := x
            }
        }
    }
    return <- (minn, maxx)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_by_impl_const(src : auto(ARGT); tt : auto(TT); key) : tuple<TT -& -const, TT -& -const> {
    return <- min_max_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
}

[skip_lock_check]
def min_max_by(var src : iterator<auto(TT)>; key) : tuple<TT -& -const, TT -& -const> {
    
    return <- min_max_by_impl(src, type<TT -const -&>, key)
}

[skip_lock_check]
def min_max_by(src : array<auto(TT)>; key) : tuple<TT -& -const, TT -& -const> {
    
    return <- min_max_by_impl_const(src, type<TT -const -&>, key)
}

[skip_lock_check, unused_argument(tt)]
def private aggregate_impl(var src; tt : auto(TT); seed : auto(AGG); func : block<(acc : AGG -&, x : TT -&) : AGG -&>) : AGG -& -const {
    var acc : AGG -& := seed
    for (x in src) {
        static_if (typeinfo can_copy(x)) {
            acc = func(acc, x)
        } else {
            acc <- func(acc, x)
        }
    }
    return <- acc
}

[skip_lock_check, unused_argument(tt)]
def private aggregate_impl_const(src : auto(ARGT); tt : auto(TT); seed : auto(AGG); func : block<(acc : AGG -&, x : TT -&) : AGG -&>) : AGG -& -const {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return aggregate_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, seed, func)
    } else {
        return <- aggregate_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, seed, func)
    }
}

[skip_lock_check]
def aggregate(var src : iterator<auto(TT)>; seed : auto(AGG); func : block<(acc : AGG -&, x : TT -&) : AGG -&>) : AGG -& -const {
    
    static_if (typeinfo is_workhorse(seed)) {
        return aggregate_impl(src, type<TT -const -&>, seed, func)
    } else {
        return <- aggregate_impl(src, type<TT -const -&>, seed, func)
    }
}

[skip_lock_check]
def aggregate(src : array<auto(TT)>; seed : auto(AGG); func : block<(acc : AGG -&, x : TT -&) : AGG -&>) : AGG -& -const {
    
    static_if (typeinfo is_workhorse(seed)) {
        return aggregate_impl_const(src, type<TT -const -&>, seed, func)
    } else {
        return <- aggregate_impl_const(src, type<TT -const -&>, seed, func)
    }
}

[skip_lock_check, unused_argument(tt)]
def private sum_impl(var src; tt : auto(TT)) : TT -const -& {
    var total : TT -const -&
    for (x in src) {
        total += x
    }
    return <- total
}

[skip_lock_check, unused_argument(tt)]
def private sum_impl_const(src : auto(ARGT); tt : auto(TT)) : TT -const -& {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return sum_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    } else {
        return <- sum_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    }
}

[skip_lock_check]
def sum(var src : iterator<auto(TT)>) : TT -const -& {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return sum_impl(src, type<TT -const -&>)
    } else {
        return <- sum_impl(src, type<TT -const -&>)
    }
}

[skip_lock_check]
def sum(src : array<auto(TT)>) : TT -const -& {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return sum_impl_const(src, type<TT -const -&>)
    } else {
        return <- sum_impl_const(src, type<TT -const -&>)
    }
}

[skip_lock_check, unused_argument(tt)]
def average_impl(var src; tt : auto(TT)) : TT -const -& {
    var total : TT -const -&
    var count : uint64
    for (x in src) {
        total += x
        count ++
    }
    if (count != 0ul) {
        static_if (typeinfo is_workhorse(type<TT>)) {
            total /= TT(count)
        } else {
            total /= count
        }
    }
    return <- total
}

[skip_lock_check, unused_argument(tt)]
def average_impl_const(src : auto(ARGT); tt : auto(TT)) : TT -const -& {
    static_if (typeinfo is_workhorse(type<TT>)) {
        return average_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    } else {
        return <- average_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
    }
}

[skip_lock_check]
def average(var src : iterator<auto(TT)>) : TT -const -& {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return average_impl(src, type<TT -const -&>)
    } else {
        return <- average_impl(src, type<TT -const -&>)
    }
}

[skip_lock_check]
def average(src : array<auto(TT)>) : TT -const -& {
    
    static_if (typeinfo is_workhorse(type<TT>)) {
        return average_impl_const(src, type<TT -const -&>)
    } else {
        return <- average_impl_const(src, type<TT -const -&>)
    }
}

[skip_lock_check, unused_argument(tt)]
def private min_max_average_impl(var src; tt : auto(TT)) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    var minn : TT -const -&
    var maxx : TT -const -&
    var total : TT -const -&
    var count : uint64
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            maxx := x
            total := x
            first = false
        } else {
            if (_::less(x, minn)) {
                minn := x
            } elif (_::less(maxx, x)) {
                maxx := x
            }
            total += x
        }
        count ++
    }
    if (count != 0ul) {
        static_if (typeinfo is_workhorse(type<TT>)) {
            total /= TT(count)
        } else {
            total /= count
        }
    }
    return <- (minn, maxx, total)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_average_impl_const(src : auto(ARGT); tt : auto(TT)) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    return <- min_max_average_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
}

[skip_lock_check]
def min_max_average(var src : iterator<auto(TT)>) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    
    return <- min_max_average_impl(src, type<TT -const -&>)
}

[skip_lock_check]
def min_max_average(src : array<auto(TT)>) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    
    return <- min_max_average_impl_const(src, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_average_by_impl(var src; tt : auto(TT); key) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    var minn : TT -const -&
    var maxx : TT -const -&
    var total : TT -const -&
    var count : uint64
    var first : bool = true
    for (x in src) {
        if (first) {
            minn := x
            maxx := x
            total := x
            first = false
        } else {
            if (_::less(key(x), key(minn))) {
                minn := x
            } elif (_::less(key(maxx), key(x))) {
                maxx := x
            }
            total += x
        }
        count ++
    }
    if (count != 0ul) {
        static_if (typeinfo is_workhorse(type<TT>)) {
            total /= TT(count)
        } else {
            total /= count
        }
    }
    return <- (minn, maxx, total)
}

[skip_lock_check, unused_argument(tt)]
def private min_max_average_by_impl_const(src : auto(ARGT); tt : auto(TT); key) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    return <- min_max_average_by_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, key)
}

[skip_lock_check]
def min_max_average_by(var src : iterator<auto(TT)>; key) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    
    return <- min_max_average_by_impl(src, type<TT -const -&>, key)
}

[skip_lock_check]
def min_max_average_by(src : array<auto(TT)>; key) : tuple<TT -const -&, TT -const -&, TT -const -&> {
    
    return <- min_max_average_by_impl_const(src, type<TT -const -&>, key)
}

[skip_lock_check]
def private join_impl(var srca; var srcb; ta : auto(TA); tb : auto(TB); keya, keyb; result) : array<typedecl(result(type<TA>, type<TB>)) -const -&> {
    
    var inscope tableb : table<typedecl(_::unique_key(keyb(type<TB>))); array<TB -const -&>>
    for (itb in srcb) {
        let k = _::unique_key(keyb(itb))
        unsafe(tableb[k]).push_clone(itb)
    }
    var buffer : array<typedecl(result(type<TA>, type<TB>)) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (ita in srca) {
        let k = _::unique_key(keya(ita))
        tableb.get(k, $(arr){
            for (itb in arr) {
                buffer.push_clone(result(ita, itb))
            }
        })
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check]
def private join_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); ta : auto(TA); tb : auto(TB); keya, keyb; result) : array<typedecl(result(type<TA>, type<TB>)) -const -&> {
    return <- join_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check]
def join(var srca : iterator<auto(TA)>; var srcb : iterator<auto(TB)>; keya, keyb; result) : iterator<typedecl(result(type<TA>, type<TB>)) -const -&> {
    
    return <- join_impl(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result).to_sequence_move()
}

[skip_lock_check]
def join(srca : array<auto(TA)>; srcb : array<auto(TB)>; keya, keyb; result) : array<typedecl(result(type<TA>, type<TB>)) -const -&> {
    
    return <- join_impl_const(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check]
def join_to_array(var srca : iterator<auto(TA)>; var srcb : iterator<auto(TB)>; keya, keyb; result) : array<typedecl(result(type<TA>, type<TB>)) -const -&> {
    
    return <- join_impl(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check, unused_argument(ta, tb)]
def private group_join_impl(var srca; var srcb; ta : auto(TA); tb : auto(TB); keya, keyb; result) : array<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&> {
    
    var inscope tableb : table<typedecl(_::unique_key(keyb(type<TB>))); array<TB -const -&>>
    for (itb in srcb) {
        let k = _::unique_key(keyb(itb))
        unsafe(tableb[k]).push_clone(itb)
    }
    var buffer : array<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (ita in srca) {
        let k = _::unique_key(keya(ita))
        tableb.get(k, $(var arr){
            buffer.push_clone(result(ita, arr))
        })
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(ta, tb)]
def private group_join_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); ta : auto(TA); tb : auto(TB); keya, keyb; result) : array<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&> {
    return <- group_join_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check]
def group_join(var srca : iterator<auto(TA)>; var srcb : iterator<auto(TB)>; keya, keyb; result) : iterator<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&> {
    
    return <- group_join_impl(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result).to_sequence_move()
}

[skip_lock_check]
def group_join(srca : array<auto(TA)>; srcb : array<auto(TB)>; keya, keyb; result) : array<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&> {
    
    return <- group_join_impl_const(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check]
def group_join_to_array(var srca : iterator<auto(TA)>; var srcb : iterator<auto(TB)>; keya, keyb; result) : array<typedecl(result(type<TA>, type<array<TB -const -&>>)) -const -&> {
    
    return <- group_join_impl(srca, srcb, type<TA -const -&>, type<TB -const -&>, keya, keyb, result)
}

[skip_lock_check, unused_argument(tt)]
def private group_by_impl(var source; tt : auto(TT); key; element_selector; result_selector)  {
    var tab : table<typedecl(_::unique_key(key(type<TT>))); tuple<typedecl(key(type<TT>)), array<typedecl(element_selector(type<TT>)) -const -&>>>
    for (it in source) {
        let kIT = key(it)
        let k = _::unique_key(kIT)
        if (tab.key_exists(k)) {
            unsafe(tab[k])._1.push_clone(element_selector(it))
        } else {
            unsafe(tab[k]) = (kIT, [element_selector(it)])
        }
    }
    var buffer : array<typedecl(result_selector(type<typedecl(key(type<TT>))>, type<iterator<typedecl(element_selector(type<TT>)) -const -&>>)) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in values(tab)) {
        buffer.push_clone(result_selector(it._0, it._1.to_sequence()))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private group_by_impl_const(source : auto(ARGT); tt : auto(TT); key; element_selector; result_selector)  {
    return <- group_by_impl(unsafe(reinterpret<ARGT -const>(source)), type<TT -const -&>, key, element_selector, result_selector)
}

[skip_lock_check]
def group_by(var source : iterator<auto(TT)>; key; element_selector; result_selector)  {
    
    return <- group_by_impl(source, type<TT -const -&>, key, element_selector, result_selector).to_sequence_move()
}

[skip_lock_check]
def group_by(source : array<auto(TT)>; key; element_selector; result_selector)  {
    
    return <- group_by_impl_const(source, type<TT -const -&>, key, element_selector, result_selector)
}

[skip_lock_check]
def group_by_to_array(var source : iterator<auto(TT)>; key; element_selector; result_selector)  {
    
    return <- group_by_impl(source, type<TT -const -&>, key, element_selector, result_selector)
}

[skip_lock_check, unused_argument(tt)]
def private union_impl(var srca; var srcb; tt : auto(TT)) : array<TT -const -&> {
    
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var inscope seen : table<typedecl(_::unique_key(type<TT>))>
    for (ita in srca) {
        let k = _::unique_key(ita)
        if (!seen.key_exists(k)) {
            buffer.push_clone(ita)
            seen.insert(k)
        }
    }
    for (itb in srcb) {
        let k = _::unique_key(itb)
        if (!seen.key_exists(k)) {
            buffer.push_clone(itb)
            seen.insert(k)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private union_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); tt : auto(TT)) : array<TT -const -&> {
    return <- union_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TT -const -&>)
}

[skip_lock_check]
def union(var srca, srcb : array<auto(TT)>) : array<TT -const -&> {
    
    return <- union_impl_const(srca, srcb, type<TT -const -&>)
}

[skip_lock_check]
def union(var srca, srcb : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return <- union_impl(srca, srcb, type<TT -const -&>).to_sequence_move()
}

[skip_lock_check]
def union_to_array(var srca, srcb : iterator<auto(TT)>) : array<TT -const -&> {
    
    return <- union_impl(srca, srcb, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private union_by_impl(var srca; var srcb; tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var inscope seen : table<typedecl(_::unique_key(key(type<TT>)))>
    for (ita in srca) {
        let k = _::unique_key(key(ita))
        if (!seen.key_exists(k)) {
            buffer.push_clone(ita)
            seen.insert(k)
        }
    }
    for (itb in srcb) {
        let k = _::unique_key(key(itb))
        if (!seen.key_exists(k)) {
            buffer.push_clone(itb)
            seen.insert(k)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private union_by_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    return <- union_by_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TT -const -&>, key)
}

[skip_lock_check]
def union_by(var srca, srcb : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : iterator<TT -const -&> {
    
    return <- union_by_impl(srca, srcb, type<TT -const -&>, key).to_sequence_move()
}

[skip_lock_check]
def union_by(srca, srcb : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- union_by_impl_const(srca, srcb, type<TT -const -&>, key)
}

[skip_lock_check]
def union_by_to_array(var srca, srcb : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- union_by_impl(srca, srcb, type<TT -const -&>, key)
}

[skip_lock_check]
def any(src : array<auto(TT)>) : bool {
    
    return length(src) != 0
}

[skip_lock_check]
def any(var src : iterator<auto(TT)>) : bool {
    
    for (it in src) {
        return true
    }
    return false
}

[skip_lock_check, unused_argument(tt)]
def private any_impl(var src; tt : auto(TT); predicate : block<(arg : auto(TT) -&) : bool>) : bool {
    for (it in src) {
        if (predicate(it)) {
            return true
        }
    }
    return false
}

[skip_lock_check, unused_argument(tt)]
def private any_impl_const(src : auto(ARGT); tt : auto(TT); predicate : block<(arg : auto(TT) -&) : bool>) : bool {
    return any_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, predicate)
}

[skip_lock_check]
def any(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : bool {
    
    return any_impl(src, type<TT -const -&>, predicate)
}

[skip_lock_check]
def any(src : array<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : bool {
    
    return any_impl_const(src, type<TT -const -&>, predicate)
}

[skip_lock_check, unused_argument(tt)]
def private all_impl(var src; tt : auto(TT); predicate : block<(arg : auto(TT) -&) : bool>) : bool {
    for (it in src) {
        if (!predicate(it)) {
            return false
        }
    }
    return true
}

[skip_lock_check, unused_argument(tt)]
def private all_impl_const(src : auto(ARGT); tt : auto(TT); predicate : block<(arg : auto(TT) -&) : bool>) : bool {
    return all_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, predicate)
}

[skip_lock_check]
def all(var src : iterator<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : bool {
    
    return all_impl(src, type<TT -const -&>, predicate)
}

[skip_lock_check]
def all(src : array<auto(TT)>; predicate : block<(arg : TT -&) : bool>) : bool {
    
    return all_impl_const(src, type<TT -const -&>, predicate)
}

[skip_lock_check, unused_argument(tt)]
def private except_impl(var src, exclude; tt : auto(TT)) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(type<TT>))>
    for (it in exclude) {
        seen.insert(_::unique_key(it))
    }
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in src) {
        if (!seen.key_exists(_::unique_key(it))) {
            buffer.push_clone(it)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private except_impl_const(src : auto(ARGT); exclude : auto(ARGTE); tt : auto(TT)) : array<TT -const -&> {
    return <- except_impl(unsafe(reinterpret<ARGT -const>(src)), unsafe(reinterpret<ARGTE -const>(exclude)), type<TT -const -&>)
}

[skip_lock_check]
def except(var src, exclude : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return <- except_impl(src, exclude, type<TT -const -&>).to_sequence_move()
}

[skip_lock_check]
def except(src, exclude : array<auto(TT)>) : array<TT -const -&> {
    
    return <- except_impl_const(src, exclude, type<TT -const -&>)
}

[skip_lock_check]
def except_to_array(var src, exclude : iterator<auto(TT)>) : array<TT -const -&> {
    
    return <- except_impl(src, exclude, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private except_by_impl(var src, exclude; tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(key(type<TT>)))>
    for (it in exclude) {
        seen.insert(_::unique_key(key(it)))
    }
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in src) {
        if (!seen.key_exists(_::unique_key(key(it)))) {
            buffer.push_clone(it)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private except_by_impl_const(src : auto(ARGT); exclude : auto(ARGTE); tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    return <- except_by_impl(unsafe(reinterpret<ARGT -const>(src)), unsafe(reinterpret<ARGTE -const>(exclude)), type<TT -const -&>, key)
}

[skip_lock_check]
def except_by(var src, exclude : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : iterator<TT -const -&> {
    
    return <- except_by_impl(src, exclude, type<TT -const -&>, key).to_sequence_move()
}

[skip_lock_check]
def except_by(src, exclude : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- except_by_impl_const(src, exclude, type<TT -const -&>, key)
}

[skip_lock_check]
def except_by_to_array(var src, exclude : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- except_by_impl(src, exclude, type<TT -const -&>, key)
}

[skip_lock_check, unused_argument(tt)]
def private intersect_impl(var srca, srcb; tt : auto(TT)) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(type<TT>))>
    for (it in srca) {
        seen.insert(_::unique_key(it))
    }
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in srcb) {
        if (seen.key_exists(_::unique_key(it))) {
            buffer.push_clone(it)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private intersect_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); tt : auto(TT)) : array<TT -const -&> {
    return <- intersect_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TT -const -&>)
}

[skip_lock_check]
def intersect(var srca, srcb : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return <- intersect_impl(srca, srcb, type<TT -const -&>).to_sequence_move()
}

[skip_lock_check]
def intersect(srca, srcb : array<auto(TT)>) : array<TT -const -&> {
    
    return <- intersect_impl_const(srca, srcb, type<TT -const -&>)
}

[skip_lock_check]
def intersect_to_array(var srca, srcb : iterator<auto(TT)>) : array<TT -const -&> {
    
    return <- intersect_impl(srca, srcb, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private intersect_by_impl(var srca, srcb; tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    var inscope seen : table<typedecl(_::unique_key(key(type<TT>)))>
    for (it in srca) {
        seen.insert(_::unique_key(key(it)))
    }
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in srcb) {
        if (seen.key_exists(_::unique_key(key(it)))) {
            buffer.push_clone(it)
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private intersect_by_impl_const(srca : auto(ARGTA); srcb : auto(ARGTB); tt : auto(TT); key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    return <- intersect_by_impl(unsafe(reinterpret<ARGTA -const>(srca)), unsafe(reinterpret<ARGTB -const>(srcb)), type<TT -const -&>, key)
}

[skip_lock_check]
def intersect_by(var srca, srcb : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : iterator<TT -const -&> {
    
    return <- intersect_by_impl(srca, srcb, type<TT -const -&>, key).to_sequence_move()
}

[skip_lock_check]
def intersect_by(srca, srcb : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- intersect_by_impl_const(srca, srcb, type<TT -const -&>, key)
}

[skip_lock_check]
def intersect_by_to_array(var srca, srcb : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : array<TT -const -&> {
    
    return <- intersect_by_impl(srca, srcb, type<TT -const -&>, key)
}

[skip_lock_check, unused_argument(tt)]
def private contains_impl(var src; tt : auto(TT); element : TT -&) : bool {
    for (it in src) {
        if (it == element) {
            return true
        }
    }
    return false
}

[skip_lock_check, unused_argument(tt)]
def private contains_impl_const(src : auto(ARGT); tt : auto(TT); element : TT -&) : bool {
    return contains_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, element)
}

[skip_lock_check]
def contains(var src : iterator<auto(TT)>; element : TT -&) : bool {
    
    return contains_impl(src, type<TT -const -&>, element)
}

[skip_lock_check]
def contains(src : array<auto(TT)>; element : TT -&) : bool {
    
    return contains_impl_const(src, type<TT -const -&>, element)
}

[skip_lock_check, unused_argument(typ)]
def empty(var typ : auto(TT)) : iterator<TT -const -&> {
    
    return <- generator<TT -const -&>() <| $ {
        return false
    }
}

[skip_lock_check]
def default_empty(var src : iterator<auto(TT)>) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- src) () <| $ {
        var found = false
        for (it in src) {
            found = true
            static_if (typeinfo can_copy(it)) {
                yield it
            } else {
                yield <- clone_to_move(it)
            }
        }
        if (!found) {
            var t : TT -const -&
            static_if (typeinfo can_copy(t)) {
                yield t
            } else {
                yield <- clone_to_move(t)
            }
        }
        return false
    }
}

[skip_lock_check]
def range_sequence(start : int; count : int) : iterator<int> {
    
    return each(start..start + count)
}

[skip_lock_check]
def repeat(element : auto(TT); count : int) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(:= element) () <| $ {
        for (i in 0..count) {
            static_if (typeinfo can_copy(element)) {
                yield element
            } else {
                yield <- clone_to_move(element)
            }
        }
        return false
    }
}

[skip_lock_check, unused_argument(tt)]
def private sequence_equal_impl(var first, second; tt : auto(TT)) : bool {
    for (f, s in first, second) {
        if (f != s) {
            return false
        }
    }
    return true
}

[skip_lock_check, unused_argument(tt)]
def private sequence_equal_impl_const(first : auto(ARGT); second : auto(ARGTS); tt : auto(TT)) : bool {
    return sequence_equal_impl(unsafe(reinterpret<ARGT -const>(first)), unsafe(reinterpret<ARGTS -const>(second)), type<TT -const -&>)
}

[skip_lock_check]
def sequence_equal(var first, second : iterator<auto(TT)>) : bool {
    
    return sequence_equal_impl(first, second, type<TT -const -&>)
}

[skip_lock_check]
def sequence_equal(first, second : array<auto(TT)>) : bool {
    
    return sequence_equal_impl_const(first, second, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private sequence_equal_by_impl(var first, second; tt : auto(TT); key : block<(arg : TT -&) : auto>) : bool {
    for (f, s in first, second) {
        if (key(f) != key(s)) {
            return false
        }
    }
    return true
}

[skip_lock_check, unused_argument(tt)]
def private sequence_equal_by_impl_const(first : auto(ARGT); second : auto(ARGTS); tt : auto(TT); key : block<(arg : TT -&) : auto>) : bool {
    return sequence_equal_by_impl(unsafe(reinterpret<ARGT -const>(first)), unsafe(reinterpret<ARGTS -const>(second)), type<TT -const -&>, key)
}

[skip_lock_check]
def sequence_equal_by(var first, second : iterator<auto(TT)>; key : block<(arg : TT -&) : auto>) : bool {
    
    return sequence_equal_by_impl(first, second, type<TT -const -&>, key)
}

[skip_lock_check]
def sequence_equal_by(first, second : array<auto(TT)>; key : block<(arg : TT -&) : auto>) : bool {
    
    return sequence_equal_by_impl_const(first, second, type<TT -const -&>, key)
}

[skip_lock_check]
def element_at(src : array<auto(TT)>; index : int) : TT -const -& {
    
    panic("element index out of range") if (index < 0 || index >= length(src))
    static_if (typeinfo can_copy(src[index])) {
        return src[index]
    } else {
        return <- clone_to_move(src[index])
    }
}

[skip_lock_check]
def element_at(var src : iterator<auto(TT)>; index : int) : TT -const -& {
    
    panic("element index out of range") if (index < 0)
    var i = 0
    for (it in src) {
        if (i == index) {
            static_if (typeinfo can_copy(it)) {
                return it
            } else {
                return <- clone_to_move(it)
            }
        }
        i ++
    }
    panic("element index out of range")
    var t : TT -const -&
    return <- t
}

[skip_lock_check]
def element_at_or_default(src : array<auto(TT)>; index : int) : TT -const -& {
    
    if (index < 0 || index >= length(src)) {
        var t : TT -const -&
        return <- t
    }
    static_if (typeinfo can_copy(src[index])) {
        return src[index]
    } else {
        return <- clone_to_move(src[index])
    }
}

[skip_lock_check]
def element_at_or_default(var src : iterator<auto(TT)>; index : int) : TT -const -& {
    
    if (index < 0) {
        var t : TT -const -&
        return <- t
    }
    var i = 0
    for (it in src) {
        if (i == index) {
            static_if (typeinfo can_copy(it)) {
                return it
            } else {
                return <- clone_to_move(it)
            }
        }
        i ++
    }
    var t : TT -const -&
    return <- t
}

[skip_lock_check]
def first(src : array<auto(TT)>) : TT -const -& {
    
    panic("sequence contains no elements") if (length(src) == 0)
    static_if (typeinfo can_copy(src[0])) {
        return src[0]
    } else {
        return <- clone_to_move(src[0])
    }
}

[skip_lock_check]
def first(var src : iterator<auto(TT)>) : TT -const -& {
    
    for (it in src) {
        static_if (typeinfo can_copy(it)) {
            return it
        } else {
            return <- clone_to_move(it)
        }
    }
    panic("sequence contains no elements")
    var t : TT -const -&
    return <- t
}

[skip_lock_check]
def first_or_default(src : array<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    if (length(src) == 0) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    static_if (typeinfo can_copy(src[0])) {
        return src[0]
    } else {
        return <- clone_to_move(src[0])
    }
}

[skip_lock_check]
def first_or_default(var src : iterator<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    for (it in src) {
        static_if (typeinfo can_copy(it)) {
            return it
        } else {
            return <- clone_to_move(it)
        }
    }
    static_if (typeinfo can_copy(defaultValue)) {
        return defaultValue
    } else {
        return <- clone_to_move(defaultValue)
    }
}

[skip_lock_check]
def last(src : array<auto(TT)>) : TT -const -& {
    
    let srcl = length(src)
    panic("sequence contains no elements") if (srcl == 0)
    static_if (typeinfo can_copy(src[srcl - 1])) {
        return src[srcl - 1]
    } else {
        return <- clone_to_move(src[srcl - 1])
    }
}

[skip_lock_check]
def last(var src : iterator<auto(TT)>) : TT -const -& {
    
    var found = false
    var last : TT -const -&
    for (it in src) {
        found = true
        last := it
    }
    if (!found) {
        panic("sequence contains no elements")
    }
    return <- last
}

[skip_lock_check]
def last_or_default(src : array<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    let srcl = length(src)
    if (srcl == 0) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    static_if (typeinfo can_copy(src[srcl - 1])) {
        return src[srcl - 1]
    } else {
        return <- clone_to_move(src[srcl - 1])
    }
}

[skip_lock_check]
def last_or_default(var src : iterator<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    var found = false
    var last : TT -const -&
    for (it in src) {
        found = true
        last := it
    }
    if (!found) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    return <- last
}

[skip_lock_check]
def single(src : array<auto(TT)>) : TT -const -& {
    
    let srcl = length(src)
    if (srcl == 0) {
        panic("sequence contains no elements")
    }
    if (srcl > 1) {
        panic("sequence contains more than one element")
    }
    static_if (typeinfo can_copy(src[0])) {
        return src[0]
    } else {
        return <- clone_to_move(src[0])
    }
}

[skip_lock_check]
def single(var src : iterator<auto(TT)>) : TT -const -& {
    
    var found = false
    var single : TT -const -&
    for (it in src) {
        if (found) {
            panic("sequence contains more than one element")
        }
        found = true
        single := it
    }
    if (!found) {
        panic("sequence contains no elements")
    }
    return <- single
}

[skip_lock_check]
def single_or_default(src : array<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    let srcl = length(src)
    if (srcl == 0) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    if (srcl > 1) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    static_if (typeinfo can_copy(src[0])) {
        return src[0]
    } else {
        return <- clone_to_move(src[0])
    }
}

[skip_lock_check]
def single_or_default(var src : iterator<auto(TT)>; defaultValue : TT -&) : TT -const -& {
    
    var found = false
    var single : TT -const -&
    for (it in src) {
        if (found) {
            static_if (typeinfo can_copy(defaultValue)) {
                return defaultValue
            } else {
                return <- clone_to_move(defaultValue)
            }
        }
        found = true
        single := it
    }
    if (!found) {
        static_if (typeinfo can_copy(defaultValue)) {
            return defaultValue
        } else {
            return <- clone_to_move(defaultValue)
        }
    }
    return <- single
}

[skip_lock_check]
def private prepend_impl(var arr; tt : auto(TT); reserveSize : int; value : TT -&) : array<TT -const -&> {
    
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    if (reserveSize > 0) {
        buffer.reserve(reserveSize)
    }
    buffer.push_clone(value)
    for (x in arr) {
        buffer.push_clone(x)
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check]
def private prepend_impl_const(arr : auto(ARGT); tt : auto(TT); reserveSize : int; value : TT -&) : array<TT -const -&> {
    return <- prepend_impl(unsafe(reinterpret<ARGT -const>(arr)), type<TT -const -&>, reserveSize, value)
}

[skip_lock_check]
def prepend(arr : array<auto(TT)>; value : TT -&) : array<TT -const -&> {
    
    return <- prepend_impl_const(arr, type<TT -const -&>, length(arr) + 1, value)
}

[skip_lock_check]
def prepend_to_array(var it : iterator<auto(TT)>; value : TT -&) : array<TT -const -&> {
    
    return <- prepend_impl(it, type<TT -const -&>, 0, value)
}

[skip_lock_check]
def prepend(var it : iterator<auto(TT)>; value : TT -&) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- it, := value) () <| $ {
        static_if (typeinfo can_copy(value)) {
            yield value
        } else {
            yield <- clone_to_move(value)
        }
        for (x in it) {
            static_if (typeinfo can_copy(x)) {
                yield x
            } else {
                yield <- clone_to_move(x)
            }
        }
        return false
    }
}

[skip_lock_check]
def prepend_inplace(var arr : array<auto(TT)>; value : TT -&) {
    
    arr.push_clone(value, 0)
}

[skip_lock_check, unused_argument(tt)]
def private append_impl(var arr; tt : auto(TT); reserveSize : int; value : TT -&) : array<TT -const -&> {
    
    var buffer : array<TT -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    if (reserveSize > 0) {
        buffer.reserve(reserveSize)
    }
    for (x in arr) {
        buffer.push_clone(x)
    }
    buffer.push_clone(value)
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private append_impl_const(arr : auto(ARGT); tt : auto(TT); reserveSize : int; value : TT -&) : array<TT -const -&> {
    return <- append_impl(unsafe(reinterpret<ARGT -const>(arr)), type<TT -const -&>, reserveSize, value)
}

[skip_lock_check]
def append(arr : array<auto(TT)>; value : TT -&) : array<TT -const -&> {
    
    return <- append_impl_const(arr, type<TT -const -&>, length(arr) + 1, value)
}

[skip_lock_check]
def append_to_array(var it : iterator<auto(TT)>; value : TT -&) : array<TT -const -&> {
    
    return <- append_impl(it, type<TT -const -&>, 0, value)
}

[skip_lock_check]
def append(var it : iterator<auto(TT)>; value : TT -&) : iterator<TT -const -&> {
    
    return generator<TT -const -&> capture(<- it, := value) () <| $ {
        for (x in it) {
            static_if (typeinfo can_copy(x)) {
                yield x
            } else {
                yield <- clone_to_move(x)
            }
        }
        static_if (typeinfo can_copy(value)) {
            yield value
        } else {
            yield <- clone_to_move(value)
        }
        return false
    }
}

[skip_lock_check]
def append_inplace(var arr : array<auto(TT)>; value : TT -&) {
    
    arr.push_clone(value)
}

[skip_lock_check, unused_argument(tt)]
def private select_impl(var src; tt : auto(TT)) : array<tuple<int, TT -const -&>> {
    
    var buffer : array<tuple<int, TT -const -&>>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    for (it, index in src, count()) {
        buffer.emplace((index, it))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private select_impl_const(src : auto(ARGT); tt : auto(TT)) : array<tuple<int, TT -const -&>> {
    return <- select_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>)
}

[skip_lock_check]
def select(var src : iterator<auto(TT)>) : iterator<tuple<int, TT -const -&>> {
    
    return <- select_impl(src, type<TT -const -&>).to_sequence_move()
}

[skip_lock_check]
def select(src : array<auto(TT)>) : array<tuple<int, TT -const -&>> {
    
    return <- select_impl_const(src, type<TT -const -&>)
}

[skip_lock_check]
def select_to_array(var src : iterator<auto(TT)>) : array<tuple<int, TT -const -&>> {
    
    return <- select_impl(src, type<TT -const -&>)
}

[skip_lock_check, unused_argument(tt)]
def private select_impl(var src; tt : auto(TT); len : int; selector) : array<typedecl(selector(type<TT>)) -const -&> {
    
    var buffer : array<typedecl(selector(type<TT>)) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    buffer.reserve(len)
    for (it in src) {
        buffer.push_clone(selector(it))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private select_impl_const(src : auto(ARGT); tt : auto(TT); len : int; selector) : array<typedecl(selector(type<TT>)) -const -&> {
    return <- select_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, len, selector)
}

[skip_lock_check]
def select(var src : iterator<auto(TT)>; result_selector) : iterator<typedecl(result_selector(type<TT>)) -const -&> {
    return <- select_impl(src, type<TT -const -&>, 0, result_selector).to_sequence_move()
}

[skip_lock_check]
def select(src : array<auto(TT)>; result_selector) : array<typedecl(result_selector(type<TT>)) -const -&> {
    return <- select_impl_const(src, type<TT -const -&>, length(src), result_selector)
}

[skip_lock_check]
def select_to_array(var src : iterator<auto(TT)>; result_selector) : array<typedecl(result_selector(type<TT>)) -const -&> {
    return <- select_impl(src, type<TT -const -&>, 0, result_selector)
}

[skip_lock_check, unused_argument(tt)]
def private chunk_impl(var src; tt : auto(TT); size : int) : array<array<TT -const -&>> {
    
    panic("chunk size must be greater than 0") if (size <= 0)
    var buffer : array<array<TT -const -&>>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    var inscope chunk : array<TT -const -&>
    static_if (typeinfo need_lock_check(chunk)) {
        unsafe(set_verify_array_locks(chunk, false))
    }
    for (it in src) {
        chunk.push_clone(it)
        if (chunk.length() == size) {
            buffer.emplace(chunk)
        }
    }
    if (chunk.length() > 0) {
        buffer.emplace(chunk)
    }
    static_if (typeinfo need_lock_check(chunk)) {
        unsafe(set_verify_array_locks(chunk, true))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private chunk_impl_const(src : auto(ARGT); tt : auto(TT); size : int) : array<array<TT -const -&>> {
    return <- chunk_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, size)
}

[skip_lock_check]
def chunk(src : array<auto(TT)>; size : int) : array<array<TT -const -&>> {
    
    return <- chunk_impl_const(src, type<TT -const -&>, size)
}

[skip_lock_check]
def chunk_to_array(var src : iterator<auto(TT)>; size : int) : array<array<TT -const -&>> {
    
    return <- chunk_impl(src, type<TT -const -&>, size)
}

[skip_lock_check]
def chunk(var src : iterator<auto(TT)>; size : int) : iterator<array<TT -const -&>> {
    
    return <- chunk_impl(src, type<TT -const -&>, size).to_sequence_move()
}

[unused_argument(src)]
def private iter_type(var src : iterator<auto(TT)>) : TT -const -& {
    
    var t : TT -const -&
    return <- t
}

[unused_argument(src)]
def private iter_type(src : array<auto(TT)>) : TT -const -& {
    
    var t : TT -const -&
    return <- t
}

[skip_lock_check, unused_argument(tt)]
def private select_many_impl(var src; tt : auto(TT); result_selector) : array<typedecl(result_selector(iter_type(type<TT>))) -const -&> {
    
    var buffer : array<typedecl(result_selector(iter_type(type<TT>))) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in src) {
        for (innerIt in it) {
            buffer.push_clone(result_selector(innerIt))
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private select_many_impl_const(src : auto(ARGT); tt : auto(TT); result_selector) : array<typedecl(result_selector(iter_type(type<TT>))) -const -&> {
    return <- select_many_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, result_selector)
}

[skip_lock_check]
def select_many(var src : iterator<auto(TT)>; result_selector) : iterator<typedecl(result_selector(iter_type(type<TT>))) -const -&> {
    
    return <- select_many_impl(src, type<TT -const -&>, result_selector).to_sequence_move()
}

[skip_lock_check]
def select_many(src : array<auto(TT)>; result_selector) : array<typedecl(result_selector(iter_type(type<TT>))) -const -&> {
    
    return <- select_many_impl_const(src, type<TT -const -&>, result_selector)
}

[skip_lock_check]
def select_many_to_array(var src : iterator<auto(TT)>; result_selector) : array<typedecl(result_selector(iter_type(type<TT>))) -const -&> {
    
    return <- select_many_impl(src, type<TT -const -&>, result_selector)
}

[skip_lock_check, unused_argument(tt)]
def private select_many_impl(var src; tt : auto(TT); collection_selector; result_selector) : array<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&> {
    
    var buffer : array<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (it in src) {
        for (innerIt in collection_selector(it)) {
            buffer.push_clone(result_selector(innerIt))
        }
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt)]
def private select_many_impl_const(src : auto(ARGT); tt : auto(TT); collection_selector; result_selector) : array<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&> {
    return <- select_many_impl(unsafe(reinterpret<ARGT -const>(src)), type<TT -const -&>, collection_selector, result_selector)
}

[skip_lock_check]
def select_many(var src : iterator<auto(TT)>; collection_selector; result_selector) : iterator<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&> {
    
    return <- select_many_impl(src, type<TT -const -&>, collection_selector, result_selector).to_sequence_move()
}

[skip_lock_check]
def select_many(src : array<auto(TT)>; collection_selector; result_selector) : array<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&> {
    
    return <- select_many_impl_const(src, type<TT -const -&>, collection_selector, result_selector)
}

[skip_lock_check]
def select_many_to_array(var src : iterator<auto(TT)>; collection_selector; result_selector) : array<typedecl(result_selector(iter_type(collection_selector(type<TT>)))) -const -&> {
    
    return <- select_many_impl(src, type<TT -const -&>, collection_selector, result_selector)
}

[skip_lock_check, unused_argument(tt, uu)]
def private zip_impl(var a; tt : auto(TT); var b; var uu : auto(UU)) : array<tuple<TT -const -&, UU -const -&>> {
    
    var buffer : array<tuple<TT -const -&, UU -const -&>>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (itA, itB in a, b) {
        buffer.emplace((itA, itB))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt, uu)]
def private zip_impl_const(a : auto(ARGT); tt : auto(TT); b : auto(ARGTS); uu : auto(UU)) : array<tuple<TT -const -&, UU -const -&>> {
    return <- zip_impl(unsafe(reinterpret<ARGT -const>(a)), type<TT -const -&>, unsafe(reinterpret<ARGTS -const>(b)), type<UU -const -&>)
}

[skip_lock_check]
def zip(var a : iterator<auto(TT)>; var b : iterator<auto(UU)>) : iterator<tuple<TT -const -&, UU -const -&>> {
    
    return <- zip_impl(a, type<TT -const -&>, b, type<UU -const -&>).to_sequence_move()
}

[skip_lock_check]
def zip(a : array<auto(TT)>; b : array<auto(UU)>) : array<tuple<TT -const -&, UU -const -&>> {
    
    return <- zip_impl_const(a, type<TT -const -&>, b, type<UU -const -&>)
}

[skip_lock_check]
def zip_to_array(var a : iterator<auto(TT)>; var b : iterator<auto(UU)>) : array<tuple<TT -const -&, UU -const -&>> {
    
    return <- zip_impl(a, type<TT -const -&>, b, type<UU -const -&>)
}

[skip_lock_check, unused_argument(tt, uu)]
def private zip_impl(var a; tt : auto(TT); var b; uu : auto(UU); result_selector : block<(l : TT -&; r : UU -&) : auto>) : array<typedecl(result_selector(type<TT>, type<UU>)) -const -&> {
    var buffer : array<typedecl(result_selector(type<TT>, type<UU>)) -const -&>
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, false))
    }
    for (itA, itB in a, b) {
        buffer.push_clone(result_selector(itA, itB))
    }
    static_if (typeinfo need_lock_check(buffer)) {
        unsafe(set_verify_array_locks(buffer, true))
    }
    return <- buffer
}

[skip_lock_check, unused_argument(tt, uu)]
def private zip_impl_const(a : auto(ARGT); tt : auto(TT); b : auto(ARGTS); uu : auto(UU); result_selector : block<(l : TT -&; r : UU -&) : auto>) : array<typedecl(result_selector(type<TT>, type<UU>)) -const -&> {
    return <- zip_impl(unsafe(reinterpret<ARGT -const>(a)), type<TT -const -&>, unsafe(reinterpret<ARGTS -const>(b)), type<UU -const -&>, result_selector)
}

[skip_lock_check]
def zip(var a : iterator<auto(TT)>; var b : iterator<auto(UU)>; result_selector : block<(l : TT -&; r : UU -&) : auto>) : iterator<typedecl(result_selector(type<TT>, type<UU>)) -const -&> {
    
    return <- zip_impl(a, type<TT -const -&>, b, type<UU -const -&>, result_selector).to_sequence_move()
}

[skip_lock_check]
def zip(a : array<auto(TT)>; b : array<auto(UU)>; result_selector : block<(l : TT -&; r : UU -&) : auto>) : array<typedecl(result_selector(type<TT>, type<UU>)) -const -&> {
    
    return <- zip_impl_const(a, type<TT -const -&>, b, type<UU -const -&>, result_selector)
}

[skip_lock_check]
def zip_to_array(var a : iterator<auto(TT)>; var b : iterator<auto(UU)>; result_selector : block<(l : TT -&; r : UU -&) : auto>) : array<typedecl(result_selector(type<TT>, type<UU>)) -const -&> {
    
    return <- zip_impl(a, type<TT -const -&>, b, type<UU -const -&>, result_selector)
}

[skip_lock_check]
def public order_unique_folded(var a : array<auto(TT)>) : array<TT -const -&> {
    
    var arr <- order(a)
    unique_inplace(arr)
    return <- arr
}

[skip_lock_check]
def public order_unique_folded(var a : iterator<auto(TT)>) : array<TT -const -&> {
    
    var arr <- to_array(a)
    order_inplace(arr)
    unique_inplace(arr)
    return <- arr
}

[skip_lock_check]
def public order_unique_folded_inplace(var a : array<auto(TT)>) {
    
    order_inplace(a)
    unique_inplace(a)
}
