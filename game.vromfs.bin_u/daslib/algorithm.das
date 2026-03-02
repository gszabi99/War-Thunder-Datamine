options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module algorithm shared public









require daslib/array_boost
require daslib/contracts

def unique(var a : array<auto(TT)>) {
    
    
    var pidx = -1
    var b : array<TT -const -&>
    for (e, eidx in a, range(length(a))) {
        if (pidx == -1 || a[pidx] != e) {
            pidx = eidx
            b |> push_clone(e)
        }
    }
    return <- b
}

def sort_unique(var a : array<auto(TT)>) {
    
    
    
    if (empty(a)) {
        return
    }
    sort(a)
    var b <- unique(a)
    delete a
    a <- b
}

def reverse(var a : array<auto>) {
    
    let l = length(a)
    let half = l / 2
    let lm1 = l - 1
    for (i in range(half)) {
        swap(a[i], a[lm1 - i])
    }
}

def combine(a, b : array<auto(TT)>) {
    
    var c : array<TT>
    reserve(c, length(a) + length(b))
    for (t in a) {
        c |> push_clone(t)
    }
    for (t in b) {
        c |> push_clone(t)
    }
    return <- c
}

def lower_bound(a : array<auto(TT)>; f, l : int; val : TT const -&) {
    
    assert(f >= 0 && f <= l, "lower bound first out of range")
    assert(l >= f && l <= length(a), "lower bound last out of range")
    var count = l - f
    var first = f
    while (count > 0) {
        let step = count / 2
        let it = first + step
        if (a[it] < val) {
            first += step + 1
            count -= step + 1
        } else {
            count = step
        }
    }
    return first
}

def lower_bound(a : array<auto(TT)>; val : TT const -&) {
    
    return lower_bound(a, 0, length(a), val)
}

def lower_bound(a : array<auto(TT)>; f, l : int; value : auto(QQ); less : block<(a : TT const -&, b : QQ) : bool>) {
    
    assert(f >= 0 && f <= l, "lower bound first out of range")
    assert(l >= f && l <= length(a), "lower bound last out of range")
    var count = l - f
    var first = f
    while (count > 0) {
        let step = count / 2
        let it = first + step
        if (invoke(less, a[it], value)) {
            first += step + 1
            count -= step + 1
        } else {
            count = step
        }
    }
    return first
}

def lower_bound(a : array<auto(TT)>; value : auto(QQ); less : block<(a : TT const -&, b : QQ) : bool>) {
    
    return lower_bound(a, 0, length(a), value, less)
}

def binary_search(a : array<auto(TT)>; val : TT const -&) {
    
    
    let first = lower_bound(a, val)
    return (first != length(a)) && (!(val < a[first]))
}

def binary_search(a : array<auto(TT)>; f, last : int; val : TT const -&) {
    
    
    let first = lower_bound(a, f, last, val)
    return (first != last) && (!(val < a[first]))
}

def binary_search(a : array<auto(TT)>; val : TT const -&; less : block<(a, b : TT const -&) : bool>) {
    
    
    let first = lower_bound(a, val, less)
    let last = length(a)
    return (first != last) && (!invoke(less, val, a[first]))
}

def binary_search(a : array<auto(TT)>; f, last : int; val : TT const -&; less : block<(a, b : TT const -&) : bool>) {
    
    
    let first = lower_bound(a, f, last, val, less)
    return (first != last) && (!invoke(less, val, a[first]))
}



def upper_bound(a : array<auto(TT)>; f, l : int; val : TT const -&) {
    
    assert(f >= 0 && f <= l, "upper bound first out of range")
    assert(l >= f && l <= length(a), "upper bound last out of range")
    var count = l - f
    var first = f
    while (count > 0) {
        let step = count / 2
        let it = first + step
        if (!(val < a[it])) {
            first += step + 1
            count -= step + 1
        } else {
            count = step
        }
    }
    return first
}

def upper_bound(a : array<auto(TT)>; val : TT const -&) {
    
    return upper_bound(a, 0, length(a), val)
}

def upper_bound(a : array<auto(TT)>; f, l : int; value : auto(QQ); less : block<(a : TT const -&, b : QQ) : bool>) {
    
    assert(f >= 0 && f <= l, "upper bound first out of range")
    assert(l >= f && l <= length(a), "upper bound last out of range")
    var count = l - f
    var first = f
    while (count > 0) {
        let step = count / 2
        let it = first + step
        if (!invoke(less, value, a[it])) {
            first += step + 1
            count -= step + 1
        } else {
            count = step
        }
    }
    return first
}

def upper_bound(a : array<auto(TT)>; value : auto(QQ); less : block<(a : TT const -&, b : QQ) : bool>) {
    
    return upper_bound(a, 0, length(a), value, less)
}



