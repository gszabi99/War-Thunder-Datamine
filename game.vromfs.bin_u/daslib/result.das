options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module result shared public

require daslib/templates
require daslib/templates_boost
require daslib/typemacro_boost
require daslib/option public




















[template_structure(T, E)]
struct template Result {
    _is_ok : bool = false
    @safe_when_uninitialized
    _value : T
    @safe_when_uninitialized
    _error : E
}







[template(etype)]
def ok(v : auto(TT); etype : auto(EE)) {
    typedef RT = $Result < TT - const; EE - const >
    var r = default<RT>
    r._is_ok = true
    static_if (typeinfo can_copy(r._value)) {
        r._value = v
    } else {
        r._value <- clone_to_move(v)
    }
    return <- r
}





[template(etype)]
def move_ok(var v : auto(TT); etype : auto(EE)) {
    typedef RT = $Result < TT - const; EE - const >
    return <- RT(_is_ok = true, _value <- v)
}







[template(ttype)]
def err(e : auto(EE); ttype : auto(TT)) {
    typedef RT = $Result < TT - const; EE - const >
    var r = default<RT>
    r._is_ok = false
    static_if (typeinfo can_copy(r._error)) {
        r._error = e
    } else {
        r._error <- clone_to_move(e)
    }
    return <- r
}





[template(ttype)]
def move_err(var e : auto(EE); ttype : auto(TT)) {
    typedef RT = $Result < TT - const; EE - const >
    return <- RT(_is_ok = false, _error <- e)
}


def is_ok(r : $Result < auto(TT); auto(EE) >) : bool {
    return r._is_ok
}


def is_err(r : $Result < auto(TT); auto(EE) >) : bool {
    return !r._is_ok
}


def map(r : $Result < auto(TT); auto(EE) >; f : block<(v : TT) : auto(UU)>) {
    var out = default<$Result<UU -const; EE -const> >
    if (r._is_ok) {
        out._is_ok = true
        static_if (typeinfo can_copy(out._value)) {
            out._value = invoke(f, r._value)
        } else {
            out._value <- invoke(f, r._value)
        }
    } else {
        static_if (typeinfo can_copy(out._error)) {
            out._error = r._error
        } else {
            out._error := r._error
        }
    }
    return <- out
}


def map_err(r : $Result < auto(TT); auto(EE) >; f : block<(e : EE) : auto(FF)>) {
    var out = default<$Result<TT -const; FF -const> >
    if (r._is_ok) {
        out._is_ok = true
        static_if (typeinfo can_copy(out._value)) {
            out._value = r._value
        } else {
            out._value := r._value
        }
    } else {
        static_if (typeinfo can_copy(out._error)) {
            out._error = invoke(f, r._error)
        } else {
            out._error <- invoke(f, r._error)
        }
    }
    return <- out
}


def and_then(r : $Result < auto(TT); auto(EE) >; f : block<(v : TT) : $Result<auto(UU); EE> >) {
    if (r._is_ok) {
        return <- invoke(f, r._value)
    }
    var out = default<$Result<UU -const; EE -const> >
    static_if (typeinfo can_copy(out._error)) {
        out._error = r._error
    } else {
        out._error := r._error
    }
    return <- out
}


def or_else(r : $Result < auto(TT); auto(EE) >; f : block<(e : EE) : $Result<TT; auto(FF)> >) {
    if (!r._is_ok) {
        return <- invoke(f, r._error)
    }
    var out = default<$Result<TT -const; FF -const> >
    out._is_ok = true
    static_if (typeinfo can_copy(out._value)) {
        out._value = r._value
    } else {
        out._value := r._value
    }
    return <- out
}


def unwrap(r : $Result < auto(TT); auto(EE) >) : TT {
    if (!r._is_ok) {
        panic("unwrap called on err")
    }
    static_if (typeinfo can_copy(r._value)) {
        return r._value
    } else {
        return <- clone_to_move(r._value)
    }
}






def move_unwrap(var r : $Result < auto(TT); auto(EE) >) : TT {
    if (!r._is_ok) {
        panic("move_unwrap called on err")
    }
    r._is_ok = false
    return <- r._value
}


