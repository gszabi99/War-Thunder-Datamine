options gen2
options no_unused_function_arguments = false





require strings






def get_das_exe() : string {
    let args <- get_command_line_arguments()
    if (empty(args)) {
        return ""
    }
    var exe = args[0]
    
    exe = replace(exe, "\\", "/")
    
    if (find(exe, ":") < 0 && first_character(exe) != '/') {
        exe = "{get_das_root()}/{exe}"
    }
    
    let last_slash = rfind(exe, "/")
    let dir = last_slash >= 0 ? slice(exe, 0, last_slash + 1) : ""
    
    let interpreter = get_platform_name() == "windows" ? "daslang.exe" : "daslang"
    var result = "{dir}{interpreter}"
    
    if (get_platform_name() == "windows") {
        result = replace(result, "/", "\\")
    }
    return result
}
