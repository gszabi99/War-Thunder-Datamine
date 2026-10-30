options gen2
options no_global_variables = false
options indenting = 4
options strict_smart_pointers = true

module json shared public








require daslib/strings_boost

variant JsValue {
    
    _object  : table<string; JsonValue?>    
    _array   : array<JsonValue?>           
    _string  : string                      
    _number  : double                      
    _longint : int64                       
    _bool    : bool                        
    _null    : void?                       
}

struct JsonValue {
    
    value : JsValue                         
}

variant Token {
    
    _string  : string                       
    _number  : double                       
    _longint : int64                        
    _bool    : bool                         
    _null    : void?                        
    _symbol  : int                          
    _error   : string                       
}

struct TokenAt {
    
    value : Token                           
    line, row : int                         
}

let private {
    Token_string = typeinfo variant_index<_string>(type<Token>) 
    Token_symbol = typeinfo variant_index<_symbol>(type<Token>)
    HIGH_SURROGATE_FIRST = 0xD800u
    HIGH_SURROGATE_LAST = 0xDBFFu
    LOW_SURROGATE_FIRST = 0xDC00u
    LOW_SURROGATE_LAST = 0xDFFFu
    SUPPLEMENTARY_FIRST = 0x10000u
    REPLACEMENT_CODEPOINT = 0xFFFDu
    INT64_MAX_DIGITS = 19
}

def private is_high_surrogate(codepoint : uint) : bool => codepoint >= HIGH_SURROGATE_FIRST && codepoint <= HIGH_SURROGATE_LAST

def private is_low_surrogate(codepoint : uint) : bool => codepoint >= LOW_SURROGATE_FIRST && codepoint <= LOW_SURROGATE_LAST

def private push_utf8_continuation(var str : array<uint8>; codepoint : uint; shift : uint) {
    
    push(str, uint8(0x80u | ((codepoint >> shift) & 0x3Fu)))
}

def private push_utf8(var str : array<uint8>; codepoint : uint) {
    
    if (codepoint <= 0x7Fu) {
        push(str, uint8(codepoint))
    } elif (codepoint <= 0x7FFu) {
        push(str, uint8(0xC0u | (codepoint >> 6u)))
        push_utf8_continuation(str, codepoint, 0u)
    } elif (codepoint <= 0xFFFFu) {
        push(str, uint8(0xE0u | (codepoint >> 12u)))
        push_utf8_continuation(str, codepoint, 6u)
        push_utf8_continuation(str, codepoint, 0u)
    } else {
        push(str, uint8(0xF0u | (codepoint >> 18u)))
        push_utf8_continuation(str, codepoint, 12u)
        push_utf8_continuation(str, codepoint, 6u)
        push_utf8_continuation(str, codepoint, 0u)
    }
}

def private flush_unpaired_surrogate(var str : array<uint8>; var pending : uint&) {
    
    if (!is_high_surrogate(pending)) return
    pending = 0u
    push_utf8(str, REPLACEMENT_CODEPOINT)
}

def private hex4_codepoint(hex_str : array<uint8>) : uint {
    
    var codepoint = 0u
    for (hb in hex_str) {
        codepoint = codepoint << 4u
        let c = int(hb)
        if (is_number(c)) {
            codepoint += uint(c - '0')
        } elif (c >= 'a' && c <= 'f') {
            codepoint += uint(c - 'a' + 10)
        } elif (c >= 'A' && c <= 'F') {
            codepoint += uint(c - 'A' + 10)
        }
    }
    return codepoint
}

def private fits_int64(num : string) : bool {
    
    var fits = true
    peek_data(num) $(digits) {
        let n = length(digits)
        var i = 0
        let negative = n > 0 && digits[0] == '-'u8
        if (negative) {
            i ++
        }
        while (i < n && digits[i] == '0'u8) {
            i ++
        }
        if (n - i > INT64_MAX_DIGITS) {
            fits = false
        } else {
            var value = 0ul
            while (i < n) {
                value = value * 10ul + uint64(int(digits[i]) - '0')
                i ++
            }
            fits = value <= (negative ? 9223372036854775808ul : 9223372036854775807ul)
        }
    }
    return fits
}

def JVNull {
    
    return new JsonValue(value <- JsValue(_null = null))
}

