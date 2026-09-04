options gen2
options indenting = 4

module jobque_profile shared public

















require jobque public
require daslib/build_const




let public JOBQUE_PROFILING_ENABLED = build_flag("--jobque-profiling", "JOBQUE_PROFILING")


let private DEFAULT_PALETTE = fixed_array<uint>(
    0x5E96DEu, 0x43B08Au, 0xAC82E4u, 0xC39536u, 0xE08563u, 0x4FC3D0u,
    0xD678B4u, 0x8385E8u, 0xD8626Au, 0x9BB556u, 0x7A9AAEu, 0xB08968u)

let public PROFILE_COLOR_BLUE = 0x5E96DEu
let public PROFILE_COLOR_GREEN = 0x43B08Au
let public PROFILE_COLOR_PURPLE = 0xAC82E4u
let public PROFILE_COLOR_AMBER = 0xC39536u
let public PROFILE_COLOR_CORAL = 0xE08563u
let public PROFILE_COLOR_TEAL = 0x4FC3D0u
let public PROFILE_COLOR_MAGENTA = 0xD678B4u
let public PROFILE_COLOR_INDIGO = 0x8385E8u

var private g_categoryIds : table<string; int>
var private g_usedCategoryIds : table<int>
var private g_markerIds : table<string; int>
var private g_nextCategoryId = 1

def private resolve_color(name : string; color : uint) : uint {
    if (color != 0u) return color
    return DEFAULT_PALETTE[int(hash(name) % uint64(length(DEFAULT_PALETTE)))]
}

def public profile_start(events_per_lane : int = 65536) {
    
    jobque_trace_start(events_per_lane)
}

def public profile_stop() {
    
    jobque_trace_stop()
}

def public profile_save(path : string) : bool {
    
    
    return jobque_trace_save(path)
}

def public profile_tag(tag : int) {   
    
    
    static_if (JOBQUE_PROFILING_ENABLED) {
        jobque_trace_tag(tag)
    }
}

def public profile_category(id : int; name : string; color : uint = 0u) {
    
    
    g_usedCategoryIds |> insert(id)
    g_categoryIds[name] = id
    jobque_trace_category(id, name, resolve_color(name, color))
}

def public profile_category(name : string; color : uint = 0u) : int {
    
    
    var id = g_categoryIds?[name] ?? -1
    if (id < 0) {
        while (g_usedCategoryIds |> key_exists(g_nextCategoryId)) {
            g_nextCategoryId++
        }
        id = g_nextCategoryId++
        g_usedCategoryIds |> insert(id)
        g_categoryIds[name] = id
    }
    jobque_trace_category(id, name, resolve_color(name, color))
    return id
}

[cold_path]   
def private profile_marker_register(name : string) : int {
    let id = jobque_trace_marker_name(name)
    g_markerIds[name] = id
    return id
}

def public profile_marker_id(name : string) : int {
    
    let existing = g_markerIds?[name] ?? -1
    if (existing >= 0) return existing
    return profile_marker_register(name)
}

def public profile_marker(id : int; arg : int = 0) {   
    
    
    static_if (JOBQUE_PROFILING_ENABLED) {
        jobque_trace_marker(id, arg)
    }
}

def public profile_marker(name : string; arg : int = 0) {   
    
    
    static_if (JOBQUE_PROFILING_ENABLED) {
        jobque_trace_marker(profile_marker_id(name), arg)
    }
}
