options gen2
options indenting = 4
options strict_smart_pointers = true

module jsonrpc shared public





















require daslib/json
require daslib/json_boost
require strings




let public PARSE_ERROR      = -32700  
let public INVALID_REQUEST  = -32600  
let public METHOD_NOT_FOUND = -32601  
let public INVALID_PARAMS   = -32602  
let public INTERNAL_ERROR   = -32603  




struct public ParsedRequest {
    id_str          : string       
    method          : string       
    params_json     : string       
    params          : JsonValue?   
    is_notification : bool         
    error_envelope  : string       
}

struct public ParsedBatch {
    is_batch        : bool                   
    requests        : array<ParsedRequest>   
    framing_error   : string                 
}




struct public ParsedResponse {
    id_str       : string         
    is_success   : bool           
    result_json  : string         
    error_code   : int            
    error_msg    : string         
    error_data   : string         
    parse_error  : string         
}

struct public ParsedResponseBatch {
    is_batch    : bool                        
    responses   : array<ParsedResponse>       
    parse_error : string                      
}




def public response(id_str : string; result_json : string) : string {
    
    
    return "\{\"jsonrpc\":\"2.0\",\"id\":{id_str},\"result\":{result_json}}"
}

def public error(id_str : string; code : int; message : string) : string {
    
    let msg_json = write_json(JV(message))
    return "\{\"jsonrpc\":\"2.0\",\"id\":{id_str},\"error\":\{\"code\":{code},\"message\":{msg_json}}}"
}

def public error_with_data(id_str : string; code : int; message, data_json : string) : string {
    
    
    let msg_json = write_json(JV(message))
    return "\{\"jsonrpc\":\"2.0\",\"id\":{id_str},\"error\":\{\"code\":{code},\"message\":{msg_json},\"data\":{data_json}}}"
}

def public serialize_id(id_val : JsonValue?) : string {
    
    
    return id_val == null ? "null" : write_json(id_val)
}




def public make_request(method : string; params_json : string; id : int) : string {
    
    
    let method_str = write_json(JV(method))
    return "\{\"jsonrpc\":\"2.0\",\"id\":{id},\"method\":{method_str},\"params\":{params_json}}"
}

def public make_request(method : string; params_json : string; id : string) : string {
    
    let method_str = write_json(JV(method))
    let id_str = write_json(JV(id))
    return "\{\"jsonrpc\":\"2.0\",\"id\":{id_str},\"method\":{method_str},\"params\":{params_json}}"
}

def public make_notification(method : string; params_json : string) : string {
    
    let method_str = write_json(JV(method))
    return "\{\"jsonrpc\":\"2.0\",\"method\":{method_str},\"params\":{params_json}}"
}

def public make_batch(messages : array<string>) : string {
    
    return build_string() $(var w) {
        write_char(w, '[')
        var first = true
        for (m in messages) {
            if (!first) write_char(w, ',')
            first = false
            write(w, m)
        }
        write_char(w, ']')
    }
}




def private parse_one_request(body_value : JsonValue?; strict : bool) : ParsedRequest {
    var result = ParsedRequest(id_str = "null")
    if (body_value == null || !(body_value.value is _object)) {
        result.error_envelope = error("null", INVALID_REQUEST, "invalid request: not a JSON object")
        return result
    }
    let body & = unsafe(body_value.value as _object)
    let id_v = body?["id"] ?? null
    let method_v = body?["method"] ?? null
    
    var params_v = unsafe(reinterpret<JsonValue?>(body?["params"] ?? null))
    
    if (id_v != null && !(id_v.value is _string) && !(id_v.value is _number) && !(id_v.value is _longint) && !(id_v.value is _null)) {
        result.error_envelope = error("null", INVALID_REQUEST, "invalid request: id must be string, number, or null")
        return result
    }
    result.id_str = serialize_id(id_v)
    if (method_v == null || !(method_v.value is _string)) {
        
        result.error_envelope = error(result.id_str, INVALID_REQUEST, "invalid request: missing or non-string method")
        return result
    }
    
    if (strict) {
        let jsonrpc_v = body?["jsonrpc"] ?? null
        if (jsonrpc_v == null || !(jsonrpc_v.value is _string) || (jsonrpc_v.value as _string) != "2.0") {
            result.error_envelope = error(result.id_str, INVALID_REQUEST, "invalid request: jsonrpc field must be \"2.0\"")
            return result
        }
    }
    
    if (params_v != null && !(params_v.value is _object) && !(params_v.value is _array) && !(params_v.value is _null)) {
        result.error_envelope = error(result.id_str, INVALID_PARAMS, "invalid params: must be array or object")
        return result
    }
    result.is_notification = (id_v == null)
    result.method = method_v.value as _string
    result.params = params_v
    result.params_json = params_v == null ? "null" : write_json(params_v)
    return result
}

def public parse_request(line : string; strict : bool = false) : ParsedRequest {
    
    var result = ParsedRequest(id_str = "null")
    var parse_error_msg = ""
    var parsed = read_json(line, parse_error_msg)
    if (parsed == null) {
        result.error_envelope = error("null", PARSE_ERROR, "parse error: {parse_error_msg}")
        return result
    }
    return parse_one_request(parsed, strict)
}