var private g_json_null_sentinel : JsonValue?

def json_null_sentinel : JsonValue ? {
    
    if (g_json_null_sentinel == null) {
        g_json_null_sentinel = JVNull()
    }
    return g_json_null_sentinel
}

def JV(v : string) {
    
    return new JsonValue(value <- JsValue(_string = v))
}

def JV(v : double) {
    
    return new JsonValue(value <- JsValue(_number = v))
}

def JV(v : bool) {
    
    return new JsonValue(value <- JsValue(_bool = v))
}

def JV(var v : table<string; JsonValue?>) {
    
    return new JsonValue(value <- JsValue(_object <- v))
}

def JV(var v : array<JsonValue?>) {
    
    return new JsonValue(value <- JsValue(_array <- v))
}

def JV(v : float) {
    
    return new JsonValue(value <- JsValue(_number = double(v)))
}

def JV(v : int) {
    
    return new JsonValue(value <- JsValue(_longint = int64(v)))
}

def JV(v : bitfield) {
    
    return new JsonValue(value <- JsValue(_longint = int64(v)))
}

def JV(v : bitfield : uint8 < >) {
    
    return new JsonValue(value <- JsValue(_longint = int64(v)))
}

def JV(v : bitfield : uint16 < >) {
    
    return new JsonValue(value <- JsValue(_longint = int64(v)))
}

def JV(v : bitfield : uint64 < >) {
    
    return new JsonValue(value <- JsValue(_longint = int64(v)))
}

def JV(val : int8) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def JV(val : uint8) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def JV(val : int16) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def JV(val : uint16) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def JV(val : uint) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def JV(val : int64) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = val))
}

def JV(val : uint64) : JsonValue? {
    
    return new JsonValue(value <- JsValue(_longint = int64(val)))
}

def private lexer(text : string) {
    
    let stext = clone_string(text)
    return <- _lexer(stext)
}

def private lexer(text : array<uint8>) {
    
    let stext = string(text)
    return <- _lexer(stext)
}

def private next(var text : iterator<int>; var character, line, row : int&) : bool {
    
    if (next(text, character)) {
        if (is_new_line(character)) {
            line++
            row = 0
        } else {
            row++
        }
        return true
    }
    return false
}

def private is_json_white_space(ch : int) : bool => ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'

