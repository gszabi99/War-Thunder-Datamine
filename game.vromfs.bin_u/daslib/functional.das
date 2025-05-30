options gen2
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options indenting = 4
options strict_smart_pointers = true

module functional shared public

def private filter_any(var src : iterator<auto(TT)>; var blk) {
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- src, <- blk) () <| $() {
            for (w in src) {
                if (invoke(blk, w)) {
                    yield w
                }
            }
            return false
        }
    } else {
        return <- generator<TT&> capture(<- src, <- blk) () <| $() {
            for (w in src) {
                if (invoke(blk, w)) {
                    yield w
                }
            }
            return false
        }
    }
}

def filter(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : bool>) {
    
    return <- filter_any(src, blk)
}


def filter(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : bool>) {
    return <- filter_any(src, blk)
}

def private map_any(var src : iterator<auto(TT)>; var blk) {
    static_if (typeinfo can_copy(type<QQ>)) {
        return <- generator<QQ -&> capture(<- src, <- blk) () <| $() {
            for (w in src) {
                static_if (typeinfo is_ref_type(invoke(blk, w))) {
                    yield copy_to_local(invoke(blk, w))
                } else {
                    yield invoke(blk, w)
                }
            }
            return false
        }
    } static_elif (typeinfo can_move(type<QQ>)) {
        return <- generator<QQ -&> capture(<- src, <- blk) () <| $() {
            for (w in src) {
                static_if (typeinfo is_ref_type(invoke(blk, w))) {
                    yield <- move_to_local(invoke(blk, w))
                } else {
                    yield <- invoke(blk, w)
                }
            }
            return false
        }
    } else {
        concept_assert(false, "can't copy or move return type")
        var dummy : iterator<QQ>
        return <- dummy
    }
}



def map(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : auto(QQ)>) {
    
    return <- map_any(src, blk)
}


def map(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : auto(QQ)>) {
    return <- map_any(src, blk)
}


def private reduce_any(var it : iterator<auto(TT)>; functor) {
    var left : TT -&
    var first = true
    for (right in it) {
        if (first) {
            first = false
            left = right
        } else {
            static_if (typeinfo is_ref_type(type<TT -&>)) {
                left <- copy_to_local(invoke(functor, left, right))
            } else {
                left = invoke(functor, left, right)
            }
        }
    }
    if (first) {
        panic("can't reduce empty sequence")
    }
    return left
}


def reduce(var it : iterator<auto(TT)>; blk : lambda<(left, right : TT -&) : TT const -&>) {
    
    
    return reduce_any(it, blk)
}


def reduce(var it : iterator<auto(TT)>; blk : function<(left, right : TT -&) : TT const -&>) {
    return reduce_any(it, blk)
}


def reduce(var it : iterator<auto(TT)>; blk : block<(left, right : TT -&) : TT const -&>) {
    return reduce_any(it, blk)
}


def sum(var it : iterator<auto(TT)>) {
    
    
    var temp : TT -&
    for (x in it) {
        temp += x
    }
    return temp
}


def any(it) {
    
    static_if (!typeinfo is_iterable(it)) {
        concept_assert(false, "can't ANY non-iterable type")
        return false
    } else {
        for (x in it) {
            if (x) {
                return true
            }
        }
        return false
    }
}

def any(var it : iterator<auto(TT)>) {
    
    for (x in it) {
        if (x) {
            return true
        }
    }
    return false
}


def all(it) {
    
    static_if (!typeinfo is_iterable(it)) {
        concept_assert(false, "can't ALL non-iterable type")
        return false
    } else {
        for (x in it) {
            if (!x) {
                return false
            }
        }
        return true
    }
}

def all(var it : iterator<auto(TT)>) {
    
    for (x in it) {
        if (!x) {
            return false
        }
    }
    return true
}

def cycle(var src : iterator<auto(TT)>) {
    
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- src) () <| $() {
            var arr : array<TT -&>
            for (x in src) {
                yield x
                push(arr, x)
            }
            while (true) {
                for (x in arr) {
                    yield x
                }
            }
            return false
        } finally {
            __builtin_array_clear_lock(arr)
        }
    } else {
        return <- generator<TT&> capture(<- src) () <| $() {
            var arr : array<TT -&>
            for (x in src) {
                yield x
                push_clone(arr, x)
            }
            while (true) {
                for (x in arr) {
                    yield x
                }
            }
            return false
        } finally {
            __builtin_array_clear_lock(arr)
        }
    }
}

def islice(var src : iterator<auto(TT)>; start, stop : int) {
    
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- src) () <| $() {
            for (x, i in src, range(stop)) {
                if (i >= start) {
                    yield x
                }
            }
            return false
        }
    } else {
        return <- generator<TT&> capture(<- src) () <| $() {
            for (x, i in src, range(stop)) {
                if (i >= start) {
                    yield x
                }
            }
            return false
        }
    }
}


def repeat_ref(value : auto(TT); var total : int) {
    
    return <- generator<TT const&>() <| $() {
        while (total > 0) {
            yield value
            total --
        }
        return false
    }
}


def repeat(value : auto(TT); var count : int = 0) {
    
    return <- generator<TT const -&>() <| $() {
        if (count == 0) {
            while (true) {
                yield value
            }
        }
        for (x in range(count)) {
            yield value
        }
        return false
    }
}

def is_equal(a, b) {
    
    return a == b
}

def is_not_equal(a, b) {
    
    return a != b
}

def not(x) {
    
    return !x
}

def echo(var x; extra : string = "\n") {
    
    print("{x}{extra}")
    return <- x
}

def private flatten_one(var src : iterator<iterator<auto(TT)>>) {
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- src) () <| $() {
            for (i in src) {
                for (j in i) {
                    yield j
                }
            }
            return false
        }
    } else {
        return <- generator<TT&> capture(<- src) () <| $() {
            for (i in src) {
                for (j in i) {
                    yield j
                }
            }
            return false
        }
    }
}

def flatten(var it : iterator<auto(TT)>) {
    
    unsafe {
        static_if (typeinfo is_iterator(type<TT>)) {
            return <- flatten_one([iterator for(i in it); flatten(i)])
        } else {
            return <- [iterator for(i in it); i]
        }
    }
}

def sorted(var arr : array<auto>) {
    
    arr |> sort
    return <- arr
}

def sorted(var it : iterator<auto(TT)>) {
    
    var arr <- to_array(it)
    sort(arr)
    return <- generator<TT> capture(<- arr) () <| $() {
        for (x in arr) {
            yield x
        }
        return false
    }
}