def public parse_batch(line : string; strict : bool = false) : ParsedBatch {
    
    var result : ParsedBatch
    var parse_error_msg = ""
    var parsed = read_json(line, parse_error_msg)
    if (parsed == null) {
        result.framing_error = error("null", PARSE_ERROR, "parse error: {parse_error_msg}")
        return <- result
    }
    if (parsed.value is _array) {
        result.is_batch = true
        let arr & = unsafe(parsed.value as _array)
        if (empty(arr)) {
            result.framing_error = error("null", INVALID_REQUEST, "invalid request: empty batch")
            return <- result
        }
        result.requests |> reserve(length(arr))
        for (entry in arr) {
            let ev = unsafe(reinterpret<JsonValue?>(entry))
            result.requests |> push(parse_one_request(ev, strict))
        }
        return <- result
    }
    
    result.is_batch = false
    result.requests |> push(parse_one_request(parsed, strict))
    return <- result
}




def private parse_one_response(body_value : JsonValue?) : ParsedResponse {
    var result = ParsedResponse(id_str = "null", is_success = false)
    if (body_value == null || !(body_value.value is _object)) {
        result.parse_error = "response is not a JSON object"
        return result
    }
    let body & = unsafe(body_value.value as _object)
    let id_v = body?["id"] ?? null
    let result_v = body?["result"] ?? null
    let error_v = body?["error"] ?? null
    result.id_str = serialize_id(id_v)
    if (result_v != null) {
        result.is_success = true
        result.result_json = write_json(result_v)
        return result
    }
    if (error_v == null || !(error_v.value is _object)) {
        result.parse_error = "response missing both `result` and a valid `error`"
        return result
    }
    let err & = unsafe(error_v.value as _object)
    let code_v = err?["code"] ?? null
    let msg_v = err?["message"] ?? null
    let data_v = err?["data"] ?? null
    if (code_v != null && code_v.value is _longint) {
        result.error_code = int(code_v.value as _longint)
    } elif (code_v != null && code_v.value is _number) {
        result.error_code = int(code_v.value as _number)
    }
    if (msg_v != null && msg_v.value is _string) {
        result.error_msg = msg_v.value as _string
    }
    if (data_v != null) {
        result.error_data = write_json(data_v)
    }
    return result
}

def public parse_response(line : string) : ParsedResponse {
    
    var result = ParsedResponse(id_str = "null", is_success = false)
    var parse_error_msg = ""
    var parsed = read_json(line, parse_error_msg)
    if (parsed == null) {
        result.parse_error = "parse error: {parse_error_msg}"
        return result
    }
    return parse_one_response(parsed)
}

def public parse_response_batch(line : string) : ParsedResponseBatch {
    
    var result : ParsedResponseBatch
    var parse_error_msg = ""
    var parsed = read_json(line, parse_error_msg)
    if (parsed == null) {
        result.parse_error = "parse error: {parse_error_msg}"
        return <- result
    }
    if (parsed.value is _array) {
        result.is_batch = true
        let arr & = unsafe(parsed.value as _array)
        result.responses |> reserve(length(arr))
        for (entry in arr) {
            let ev = unsafe(reinterpret<JsonValue?>(entry))
            result.responses |> push(parse_one_response(ev))
        }
        return <- result
    }
    result.is_batch = false
    result.responses |> push(parse_one_response(parsed))
    return <- result
}




def public compact_json_whitespace(s : string) : string {
    
    return build_string() $(var w) {
        peek_data(s) $(bytes) {
            var in_string = false
            var escape = false
            for (raw_b in bytes) {
                let b = int(raw_b)
                if (in_string) {
                    write_char(w, b)
                    if (escape) {
                        escape = false
                    } elif (b == '\\') {
                        escape = true
                    } elif (b == '"') {
                        in_string = false
                    }
                } else {
                    if (b == '"') {
                        in_string = true
                        write_char(w, b)
                    } elif (b != ' ' && b != '\n' && b != '\t' && b != '\r') {
                        write_char(w, b)
                    }
                }
            }
        }
    }
}




def private dispatch_one(req : ParsedRequest; dispatcher : block<(method : string; params_json : string) : string>) : string {
    if (!empty(req.error_envelope)) return req.is_notification ? "" : req.error_envelope
    let result_json = invoke(dispatcher, req.method, req.params_json)
    return req.is_notification ? "" : response(req.id_str, result_json)
}

def public dispatch_line(line : string; strict : bool; dispatcher : block<(method : string; params_json : string) : string>) : string {
    
    let pb = parse_batch(line, strict)
    if (!empty(pb.framing_error)) return pb.framing_error
    if (!pb.is_batch) return dispatch_one(pb.requests[0], dispatcher)
    var parts : array<string>
    for (req in pb.requests) {
        let r = dispatch_one(req, dispatcher)
        if (!empty(r)) parts |> push(r)
    }
    if (empty(parts)) return ""
    return build_string() $(var w) {
        write_char(w, '[')
        var first = true
        for (p in parts) {
            if (!first) write_char(w, ',')
            first = false
            write(w, p)
        }
        write_char(w, ']')
    }
}