def private _lexer(var stext : string implicit) {  
    
    return <- generator<TokenAt> {
        var tin : iterator<int>
        tin <- unsafe(each(stext))
        var ahead : int = ' '
        var str : array<uint8>
        var pending_high = 0u
        var line : int = 1
        var row : int = 0
        while (!empty(tin)) {
            while (is_json_white_space(ahead) && next(tin, ahead, line, row)) {
                pass
            }
            if (empty(tin)) return false
            if (ahead == '[' || ahead == ']' || ahead == '{' || ahead == '}' || ahead == ':' || ahead == ',') {
                yield TokenAt(value = Token(_symbol = ahead), line = line, row = row)
                next(tin, ahead)
            } elif (ahead == '"') {
                while (next(tin, ahead, line, row) && ahead != '"') {
                    if (ahead == '\\') {
                        if (next(tin, ahead, line, row)) {
                            if (ahead == 'u') {
                                var hex_str : array<uint8>
                                var valid_hex = true
                                for (_ in range(4)) {
                                    if (!next(tin, ahead, line, row)) {
                                        yield TokenAt(value = Token(_error = "incomplete \\u escape"), line = line, row = row)
                                        return false
                                    }
                                    if (!is_hex(ahead)) {
                                        valid_hex = false
                                        break
                                    }
                                    push(hex_str, uint8(ahead))
                                }
                                if (valid_hex && length(hex_str) == 4) {
                                    let codepoint = hex4_codepoint(hex_str)
                                    if (is_high_surrogate(codepoint)) {
                                        flush_unpaired_surrogate(str, pending_high)
                                        pending_high = codepoint
                                    } elif (is_low_surrogate(codepoint) && is_high_surrogate(pending_high)) {
                                        push_utf8(str, SUPPLEMENTARY_FIRST + ((pending_high - HIGH_SURROGATE_FIRST) << 10u) + (codepoint - LOW_SURROGATE_FIRST))
                                        pending_high = 0u
                                    } elif (is_low_surrogate(codepoint)) {
                                        push_utf8(str, REPLACEMENT_CODEPOINT)
                                    } else {
                                        flush_unpaired_surrogate(str, pending_high)
                                        push_utf8(str, codepoint)
                                    }
                                } else {
                                    flush_unpaired_surrogate(str, pending_high)
                                    push(str, uint8('\\')) 
                                    push(str, uint8('u'))
                                    str |> push_from(hex_str) 
                                    if (!valid_hex) {
                                        push(str, uint8(ahead))
                                    }
                                }
                                continue
                            }
                            flush_unpaired_surrogate(str, pending_high)
                            if (ahead == 'b') {
                                ahead = '\b'
                            } elif (ahead == 'f') {
                                ahead = '\f'
                            } elif (ahead == 'n') {
                                ahead = '\n'
                            } elif (ahead == 'r') {
                                ahead = '\r'
                            } elif (ahead == 't') {
                                ahead = '\t'
                            } elif (ahead == '/') {
                                ahead = '/'
                            }
                            push(str, uint8(ahead))
                        } else {
                            yield TokenAt(value = Token(_error = "string escape sequence exceeds text"), line = line, row = row)
                            return false
                        }
                    } else {
                        flush_unpaired_surrogate(str, pending_high)
                        push(str, uint8(ahead))
                    }
                }
                if (empty(tin)) {
                    yield TokenAt(value = Token(_error = "string exceeds text"), line = line, row = row)
                    return false
                }
                flush_unpaired_surrogate(str, pending_high)
                yield TokenAt(value = Token(_string = string(str)), line = line, row = row)
                clear(str)
                next(tin, ahead)
            } elif (ahead == '-' || is_number(ahead)) {
                push(str, uint8(ahead))
                var anyNumbers = is_number(ahead)
                while (next(tin, ahead, line, row) && is_number(ahead)) {
                    push(str, uint8(ahead))
                    anyNumbers = true
                }
                var is_integer = true
                if (!empty(tin) && ahead == '.') {
                    is_integer = false
                    push(str, uint8(ahead))
                    while (next(tin, ahead, line, row) && is_number(ahead)) {
                        push(str, uint8(ahead))
                        anyNumbers = true
                    }
                }
                if (!empty(tin) && (ahead == 'e' || ahead == 'E')) {
                    is_integer = false
                    push(str, uint8(ahead))
                    next(tin, ahead, line, row)
                    if (ahead == '+' || ahead == '-' || is_number(ahead)) {
                        push(str, uint8(ahead))
                    }
                    while (next(tin, ahead, line, row) && is_number(ahead)) {
                        push(str, uint8(ahead))
                        anyNumbers = true
                    }
                }
                var num = string(str)
                if (!anyNumbers) {
                    yield TokenAt(value = Token(_error = "number {num} is invalid"), line = line, row = row)
                    return false
                }
                if (is_integer && fits_int64(num)) {
                    yield TokenAt(value = Token(_longint = int64(num)), line = line, row = row)
                } else {
                    var conversion : ConversionResult
                    var consumed = 0
                    let wide = double(num, conversion, consumed)
                    if (conversion != ConversionResult.ok || consumed != length(num)) {
                        let verdict = conversion == ConversionResult.out_of_range ? "out of range" : "invalid"
                        yield TokenAt(value = Token(_error = "number {num} is {verdict}"), line = line, row = row)
                        return false
                    }
                    yield TokenAt(value = Token(_number = wide), line = line, row = row)
                }
                clear(str)
                unsafe(delete_string(num))
            } elif (is_alpha(ahead)) {
                push(str, uint8(ahead))
                while (next(tin, ahead, line, row) && is_alpha(ahead)) {
                    push(str, uint8(ahead))
                }
                var name = string(str)
                if (name == "true") {
                    yield TokenAt(value = Token(_bool = true), line = line, row = row)
                } elif (name == "false") {
                    yield TokenAt(value = Token(_bool = false), line = line, row = row)
                } elif (name == "null") {
                    yield TokenAt(value = Token(_null = null), line = line, row = row)
                } else {
                    yield TokenAt(value = Token(_error = "invalid name {name}"), line = line, row = row)
                    return false
                }
                unsafe(delete_string(name))
                clear(str)
            } else {
                yield TokenAt(value = Token(_error = "invalid character `{to_char(ahead)}` aka ASCII {ahead}"), line = line, row = row)
                return false
            }
        }
        return false
    } finally {
        unsafe {
            delete_string(stext)
        }
    }
}

