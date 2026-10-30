options gen2
options indenting = 4
options no_aot = true

module tune shared public

require daslib/ast
require daslib/ast_boost

require [tune_framework] public
















[function_macro(name = "tune_perm")]
class private TunePermShell : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_perm_apply(func, group, args, errors)
        } else {
            return true
        }
    }
}

[function_macro(name = "tune_companion")]
class private TuneCompanionShell : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_companion_apply(func, group, args, errors)
        } else {
            return true
        }
    }
}

[function_macro(name = "tune")]
class private TuneShell : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_apply(func, group, args, errors)
        } else {
            return true
        }
    }
}

[structure_macro(name = "tune_scope")]
class private TuneScopeShell : AstStructureAnnotation {
    def override apply(var st : StructurePtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_scope_apply(st, group, args, errors)
        } else {
            return true
        }
    }
}

[function_macro(name = "tune_policy")]
class private TunePolicyShell : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_policy_apply(func, group, args, errors)
        } else {
            return true
        }
    }
}

[function_macro(name = "llvm_code")]
class private LlvmCodeShell : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       var args : AnnotationArgumentList; var errors : das_string) : bool {
        static_if (typeinfo module_exists(llvm_code)) {
            return llvm_code_apply(func, group, args, errors)
        } else {
            return true
        }
    }
}

[infer_macro]
class private TuneDefaultPolicyShell : AstPassMacro {
    def override apply(prog : ProgramPtr; mod : Module?) : bool {
        static_if (typeinfo module_exists(llvm_tune)) {
            return tune_default_policy_apply(prog, mod)
        } else {
            return false
        }
    }
}




[arch(at = "ARCHITECTURE.md#tune-shells-module-exists")]
def log_tune_status(appName : string) {
    var inscope rows <- tune_status_rows()
    if (empty(rows)) {
        return
    }
    var tuned = 0
    for (r in rows) {
        tuned += (r.source == "manifest" || r.source == "profile") ? 1 : 0
    }
    to_log(LOG_INFO, "{appName}: tune status ({tuned}/{length(rows)} kernels tuned for this box):\n")
    var fat = false
    for (r in rows) {
        
        let klass = empty(r.klass) ? "" : " [{r.klass}{r.active ? " <- this box" : ""}]"
        fat ||= !empty(r.klass)
        to_log(LOG_INFO, "  {r.fname}{klass}: {empty(r.suffix) ? "reference" : r.suffix} ({r.source})\n")
    }
    if (tuned < length(rows) && !fat) {
        to_log(LOG_INFO, "{appName}: run with --tune to tune the remaining kernels for this box\n")
    }
}



def private tune_status_rows() : array<tuple<fname : string; suffix : string; source : string; klass : string; active : bool>> {
    var rows : array<tuple<fname : string; suffix : string; source : string; klass : string; active : bool>>
    static_if (typeinfo module_exists(llvm_tune)) {
        var inscope st <- tune_status()
        rows |> reserve(length(st))
        for (s in st) {
            let active = !empty(s.klass) && (tune_fat_mask() & tune_fat_class_bit(s.klass)) != 0
            rows |> push((fname = s.fname, suffix = s.suffix, source = s.source, klass = s.klass, active = active))
        }
    }
    return <- rows
}
