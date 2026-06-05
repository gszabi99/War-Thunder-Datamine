options gen2
options indenting = 4
options unsafe_table_lookup = false
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module profiler_boost shared private







require daslib/profiler
require daslib/rtti public

def public enable_profiler(var ctx : Context) {
    
    profiler::set_enable_profiler(intptr(unsafe(addr(ctx))), true)
}

def public disable_profiler(var ctx : Context) {
    
    profiler::set_enable_profiler(intptr(unsafe(addr(ctx))), false)
}

def public enable_profiler_log(var ctx : Context) {
    
    profiler::set_enable_profiler_log(intptr(unsafe(addr(ctx))), true)
}

def public disable_profiler_log(var ctx : Context) {
    
    profiler::set_enable_profiler_log(intptr(unsafe(addr(ctx))), false)
}