def private expect_token(var itv : iterator<TokenAt>; var ahead : TokenAt; vindex : int; var error : string&) : bool {
    
    if (!next(itv, ahead)) {
        error = "unexected eos"
        return false
    } elif (variant_index(ahead.value) != vindex) {
        error = "unexpected {ahead.value}, expecting variant {vindex} at {ahead.line}:{ahead.row}"
        return false
    } else {
        return true
    }
}

def private expect_symbol(var itv : iterator<TokenAt>; var ahead : TokenAt; sym : int; var error : string&) : bool {
    
    if (!next(itv, ahead)) {
        error = "unexected eos"
        return false
    } elif (!ahead.value is _symbol) {
        error = "unexpected {ahead.value}, expecting symbol at {ahead.line}:{ahead.row}"
        return false
    } elif (!(ahead.value as _symbol == sym)) {
        error = "unexpected {ahead.value}, expecting symbol `{to_char(sym)}` aka ASCII {sym} at {ahead.line}:{ahead.row}"
        return false
    } else {
        return true
    }
}

def private parse_value(var itv : iterator<TokenAt>; var error : string&) : JsonValue? {
    
    var ahead : TokenAt
    if (!next(itv, ahead)) return null
    return parse_value(itv, ahead, error)
}

def private parse_value(var itv : iterator<TokenAt>; var ahead : TokenAt; var error : string&) : JsonValue? {  
    
    if (ahead.value is _symbol) {
        let sym = ahead.value as _symbol
        if (sym == ']') {
            error = "unexpected ] at {ahead.line}:{ahead.row}";
            return null;
        }
        if (sym == '[') {
            var arr : array<JsonValue?>
            var element : TokenAt
            while (next(itv, element)) {
                if (empty(arr) && (element.value is _symbol) && (element.value as _symbol) == ']') return JV(arr)
                var value = parse_value(itv, element, error)
                if (value == null) return null
                push(arr, value)
                if (!expect_token(itv, ahead, Token_symbol, error)) return null
                let sepsym = ahead.value as _symbol
                if (sepsym == ']') return JV(arr)
                if (sepsym != ',') {
                    error = "unexpected array separator symbol `{to_char(sepsym)}` aka ASCII {sepsym} at {ahead.line}:{ahead.row}";
                    return null;
                }
            }
            error = "unexpected eos";
            return null;
        } elif (sym == '{') {
            var tab : table<string; JsonValue?>;
            while (!empty(itv)) {
                if (!expect_token(itv, ahead, Token_string, error)) {
                    if ((ahead.value is _symbol) && (ahead.value as _symbol) == '}' && empty(tab)) {
                        error = "";
                        return JV(tab);
                    }
                    return null;
                }
                let key = ahead.value as _string;
                if (!expect_symbol(itv, ahead, ':', error)) return null;
                var value = parse_value(itv, error);
                if (value == null) return null;
                if (!allow_duplicate_keys && key_exists(tab, key)) {
                    error = "duplicate key {key} at {ahead.line}:{ahead.row}";
                    return null;
                }
                tab |> insert(key, value);
                if (!expect_token(itv, ahead, Token_symbol, error)) return null;
                let sepsym = ahead.value as _symbol;
                if (sepsym == '}') {
                    break;
                } elif (sepsym != ',') {
                    error = "unexpected object separator symbol `{to_char(sepsym)}` aka ASCII {sepsym} at {ahead.line}:{ahead.row}";
                    return null;
                }
            }
            if (empty(itv)) {
                error = "unexpected eos";
                return null;
            }
            return JV(tab);
        } else {
            error = "unexpected symbol `{to_char(sym)}` aka ASCII {sym} at {ahead.line}:{ahead.row}";
            return null;
        }
    } elif (ahead.value is _string) {
        return JV(ahead.value as _string);
    } elif (ahead.value is _number) {
        return JV(ahead.value as _number);
    } elif (ahead.value is _longint) {
        return JV(ahead.value as _longint)
    } elif (ahead.value is _bool) {
        return JV(ahead.value as _bool);
    } elif (ahead.value is _null) {
        return JVNull();
    } else {
        error = "{ahead.value} at {ahead.line}:{ahead.row}";
        return null;
    }
}