def equal_range(a : array<auto(TT)>; val : TT const -&) {
    
    
    let lo = lower_bound(a, val)
    let hi = upper_bound(a, val)
    return int2(lo, hi)
}

def equal_range(a : array<auto(TT)>; f, l : int; val : TT const -&) {
    
    
    let lo = lower_bound(a, f, l, val)
    let hi = upper_bound(a, f, l, val)
    return int2(lo, hi)
}



[expect_any_array(a)]
def reverse(var a) {
    
    unsafe {
        reverse(temp_array(a))
    }
}

[expect_any_array(a)]
def combine(a, b) {
    
    unsafe {
        return combine(temp_array(a), temp_array(b))
    }
}

[expect_any_array(a)]
def lower_bound(a; f, l : int; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return lower_bound(temp_array(a), f, l, val)
        }
    }
}

[expect_any_array(a)]
def lower_bound(a; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return lower_bound(temp_array(a), val)
        }
    }
}

[expect_any_array(a)]
def lower_bound(a; f, l : int; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return lower_bound(temp_array(a), f, l, val, less)
        }
    }
}

[expect_any_array(a)]
def lower_bound(a; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return lower_bound(temp_array(a), val, less)
        }
    }
}

[expect_any_array(a)]
def binary_search(a; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return false
    } else {
        unsafe {
            return binary_search(temp_array(a), val)
        }
    }
}

[expect_any_array(a)]
def binary_search(a; f, last : int; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return false
    } else {
        unsafe {
            return binary_search(temp_array(a), f, last, val)
        }
    }
}

[expect_any_array(a)]
def binary_search(a; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return false
    } else {
        unsafe {
            return binary_search(temp_array(a), val, less)
        }
    }
}

[expect_any_array(a)]
def binary_search(a; f, last : int; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return false
    } else {
        unsafe {
            return binary_search(temp_array(a), f, last, val, less)
        }
    }
}

[expect_any_array(a)]
def upper_bound(a; f, l : int; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return upper_bound(temp_array(a), f, l, val)
        }
    }
}

[expect_any_array(a)]
def upper_bound(a; val) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return upper_bound(temp_array(a), val)
        }
    }
}

[expect_any_array(a)]
def upper_bound(a; f, l : int; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return upper_bound(temp_array(a), f, l, val, less)
        }
    }
}

[expect_any_array(a)]
def upper_bound(a; val : auto(TT); less : block<(a, b : TT const -&) : bool>) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(val)) {
        concept_assert(false, "value type {typeinfo stripped_typename(val)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
        return -1
    } else {
        unsafe {
            return upper_bound(temp_array(a), val, less)
        }
    }
}

[expect_any_array(arr)]
def erase_all(var arr; value) {
    
    
    
    static_if (typeinfo stripped_typename(arr[0]) != typeinfo stripped_typename(value)) {
        concept_assert(false, "value type {typeinfo stripped_typename(value)} should be the same as array {typeinfo stripped_typename(arr)} element type {typeinfo stripped_typename(arr[0])}")
    } else {
        var write_idx = 0
        for (i in range(length(arr))) {
            if (arr[i] != value) {
                if (write_idx != i) {
                    swap(arr[write_idx], arr[i])
                }
                write_idx ++
            }
        }
        resize(arr, write_idx)
    }
}



def fill(var a : array<auto(TT)>; value : TT const -&) {
    
    for (i in range(length(a))) {
        a[i] := value
    }
}

[expect_any_array(a)]
def fill(var a; value) {
    
    static_if (typeinfo stripped_typename(a[0]) != typeinfo stripped_typename(value)) {
        concept_assert(false, "value type {typeinfo stripped_typename(value)} should be the same as array {typeinfo stripped_typename(a)} element type {typeinfo stripped_typename(a[0])}")
    } else {
        for (i in range(length(a))) {
            a[i] := value
        }
    }
}



def is_sorted(a : array<auto(TT)>) : bool {
    
    for (i in range(1, length(a))) {
        if (a[i] < a[i - 1]) {
            return false
        }
    }
    return true
}

def is_sorted(a : array<auto(TT)>; less : block<(a, b : TT const -&) : bool>) : bool {
    
    for (i in range(1, length(a))) {
        if (invoke(less, a[i], a[i - 1])) {
            return false
        }
    }
    return true
}

[expect_any_array(a)]
def is_sorted(a) : bool {
    
    unsafe {
        return is_sorted(temp_array(a))
    }
}



