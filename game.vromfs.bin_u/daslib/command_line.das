options gen2

module command_line shared public





require strings
require fio_core














def get_das_exe() : string {
    let args <- get_command_line_arguments()
    if (empty(args)) return ""
    var exe = args[0]
    
    exe = replace(exe, "\\", "/")
    
    let last_slash = rfind(exe, "/")
    let dir = last_slash >= 0 ? slice(exe, 0, last_slash + 1) : ""
    
    let interpreter = get_platform_name() == "windows" ? "daslang.exe" : "daslang"
    var result = "{dir}{interpreter}"
    
    if (get_platform_name() == "windows") {
        result = replace(result, "/", "\\")
    }
    if (fexist(result)) return result
    let windows = get_platform_name() == "windows"
    let self = windows ? replace(exe, "/", "\\") : exe
    if (fexist(self)) return self
    if (windows && fexist("{self}.exe")) return "{self}.exe"
    return self
}