def unwrap_or(r : $Result < auto(TT); auto(EE) >; d : TT) : TT {
    static_if (typeinfo can_copy(r._value)) {
        return r._is_ok ? r._value : d
    } else {
        return <- clone_to_move(r._is_ok ? r._value : d)
    }
}


def unwrap_or_else(r : $Result < auto(TT); auto(EE) >; f : block<(e : EE) : TT>) : TT {
    static_if (typeinfo can_copy(r._value)) {
        return r._is_ok ? r._value : invoke(f, r._error)
    } else {
        return <- clone_to_move(r._is_ok ? r._value : invoke(f, r._error))
    }
}


def unwrap_or_default(r : $Result < auto(TT); auto(EE) >) : TT {
    static_if (typeinfo can_copy(r._value)) {
        return r._is_ok ? r._value : default<TT>
    } else {
        return <- clone_to_move(r._is_ok ? r._value : default<TT>)
    }
}


def unwrap_err(r : $Result < auto(TT); auto(EE) >) : EE {
    if (r._is_ok) {
        panic("unwrap_err called on ok")
    }
    static_if (typeinfo can_copy(r._error)) {
        return r._error
    } else {
        return <- clone_to_move(r._error)
    }
}




def move_unwrap_err(var r : $Result < auto(TT); auto(EE) >) : EE {
    if (r._is_ok) {
        panic("move_unwrap_err called on ok")
    }
    r._is_ok = true
    return <- r._error
}



def expect_value(r : $Result < auto(TT); auto(EE) >; msg : string) : TT {
    if (!r._is_ok) {
        panic(msg)
    }
    static_if (typeinfo can_copy(r._value)) {
        return r._value
    } else {
        return <- clone_to_move(r._value)
    }
}


def expect_err(r : $Result < auto(TT); auto(EE) >; msg : string) : EE {
    if (r._is_ok) {
        panic(msg)
    }
    static_if (typeinfo can_copy(r._error)) {
        return r._error
    } else {
        return <- clone_to_move(r._error)
    }
}


def if_ok(r : $Result < auto(TT); auto(EE) >; f : block<(v : TT) : void>) : void {
    if (r._is_ok) {
        invoke(f, r._value)
    }
}


def if_err(r : $Result < auto(TT); auto(EE) >; f : block<(e : EE) : void>) : void {
    if (!r._is_ok) {
        invoke(f, r._error)
    }
}


def to_option(r : $Result < auto(TT); auto(EE) >) {
    var o = default<$Option<TT -const> >
    if (r._is_ok) {
        o._has_value = true
        static_if (typeinfo can_copy(o._value)) {
            o._value = r._value
        } else {
            o._value := r._value
        }
    }
    return <- o
}


def err_to_option(r : $Result < auto(TT); auto(EE) >) {
    var o = default<$Option<EE -const> >
    if (!r._is_ok) {
        o._has_value = true
        static_if (typeinfo can_copy(o._value)) {
            o._value = r._error
        } else {
            o._value := r._error
        }
    }
    return <- o
}


def operator ??(r : $Result < auto(TT); auto(EE) >; d : TT) : TT {
    static_if (typeinfo can_copy(r._value)) {
        return r._is_ok ? r._value : d
    } else {
        return <- clone_to_move(r._is_ok ? r._value : d)
    }
}


def operator ==(a, b : $Result < auto(TT); auto(EE) > implicit) : bool {
    if (a._is_ok != b._is_ok) {
        return false
    }
    return a._is_ok ? a._value == b._value : a._error == b._error
}


def operator ==(r : $Result < auto(TT); auto(EE) >; v : TT) : bool {
    return r._is_ok && r._value == v
}

def operator ==(v : auto(TT); r : $Result < TT; auto(EE) >) : bool {
    return r._is_ok && r._value == v
}

def operator !=(r : $Result < auto(TT); auto(EE) >; v : TT) : bool {
    return !(r == v)
}

def operator !=(v : auto(TT); r : $Result < TT; auto(EE) >) : bool {
    return !(r == v)
}
