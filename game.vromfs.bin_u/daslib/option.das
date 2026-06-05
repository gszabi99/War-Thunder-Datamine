options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module option shared public

require daslib/templates
require daslib/templates_boost
require daslib/typemacro_boost

















[template_structure(T), safe_when_uninitialized]
struct template Option {
    _has_value : bool = false
    @safe_when_uninitialized
    _value : T
}




def some(v : auto(TT)) {
    typedef OT = $Option < TT - const >
    var o = default<OT>
    o._has_value = true
    static_if (typeinfo can_copy(o._value)) {
        o._value = v
    } else {
        o._value <- clone_to_move(v)
    }
    return <- o
}







def move_some(var v : auto(TT)) {
    typedef OT = $Option < TT - const >
    return <- OT(_has_value = true, _value <- v)
}




[template(t)]
def none(t : auto(TT)) {
    return default<$Option<TT -const> >
}


def is_some(o : $Option < auto(TT) >) : bool {
    return o._has_value
}


def is_none(o : $Option < auto(TT) >) : bool {
    return !o._has_value
}


def map(o : $Option < auto(TT) >; f : block<(v : TT) : auto(UU)>) {
    var r = default<$Option<UU -const> >
    if (o._has_value) {
        r._has_value = true
        static_if (typeinfo can_copy(r._value)) {
            r._value = invoke(f, o._value)
        } else {
            r._value <- invoke(f, o._value)
        }
    }
    return <- r
}


def and_then(o : $Option < auto(TT) >; f : block<(v : TT) : $Option<auto(UU)> >) {
    if (o._has_value) {
        return invoke(f, o._value)
    }
    return default<$Option<UU -const> >
}


def filter(o : $Option < auto(TT) >; p : block<(v : TT) : bool>) {
    if (o._has_value && invoke(p, o._value)) {
        static_if (typeinfo can_copy(o._value)) {
            return o
        } else {
            return <- clone_to_move(o)
        }
    }
    return default<$Option<TT -const> >
}


def or_else(o : $Option < auto(TT) >; f : block<() : $Option<TT> >) {
    if (o._has_value) {
        static_if (typeinfo can_copy(o._value)) {
            return o
        } else {
            return <- clone_to_move(o)
        }
    }
    return invoke(f)
}


def or_value(o : $Option < auto(TT) >; v : TT) {
    if (o._has_value) {
        static_if (typeinfo can_copy(o._value)) {
            return o
        } else {
            return <- clone_to_move(o)
        }
    }
    return some(v)
}


def unwrap(o : $Option < auto(TT) >) : TT {
    if (!o._has_value) {
        panic("unwrap called on none")
    }
    static_if (typeinfo can_copy(o._value)) {
        return o._value
    } else {
        return <- clone_to_move(o._value)
    }
}






def move_unwrap(var o : $Option < auto(TT) >) : TT {
    if (!o._has_value) {
        panic("move_unwrap called on none")
    }
    o._has_value = false
    return <- o._value
}


def unwrap_or(o : $Option < auto(TT) >; d : TT) : TT {
    static_if (typeinfo can_copy(o._value)) {
        return o._has_value ? o._value : d
    } else {
        return <- clone_to_move(o._has_value ? o._value : d)
    }
}


def unwrap_or_else(o : $Option < auto(TT) >; f : block<() : TT>) : TT {
    static_if (typeinfo can_copy(o._value)) {
        return o._has_value ? o._value : invoke(f)
    } else {
        return <- clone_to_move(o._has_value ? o._value : invoke(f))
    }
}


def unwrap_or_default(o : $Option < auto(TT) >) : TT {
    static_if (typeinfo can_copy(o._value)) {
        return o._has_value ? o._value : default<TT>
    } else {
        return <- clone_to_move(o._has_value ? o._value : default<TT>)
    }
}



def expect_value(o : $Option < auto(TT) >; msg : string) : TT {
    if (!o._has_value) {
        panic(msg)
    }
    static_if (typeinfo can_copy(o._value)) {
        return o._value
    } else {
        return <- clone_to_move(o._value)
    }
}


def if_some(o : $Option < auto(TT) >; f : block<(v : TT) : void>) : void {
    if (o._has_value) {
        invoke(f, o._value)
    }
}


def if_none(o : $Option < auto(TT) >; f : block<() : void>) : void {
    if (!o._has_value) {
        invoke(f)
    }
}


def zip(a : $Option < auto(TT) >; b : $Option < auto(UU) >) {
    var r = default<$Option<tuple<TT -const; UU -const> > >
    if (a._has_value && b._has_value) {
        r._has_value = true
        static_if (typeinfo can_copy(a._value)) {
            r._value._0 = a._value
        } else {
            r._value._0 := a._value
        }
        static_if (typeinfo can_copy(b._value)) {
            r._value._1 = b._value
        } else {
            r._value._1 := b._value
        }
    }
    return <- r
}


def operator ??(o : $Option < auto(TT) >; d : TT) : TT {
    static_if (typeinfo can_copy(o._value)) {
        return o._has_value ? o._value : d
    } else {
        return <- clone_to_move(o._has_value ? o._value : d)
    }
}


def operator ==(a, b : $Option < auto(TT) > implicit) : bool {
    if (a._has_value != b._has_value) {
        return false
    }
    return !a._has_value || a._value == b._value
}


def operator ==(o : $Option < auto(TT) >; v : TT) : bool {
    return o._has_value && o._value == v
}

def operator ==(v : auto(TT); o : $Option < TT >) : bool {
    return o._has_value && o._value == v
}

def operator !=(o : $Option < auto(TT) >; v : TT) : bool {
    return !(o == v)
}

def operator !=(v : auto(TT); o : $Option < TT >) : bool {
    return !(o == v)
}