def rotate(var a : array<auto>; mid : int) {
    
    
    let l = length(a)
    if (l == 0 || mid == 0 || mid == l) {
        return
    }
    assert(mid > 0 && mid < l, "rotate mid out of range")
    
    let lm1 = l - 1
    let mm1 = mid - 1
    for (i in range(mid / 2)) {
        swap(a[i], a[mm1 - i])
    }
    let right_len = l - mid
    for (i in range(right_len / 2)) {
        swap(a[mid + i], a[lm1 - i])
    }
    for (i in range(l / 2)) {
        swap(a[i], a[lm1 - i])
    }
}

[expect_any_array(a)]
def rotate(var a; mid : int) {
    
    unsafe {
        rotate(temp_array(a), mid)
    }
}



def min_element(a : array<auto(TT)>) : int {
    
    if (length(a) == 0) {
        return -1
    }
    var best = 0
    for (i in range(1, length(a))) {
        if (a[i] < a[best]) {
            best = i
        }
    }
    return best
}

def min_element(a : array<auto(TT)>; less : block<(a, b : TT const -&) : bool>) : int {
    
    if (length(a) == 0) {
        return -1
    }
    var best = 0
    for (i in range(1, length(a))) {
        if (invoke(less, a[i], a[best])) {
            best = i
        }
    }
    return best
}

def max_element(a : array<auto(TT)>) : int {
    
    if (length(a) == 0) {
        return -1
    }
    var best = 0
    for (i in range(1, length(a))) {
        if (a[best] < a[i]) {
            best = i
        }
    }
    return best
}

def max_element(a : array<auto(TT)>; less : block<(a, b : TT const -&) : bool>) : int {
    
    if (length(a) == 0) {
        return -1
    }
    var best = 0
    for (i in range(1, length(a))) {
        if (invoke(less, a[best], a[i])) {
            best = i
        }
    }
    return best
}

[expect_any_array(a)]
def min_element(a) : int {
    
    unsafe {
        return min_element(temp_array(a))
    }
}

[expect_any_array(a)]
def max_element(a) : int {
    
    unsafe {
        return max_element(temp_array(a))
    }
}

def topological_sort(nodes : array<auto(Node)>) {
    
    
    
    
    static_if (!typeinfo has_field <before>(type<Node>) || !typeinfo is_table(nodes[0].before) || !typeinfo has_field <id>(type<Node>)) {
        concept_assert(false, "Node type {typeinfo stripped_typename(type<Node>)} should have fields 'before:table<id>' and 'id'")
    } else {
        var sorted : array<Node>
        let lnodes = length(nodes)
        if (lnodes != 0) {
            sorted |> reserve(lnodes)
            var unsorted : array<Node> := nodes
            while (length(unsorted) > 0) {
                var removed = 0
                var i = 0
                while (i < length(unsorted)) {
                    if (length(unsorted[i].before) == 0) {
                        var node <- unsorted[i]
                        unsorted |> erase(i)
                        for (other in unsorted) {
                            other.before |> erase(node.id)
                        }
                        sorted |> emplace(node)
                        removed ++
                    } else {
                        i ++
                    }
                }
                if (removed == 0) {
                    panic("cyclic dependency detected")
                }
            }
            delete unsorted
        }
        return <- sorted
    }
}

def intersection(a, b : table<auto(TT)>) : table<TT> {
    
    var result : table<TT>
    if (length(a) < length(b)) {
        for (k in keys(a)) {
            if (b |> key_exists(k)) {
                result |> insert(k)
            }
        }
    } else {
        for (k in keys(b)) {
            if (a |> key_exists(k)) {
                result |> insert(k)
            }
        }
    }
    return <- result
}

def union(a, b : table<auto(TT)>) : table<TT> {
    
    var result : table<TT>
    for (k in keys(a)) {
        result |> insert(k)
    }
    for (k in keys(b)) {
        result |> insert(k)
    }
    return <- result
}

def difference(a, b : table<auto(TT)>) : table<TT> {
    
    var result : table<TT>
    for (k in keys(a)) {
        if (!b |> key_exists(k)) {
            result |> insert(k)
        }
    }
    return <- result
}

def identical(a, b : table<auto(TT)>) : bool {
    
    if (length(a) != length(b)) {
        return false
    }
    for (k in keys(a)) {
        if (!b |> key_exists(k)) {
            return false
        }
    }
    return true
}

def symmetric_difference(a, b : table<auto(TT)>) : table<TT> {
    
    var result : table<TT>
    for (k in keys(a)) {
        if (!b |> key_exists(k)) {
            result |> insert(k)
        }
    }
    for (k in keys(b)) {
        if (!a |> key_exists(k)) {
            result |> insert(k)
        }
    }
    return <- result
}

def is_subset(a, b : table<auto(TT)>) : bool {
    
    if (length(a) > length(b)) {
        return false
    }
    for (k in keys(a)) {
        if (!b |> key_exists(k)) {
            return false
        }
    }
    return true
}
