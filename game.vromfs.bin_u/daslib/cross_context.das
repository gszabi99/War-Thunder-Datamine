options gen2
options indenting = 4
options strict_smart_pointers

module cross_context shared public




require daslib/ast public
require daslib/rtti public
require daslib/debugger public

def private report_late_require(name : string; var mod : Module?; issues : das_string) : Module? {
    if (mod == null) {
        to_log(LOG_ERROR, "require_module_now({name}): {issues}")
    }
    return mod
}

def require_module_now(name : string) : Module? {
    
    
    
    if (!is_compiling()) {
        panic("require_module_now({name}): no program is compiling - a require after the walk is issued from a macro, a simulate macro or an [init], not from a running script")
    }
    var found : Module?
    var inscope no_access : smart_ptr<FileAccess>
    require_module_now(name, no_access, compiling_program().policies) $(var mod : Module?; issues : das_string) {
        found = report_late_require(name, mod, issues)
    }
    return found
}

def macro_context_of(name : string) : Context? {
    
    
    var mod = require_module_now(name)
    if (mod == null) {
        return null
    }
    if (!has_macro_context(mod)) {
        to_log(LOG_ERROR, "macro_context_of({name}): the module has no macro context")
        return null
    }
    return unsafe(addr(find_macro_context(mod)))
}
