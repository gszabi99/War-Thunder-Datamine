options gen2
options indenting = 4
options no_global_variables = false

module logger shared public




































require daslib/json public
require daslib/fio public
require strings
require daslib/jsonrpc
require daslib/debugger
require daslib/rtti



var private log_file : FILE const? = null
var private log_path : string
var private log_name : string
var private log_open_attempted = false
var private log_open_failed = false
var private log_min_level = LOG_INFO
var private log_category_overrides : table<string; int>
var private log_fallback_to_stderr = true
var private log_tee = false



def private level_name(level : int) : string {
    return "critical" if (level >= LOG_CRITICAL)
    return "error" if (level >= LOG_ERROR)
    return "warning" if (level >= LOG_WARNING)
    return "info" if (level >= LOG_INFO)
    return "debug" if (level >= LOG_DEBUG)
    return "trace"
}




def private resolve_level(category : string) : int {
    var probe = category
    while (true) {
        if (key_exists(log_category_overrides, probe)) return log_category_overrides[probe]
        let dot = probe |> rfind(".")
        break if (dot < 0)
        probe = probe |> slice(0, dot)
    }
    return log_min_level
}

def private should_log(level : int; category : string) : bool {
    return level >= resolve_level(category)
}

def private ensure_dir(path : string) {
    let dir = dir_name(path)
    return if (empty(dir))
    let st = stat(dir)
    return if (st.is_valid && st.is_dir)
    mkdir(dir)
}

def private ensure_open() {
    return if (log_file != null || log_open_failed || empty(log_path))
    log_open_attempted = true
    ensure_dir(log_path)
    log_file = fopen(log_path, "ab")
    if (log_file == null) {
        log_open_failed = true
    }
}




def private write_record(var w : StringBuilderWriter; ts, lvl, cat, msg : string; fields : JsonValue?) {
    w |> write("\{\"ts\":\"")
    write_escape_string(w, ts)
    w |> write("\",\"level\":\"")
    write_escape_string(w, lvl)
    w |> write("\",\"cat\":\"")
    write_escape_string(w, cat)
    w |> write("\",\"msg\":\"")
    write_escape_string(w, msg)
    if (fields != null) {
        w |> write("\",\"fields\":")
        
        w |> write(compact_json_whitespace(write_json(fields)))
        w |> write("}\n")
    } else {
        w |> write("\"}\n")
    }
}

def private emit(level : int; category, message : string; fields : JsonValue?) {
    return if (!should_log(level, category))
    ensure_open()
    let line = build_string() $(var w) {
        write_record(w, iso8601_now(), level_name(level), category, message, fields)
    }
    if (log_file != null) {
        fwrite(log_file, line)
        fflush(log_file)
        return
    }
    
    if (log_fallback_to_stderr) {
        fwrite(fstderr(), line)
    }
}



def logger_set_name(name : string) {
    
    
    
    let new_path = path_join(get_das_root(), "logs/{name}.log")
    logger_set_path(new_path)
    log_name = name
}

def logger_set_path(path : string) {
    
    
    if (path == log_path) return
    if (log_file != null) {
        fclose(log_file)
        log_file = null
    }
    log_path = path
    
    
    
    log_name = ""
    log_open_attempted = false
    log_open_failed = false
}

def logger_get_path() : string {
    
    return log_path
}

def logger_get_name() : string {
    
    
    return log_name
}

def logger_set_min_level(level : int) {
    
    
    log_min_level = level
}

def logger_get_min_level() : int {
    
    return log_min_level
}

def logger_set_category_level(category : string; level : int) {
    
    log_category_overrides[category] = level
}

def logger_clear_category_levels() {
    
    log_category_overrides |> clear
}

def logger_set_stderr_fallback(enabled : bool) {
    
    
    
    log_fallback_to_stderr = enabled
}



def logger_log(level : int; category, message : string; fields : JsonValue? = null) {
    
    emit(level, category, message, fields)
}

def logger_trace(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_TRACE, category, message, fields)
}

def logger_debug(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_DEBUG, category, message, fields)
}

def logger_info(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_INFO, category, message, fields)
}

def logger_warning(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_WARNING, category, message, fields)
}

def logger_error(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_ERROR, category, message, fields)
}

def logger_critical(category, message : string; fields : JsonValue? = null) {
    
    emit(LOG_CRITICAL, category, message, fields)
}



def logger_flush() {
    
    
    if (log_file != null) {
        fflush(log_file)
    }
}

def logger_close() {
    
    if (log_file != null) {
        fclose(log_file)
        log_file = null
    }
    log_open_attempted = false
    log_open_failed = false
}



let private LOGGER_AGENT_CATEGORY = "daslib_logger"

class private LogHookAgent : DapiDebugAgent {
    def override onLog(context : Context?; at : LineInfo const?; level : int; text : string#) : bool {
        
        if (empty(log_path) && !log_fallback_to_stderr) return false
        var fields : JsonValue? = null
        if (at != null && at.fileInfo != null) {
            fields = JV({"at" => JV("{at.fileInfo.name}:{at.line}")})
        }
        emit(level, "runtime", string(text), fields)
        return !log_tee   
    }
}

def logger_set_tee(tee : bool) {
    
    
    
    log_tee = tee
}

def logger_install_hook() {
    
    return if (has_debug_agent_context(LOGGER_AGENT_CATEGORY))
    install_new_debug_agent(new LogHookAgent(), LOGGER_AGENT_CATEGORY)
}

def logger_init(name : string) {
    
    
    logger_set_name(name)
    logger_install_hook()
}

def logger_init_tee(name : string) {
    
    
    logger_set_tee(true)
    logger_init(name)
}