def read_json(text : string implicit; var error : string&) : JsonValue? {
    
    
    error = ""
    var lex <- lexer(text)
    var res = parse_value(lex, error)
    delete lex
    return res
}

def read_json(text : array<uint8>; var error : string&) : JsonValue? {
    
    
    error = ""
    var lex <- lexer(text)
    var res = parse_value(lex, error)
    delete lex
    return res
}

var private no_trailing_zeros = false

def set_no_trailing_zeros(value : bool) {
    
    let old_ntz = no_trailing_zeros
    no_trailing_zeros = value
    return old_ntz
}

var private no_empty_arrays = false

def set_no_empty_arrays(value : bool) {
    
    let old_nea = no_empty_arrays
    no_empty_arrays = value
    return old_nea
}

var private allow_duplicate_keys = false

def set_allow_duplicate_keys(value : bool) {
    
    let old_adc = allow_duplicate_keys
    allow_duplicate_keys = value
    return old_adc
}

def private write_value(var writer : StringBuilderWriter; jsv : JsonValue?; depth : int) {
    
    if (jsv == null) {
        write(writer, "null")
    } elif (jsv.value is _string) {
        write(writer, "\"");
        write_escape_string(writer, jsv.value as _string);
        write(writer, "\"")
    } elif (jsv.value is _number) {
        if (no_trailing_zeros) {
            write(writer, fmt(":.17f", jsv.value as _number) |> rtrim("0") |> rtrim("."))
        } else {
            write(writer, jsv.value as _number)
        }
    } elif (jsv.value is _longint) {
        write(writer, jsv.value as _longint)
    } elif (jsv.value is _array) {
        if (empty(jsv.value as _array)) {
            write(writer, "[]")
        } else {
            write(writer, "[\n")
            var first = true
            for (elem in jsv.value as _array) {
                if (first) {
                    first = false
                } else {
                    write(writer, ",\n")
                }
                write_chars(writer, '\t', depth + 1)
                write_value(writer, elem, depth + 1)
            }
            write(writer, "\n")
            write_chars(writer, '\t', depth)
            write(writer, "]")
        }
    } elif (jsv.value is _object) {
        if (empty(jsv.value as _object)) {
            write(writer, "\{\}")
        } else {
            write(writer, "\{\n")
            var first = true
            for (elemK, elemV in keys(jsv.value as _object), values(jsv.value as _object)) {
                if (no_empty_arrays && elemV.value is _array && empty(elemV.value as _array)) continue
                if (first) {
                    first = false
                } else {
                    write(writer, ",\n")
                }
                write_chars(writer, '\t', depth + 1)
                write(writer, "\"");
                write_escape_string(writer, elemK);
                write(writer, "\" : ")
                write_value(writer, elemV, depth + 1)
            }
            write(writer, "\n")
            write_chars(writer, '\t', depth)
            write(writer, "\}")
        }
    } elif (jsv.value is _bool) {
        if (jsv.value as _bool) {
            write(writer, "true")
        } else {
            write(writer, "false")
        }
    } elif (jsv.value is _null) {
        write(writer, "null")
    } else {
        panic("unexpected {jsv}")
    }
}

[temp_string_result]
def write_json(val : JsonValue?) : string {
    
    let st = build_string() $(var writer) {
        write_value(writer, val, 0)
    }
    return st
}

