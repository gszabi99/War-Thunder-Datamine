options gen2
options indenting = 4
options strict_smart_pointers = true

module tty shared public








require fio_core


let TTY_STDIN = 0
let TTY_STDOUT = 1
let TTY_STDERR = 2


let TTY_DEFAULT_WIDTH = 80

def is_stream_terminal(fd : int) : bool {
    
    
    return is_terminal(fd)
}

def is_stdin_terminal() : bool {
    
    return is_terminal(TTY_STDIN)
}

def is_stdout_terminal() : bool {
    
    
    return is_terminal(TTY_STDOUT)
}

def is_stderr_terminal() : bool {
    
    return is_terminal(TTY_STDERR)
}

def terminal_columns(fallback = TTY_DEFAULT_WIDTH) : int {
    
    
    let w = terminal_width()
    return w > 0 ? w : fallback
}
