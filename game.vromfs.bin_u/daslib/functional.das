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
            var arr : array<TT -const -&>
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
        }
    } else {
        return <- generator<TT&> capture(<- src) () <| $() {
            var arr : array<TT -const -&>
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


def repeat(value : auto(TT); var count : int = -1) {
    
    return <- generator<TT const -&>() <| $() {
        if (count < 0) {
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

def echo(x; extra : string = "\n") {
    
    
    print("{x}{extra}")
    return x
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





def private reduce_or_default_any(var it : iterator<auto(TT)>; functor; default_value : TT -&) {
    
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
    return left if (!first)
    return default_value
}

def reduce_or_default(var it : iterator<auto(TT)>; blk : lambda<(left, right : TT -&) : TT const -&>; default_value : TT -&) {
    
    return reduce_or_default_any(it, blk, default_value)
}

def reduce_or_default(var it : iterator<auto(TT)>; blk : function<(left, right : TT -&) : TT const -&>; default_value : TT -&) {
    
    return reduce_or_default_any(it, blk, default_value)
}

def reduce_or_default(var it : iterator<auto(TT)>; default_value : TT -&; blk : block<(left, right : TT -&) : TT const -&>) {
    
    return reduce_or_default_any(it, blk, default_value)
}





def private fold_any(var it : iterator<auto(TT)>; seed : auto(AGG); functor) {
    
    var acc : AGG -& = seed
    for (x in it) {
        static_if (typeinfo is_ref_type(type<AGG -&>)) {
            acc <- copy_to_local(invoke(functor, acc, x))
        } else {
            acc = invoke(functor, acc, x)
        }
    }
    return acc
}

def fold(var it : iterator<auto(TT)>; seed : auto(AGG); blk : lambda<(acc : AGG -&, x : TT -&) : AGG const -&>) {
    
    return fold_any(it, seed, blk)
}

def fold(var it : iterator<auto(TT)>; seed : auto(AGG); blk : function<(acc : AGG -&, x : TT -&) : AGG const -&>) {
    
    return fold_any(it, seed, blk)
}

def fold(var it : iterator<auto(TT)>; seed : auto(AGG); blk : block<(acc : AGG -&, x : TT -&) : AGG const -&>) {
    
    return fold_any(it, seed, blk)
}





def private scan_any(var src : iterator<auto(TT)>; seed : auto(AGG); var functor) {
    
    return <- generator<AGG -&> capture(<- src, <- functor) () <| $() {
        var acc : AGG -& = seed
        yield acc
        for (x in src) {
            static_if (typeinfo is_ref_type(type<AGG -&>)) {
                acc <- copy_to_local(invoke(functor, acc, x))
            } else {
                acc = invoke(functor, acc, x)
            }
            yield acc
        }
        return false
    }
}

def scan(var src : iterator<auto(TT)>; seed : auto(AGG); blk : lambda<(acc : AGG -&, x : TT -&) : AGG const -&>) {
    
    return <- scan_any(src, seed, blk)
}

def scan(var src : iterator<auto(TT)>; seed : auto(AGG); blk : function<(acc : AGG -&, x : TT -&) : AGG const -&>) {
    
    return <- scan_any(src, seed, blk)
}





def enumerate(var src : iterator<auto(TT)>) {
    
    return <- generator<tuple<int, TT -&>> capture(<- src) () <| $() {
        var idx = 0
        for (x in src) {
            yield (idx, x)
            idx ++
        }
        return false
    }
}





def private for_each_any(var src : iterator<auto(TT)>; blk) {
    
    for (x in src) {
        invoke(blk, x)
    }
}

def for_each(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : void>) {
    
    for_each_any(src, blk)
}

def for_each(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : void>) {
    
    for_each_any(src, blk)
}

def for_each(var src : iterator<auto(TT)>; blk : block<(what : TT -&) : void>) {
    
    for_each_any(src, blk)
}





def private find_any(var src : iterator<auto(TT)>; predicate; default_value : TT -&) {
    
    for (x in src) {
        if (invoke(predicate, x)) {
            return x
        }
    }
    return default_value
}

def find(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : bool>; default_value : TT -&) {
    
    return find_any(src, blk, default_value)
}

def find(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : bool>; default_value : TT -&) {
    
    return find_any(src, blk, default_value)
}

def find(var src : iterator<auto(TT)>; default_value : TT -&; blk : block<(what : TT -&) : bool>) {
    
    return find_any(src, blk, default_value)
}





def private find_index_any(var src : iterator<auto(TT)>; predicate) : int {
    
    var idx = 0
    for (x in src) {
        if (invoke(predicate, x)) {
            return idx
        }
        idx ++
    }
    return -1
}

def find_index(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : bool>) : int {
    
    return find_index_any(src, blk)
}

def find_index(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : bool>) : int {
    
    return find_index_any(src, blk)
}

def find_index(var src : iterator<auto(TT)>; blk : block<(what : TT -&) : bool>) : int {
    
    return find_index_any(src, blk)
}





def private partition_any(var src : iterator<auto(TT)>; predicate) : tuple<array<TT -const -&>, array<TT -const -&>> {
    
    var yes : array<TT -const -&>
    var no  : array<TT -const -&>
    for (x in src) {
        if (invoke(predicate, x)) {
            yes |> push(x)
        } else {
            no |> push(x)
        }
    }
    return (yes, no)
}

def partition(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : bool>) : tuple<array<TT -const -&>, array<TT -const -&>> {
    
    return partition_any(src, blk)
}

def partition(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : bool>) : tuple<array<TT -const -&>, array<TT -const -&>> {
    
    return partition_any(src, blk)
}

def partition(var src : iterator<auto(TT)>; blk : block<(what : TT -&) : bool>) : tuple<array<TT -const -&>, array<TT -const -&>> {
    
    return partition_any(src, blk)
}





def private tap_any(var src : iterator<auto(TT)>; var blk) {
    
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- src, <- blk) () <| $() {
            for (x in src) {
                invoke(blk, x)
                yield x
            }
            return false
        }
    } else {
        return <- generator<TT&> capture(<- src, <- blk) () <| $() {
            for (x in src) {
                invoke(blk, x)
                yield x
            }
            return false
        }
    }
}

def tap(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : void>) {
    
    return <- tap_any(src, blk)
}

def tap(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : void>) {
    
    return <- tap_any(src, blk)
}





def iterate(seed : auto(TT); var blk : lambda<(what : TT -&) : TT const -&>) {
    
    
    return <- generator<TT -&> capture(<- blk) () <| $() {
        var current : TT -& = seed
        while (true) {
            yield current
            static_if (typeinfo is_ref_type(type<TT -&>)) {
                current <- copy_to_local(invoke(blk, current))
            } else {
                current = invoke(blk, current)
            }
        }
        return false
    }
}

def iterate(seed : auto(TT); var blk : function<(what : TT -&) : TT const -&>) {
    
    return <- generator<TT -&> capture(<- blk) () <| $() {
        var current : TT -& = seed
        while (true) {
            yield current
            static_if (typeinfo is_ref_type(type<TT -&>)) {
                current <- copy_to_local(invoke(blk, current))
            } else {
                current = invoke(blk, current)
            }
        }
        return false
    }
}





def chain(var a : iterator<auto(TT)>; var b : iterator<auto(TT)>) {
    
    static_if (!typeinfo is_ref_type(type<TT>)) {
        return <- generator<TT -&> capture(<- a, <- b) () <| $() {
            for (x in a) {
                yield x
            }
            for (x in b) {
                yield x
            }
            return false
        }
    } else {
        return <- generator<TT&> capture(<- a, <- b) () <| $() {
            for (x in a) {
                yield x
            }
            for (x in b) {
                yield x
            }
            return false
        }
    }
}





def pairwise(var src : iterator<auto(TT)>) {
    
    return <- generator<tuple<TT -&, TT -&>> capture(<- src) () <| $() {
        var prev : TT -&
        var first = true
        for (x in src) {
            if (first) {
                first = false
                prev = x
            } else {
                yield (prev, x)
                prev = x
            }
        }
        return false
    }
}





def private flat_map_any(var src : iterator<auto(TT)>; var blk) {
    
    return <- generator<auto(QQ) -&> capture(<- src, <- blk) () <| $() {
        for (x in src) {
            for (y in invoke(blk, x)) {
                yield y
            }
        }
        return false
    }
}

def flat_map(var src : iterator<auto(TT)>; blk : lambda<(what : TT -&) : auto(QQ)>) {
    
    return <- flat_map_any(src, blk)
}

def flat_map(var src : iterator<auto(TT)>; blk : function<(what : TT -&) : auto(QQ)>) {
    
    return <- flat_map_any(src, blk)
}