def private write_value_compact(var writer : StringBuilderWriter; jsv : JsonValue?) {
    if (jsv == null) {
        write(writer, "null")
    } elif (jsv.value is _string) {
        write(writer, "\"")
        write_escape_string(writer, jsv.value as _string)
        write(writer, "\"")
    } elif (jsv.value is _number) {
        if (no_trailing_zeros) {
            write(writer, fmt(":.17f", jsv.value as _number) |> rtrim("0") |> rtrim("."))
        } else {
            write(writer, jsv.value as _number)
        }
    } elif (jsv.value is _longint) {
        write(writer, jsv.value as _longint)
    } elif (jsv.value is _array) {
        write(writer, "[")
        var first = true
        for (elem in jsv.value as _array) {
            if (first) {
                first = false
            } else {
                write(writer, ", ")
            }
            write_value_compact(writer, elem)
        }
        write(writer, "]")
    } elif (jsv.value is _object) {
        write(writer, "\{")
        var first = true
        for (elemK, elemV in keys(jsv.value as _object), values(jsv.value as _object)) {
            if (no_empty_arrays && elemV.value is _array && empty(elemV.value as _array)) {
                continue
            }
            if (first) {
                first = false
            } else {
                write(writer, ", ")
            }
            write(writer, "\"")
            write_escape_string(writer, elemK)
            write(writer, "\": ")
            write_value_compact(writer, elemV)
        }
        write(writer, "\}")
    } elif (jsv.value is _bool) {
        write(writer, (jsv.value as _bool) ? "true" : "false")
    } elif (jsv.value is _null) {
        write(writer, "null")
    } else {
        panic("unexpected {jsv}")
    }
}

[temp_string_result]
def write_json_compact(val : JsonValue?) : string {
    
    
    let st = build_string() $(var writer) {
        write_value_compact(writer, val)
    }
    return st
}

def write_json(val : JsonValue?#) : string {
    
    unsafe {
        return write_json(reinterpret<JsonValue?>(val))
    }
}

def delete_json(var jsv : JsonValue?) {
    
    if (jsv == null || jsv == g_json_null_sentinel) return
    unsafe { delete jsv; }
}

def update(var obj : JsonValue?; key : string; var jsv : JsonValue?) {
    
    if (obj == null || !(obj.value is _object)) return
    if (jsv == null || jsv == g_json_null_sentinel) {
        jsv = JVNull()
    }
    if (key_exists(obj.value as _object, key) && (obj.value as _object)[key] != jsv) {
        delete_json((obj.value as _object)[key])
    }
    (obj.value as _object) |> insert(key, jsv)
}

def try_fixing_broken_json(var bad : string) {  
    
    return build_string() $(writer) {
        peek_data(bad) $(str) {
            var i = 0
            let lstr = length(str)
            while (i < lstr) {
                while (i < lstr && str[i] != '"'u8) {
                    if (str[i] == ','u8) {
                        var j = i + 1;
                        while (j < lstr && is_white_space(int(str[j]))) {
                            j ++;
                        }
                        if (j < lstr && (str[j] == '}'u8 || str[j] == ']'u8)) {
                            i = j;
                            continue;
                        }
                    }
                    if (str[i] == '\\'u8 && i + 1 < lstr && str[i + 1] == 'u'u8) {
                        i += 2;
                        while (i < lstr && is_hex(int(str[i]))) {
                            i ++;
                        }
                        continue;
                    }
                    writer |> write_char(int(str[i]));
                    i ++;
                }
                if (i >= lstr) break
                writer |> write_char('"')
                i ++
                label 0:
                while (i < lstr && str[i] != '"'u8) {
                    writer |> write_char(int(str[i]));
                    i ++;
                }
                if (i >= lstr) {
                    writer |> write_char('"')
                    break
                }
                let nested = i
                var j = i + 1
                let any_white_space = j < lstr && is_white_space(int(str[j]))
                while (j < lstr && is_white_space(int(str[j]))) {
                    j ++
                }
                if (j >= lstr) {
                    writer |> write_char('"');
                    break;
                }
                let strj = int(str[j]);
                if (strj == ':' || strj == '}' || strj == ']' || strj == ',') {
                    writer |> write_char('"')
                    i ++
                    continue
                }
                if (strj == '+') {
                    j ++
                    while (j < lstr && is_white_space(int(str[j]))) {
                        j ++
                    }
                    if (j < lstr && str[j] == '"'u8) {
                        writer |> write_char(' ');
                        i = j + 1;
                        goto label 0;
                    }
                }
                if (any_white_space) {
                    writer |> write_char('"')
                    writer |> write_char(',')
                    i = nested + 1
                    continue
                }
                writer |> write("`")
                i = nested + 1
                while (i < lstr && str[i] != '"'u8) {
                    writer |> write_char(int(str[i]));
                    i ++;
                }
                if (i >= lstr) {
                    writer |> write("`");
                    writer |> write_char('"')
                    break
                }
                writer |> write("`")
                i ++
                goto label 0
            }
        }
    }
}
