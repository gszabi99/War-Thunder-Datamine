options gen2
options indenting = 4
options no_global_variables = false

module lint_config shared private




































require daslib/fio
require daslib/json
require daslib/toml
require daslib/ast_boost
require daslib/strings_boost






def private resolved_config_path() : string {
    if (has_env_variable("DAS_LINT_CONFIG_PATH")) {
        let v = get_env_variable("DAS_LINT_CONFIG_PATH")
        if (!empty(v)) return v
    }
    return "{get_das_root()}/.lint_config"
}




def public load_env_disabled(var disabled_codes : table<string>) : void {
    return if (!has_env_variable("DAS_LINT_DISABLE"))
    for (part in split(get_env_variable("DAS_LINT_DISABLE"), ",")) {
        let code = strip(part)
        if (!empty(code) && !key_exists(disabled_codes, code)) {
            disabled_codes |> insert(code)
        }
    }
}




def public load_lint_config(var disabled_codes : table<string>) : void {
    load_lint_config_from_path(resolved_config_path(), disabled_codes)
    load_env_disabled(disabled_codes)
}




def public load_lint_config_from_path(path : string; var disabled_codes : table<string>) : void {
    let body = fread(path)
    if (empty(body)) return
    var error : string
    var root : JsonValue? = read_toml(body, error)
    if (root == null || !(root.value is _object)) return
    var root_obj & = unsafe(root.value as _object)
    if (!key_exists(root_obj, "rules")) return
    var rules_obj : JsonValue? = root_obj["rules"]
    if (rules_obj == null || !(rules_obj.value is _object)) return
    var rules & = unsafe(rules_obj.value as _object)
    for (code, val_jv in keys(rules), values(rules)) {
        if (val_jv == null || !(val_jv.value is _bool)) continue
        let enabled = val_jv.value as _bool
        if (enabled) {
            if (key_exists(disabled_codes, code)) {
                disabled_codes |> erase(code)
            }
        } else {
            if (!key_exists(disabled_codes, code)) {
                disabled_codes |> insert(code)
            }
        }
    }
}


def public seed_default_disabled(var disabled_codes : table<string>) : void {
    for (code in ["STYLE005", "LINT029", "LINT030"]) {
        if (!key_exists(disabled_codes, code)) {
            disabled_codes |> insert(code)
        }
    }
}

var private _cache_off : table<string>
var private _cache_on  : table<string>
var private _cache_path_excludes : array<string>
var private _cache_loaded = false

def private ensure_cache_loaded() : void {
    if (_cache_loaded) return
    _cache_loaded = true
    load_path_excludes_from_path(resolved_config_path(), _cache_path_excludes)
    let body = fread(resolved_config_path())
    if (empty(body)) return
    var error : string
    var root : JsonValue? = read_toml(body, error)
    if (root == null || !(root.value is _object)) return
    var root_obj & = unsafe(root.value as _object)
    if (!key_exists(root_obj, "rules")) return
    var rules_obj : JsonValue? = root_obj["rules"]
    if (rules_obj == null || !(rules_obj.value is _object)) return
    var rules & = unsafe(rules_obj.value as _object)
    for (code, val_jv in keys(rules), values(rules)) {
        if (val_jv == null || !(val_jv.value is _bool)) continue
        let enabled = val_jv.value as _bool
        if (enabled) {
            if (!key_exists(_cache_on, code)) _cache_on |> insert(code)
        } else {
            if (!key_exists(_cache_off, code)) _cache_off |> insert(code)
        }
    }
}



def public load_path_excludes_from_path(path : string; var excludes : array<string>) : void {
    let body = fread(path)
    if (empty(body)) return
    var error : string
    var root : JsonValue? = read_toml(body, error)
    if (root == null || !(root.value is _object)) return
    var root_obj & = unsafe(root.value as _object)
    if (!key_exists(root_obj, "paths")) return
    var paths_obj : JsonValue? = root_obj["paths"]
    if (paths_obj == null || !(paths_obj.value is _object)) return
    var paths & = unsafe(paths_obj.value as _object)
    if (!key_exists(paths, "exclude")) return
    var excl_jv : JsonValue? = paths["exclude"]
    if (excl_jv == null || !(excl_jv.value is _array)) return
    for (pat_jv in excl_jv.value as _array) {
        if (pat_jv != null && pat_jv.value is _string) {
            let pat = pat_jv.value as _string
            if (!empty(pat)) excludes |> push("{pat}")
        }
    }
}



def public matches_path_excludes(file : string; excludes : array<string>) : bool {
    return false if (empty(excludes))
    let gen = to_generic_path(file)
    var rel = gen
    let root = to_generic_path(get_das_root())
    if (!empty(root) && starts_with(gen, root + "/")) {
        rel = slice(gen, length(root) + 1)
    }
    for (pat in excludes) {
        if (match_glob(pat, rel) || match_glob(pat, gen)) return true
    }
    return false
}




def public is_lint_path_excluded(file : string) : bool {
    ensure_cache_loaded()
    return matches_path_excludes(file, _cache_path_excludes)
}




def public lint_config_forces_on(code : string) : bool {
    ensure_cache_loaded()
    return key_exists(_cache_on, code)
}


def public build_lint_macro_disabled(prog : ProgramPtr) : table<string> {
    let force_default_off = prog._options |> find_arg("_enable_default_off_rules") ?as tBool ?? false
    var disabled : table<string>
    if (!force_default_off) {
        seed_default_disabled(disabled)
    }
    ensure_cache_loaded()
    if (!force_default_off) {
        for (code in keys(_cache_off)) {
            if (!key_exists(disabled, code)) disabled |> insert(code)
        }
    }
    for (code in keys(_cache_on)) {
        if (key_exists(disabled, code)) disabled |> erase(code)
    }
    load_env_disabled(disabled)
    add_module_rule_overrides(prog, disabled)
    return <- disabled
}




def public add_module_rule_overrides(prog : ProgramPtr; var disabled_codes : table<string>) : void {
    apply_module_codes(prog, "_nolint", disabled_codes, true)
    apply_module_codes(prog, "_lint", disabled_codes, false)
}

def private apply_module_codes(prog : ProgramPtr; option : string;
                               var disabled_codes : table<string>; disable : bool) : void {
    let configured = prog._options |> find_arg(option)
    return if (!(configured is tString))
    for (part in split(configured as tString, ",")) {
        let code = part |> strip |> to_upper
        continue if (empty(code))
        if (disable) {
            if (!key_exists(disabled_codes, code)) {
                disabled_codes |> insert(code)
            }
        } elif (key_exists(disabled_codes, code)) {
            disabled_codes |> erase(code)
        }
    }
}

def private module_source_path(prog : ProgramPtr) : string {
    let mod = prog.getThisModule
    if (mod == null) return ""
    var res = ""
    peek(mod.fileName) $(fn) {
        res = fn |> replace("\\", "/")
    }
    return res
}

def private path_has_segment(file : string; seg : string) : bool {
    return starts_with(file, seg + "/") || find(file, "/" + seg + "/") >= 0
}



def public is_daslib_source(prog : ProgramPtr) : bool {
    return path_has_segment(module_source_path(prog), "daslib")
}



def public lint029_source_exempt(prog : ProgramPtr) : bool {
    return path_has_segment(module_source_path(prog), "daslib")
}

def public is_shipped_library_source(prog : ProgramPtr) : bool {
    let file = module_source_path(prog)
    return path_has_segment(file, "daslib") || path_has_segment(file, "modules")
}



def public is_core_library_source(prog : ProgramPtr) : bool {
    let file = module_source_path(prog)
    return ((path_has_segment(file, "daslib") || path_has_segment(file, "utils"))
        && !path_has_segment(file, "modules"))
}




struct public FormatPolicy {
    format_enabled : bool = true
    force_clean_comments : bool = false
}



def private with_config_table(path, table_name : string; blk : block<(var tbl : JsonValue?) : void>) {
    let body = fread(path)
    return if (empty(body))
    var error : string
    var root : JsonValue? = read_toml(body, error)
    return if (root == null)
    if (root.value is _object) {
        var root_obj & = unsafe(root.value as _object)
        if (key_exists(root_obj, table_name)) {
            var tbl_jv : JsonValue? = root_obj[table_name]
            if (tbl_jv != null && tbl_jv.value is _object) {
                blk |> invoke(tbl_jv)
            }
        }
    }
    unsafe {
        delete root
    }
}



def private docs_flag_at(config_path, key : string) : bool {
    var result = false
    with_config_table(config_path, "docs") $(var docs_jv) {
        var docs & = unsafe(docs_jv.value as _object)
        return if (!key_exists(docs, key))
        var val_jv : JsonValue? = docs[key]
        return if (val_jv == null || !(val_jv.value is _bool))
        result = val_jv.value as _bool
    }
    return result
}




def public rule_docs_only_at(config_path : string) : bool {
    return docs_flag_at(config_path, "rule_docs_only")
}

def private config_dir_of(file : string) : string {
    let dir = to_generic_path(dir_name(to_generic_path(file)))
    return empty(dir) ? "." : dir
}

def private take_format_key(var fmt_jv : JsonValue?; key : string; var dst : bool&; var decided : bool&) {
    return if (decided)
    var fmt & = unsafe(fmt_jv.value as _object)
    if (!key_exists(fmt, key)) return
    var val_jv : JsonValue? = fmt[key]
    if (val_jv == null || !(val_jv.value is _bool)) return
    dst = val_jv.value as _bool
    decided = true
}


struct public FormatJob {
    file : string
    strip_comments : bool
}




def public partition_by_format_policy(var files : array<string>; var skipped : array<string>) : array<FormatJob> {
    var jobs : array<FormatJob>
    jobs |> reserve(length(files))
    var policy_by_dir : table<string; FormatPolicy>
    for (file in files) {
        let dir = config_dir_of(file)
        if (!key_exists(policy_by_dir, dir)) {
            policy_by_dir[dir] = format_policy_for(file)
        }
        let policy = policy_by_dir?[dir] ?? FormatPolicy()
        if (!policy.format_enabled) {
            skipped |> push(file)
            continue
        }
        jobs |> push(FormatJob(file = file, strip_comments = policy.force_clean_comments))
    }
    delete files
    return <- jobs
}




def public format_policy_for(file : string) : FormatPolicy {
    var pol = FormatPolicy()
    var enabled_decided = false
    var clean_decided = false
    var dir = config_dir_of(file)
    while (true) {
        let cfg = dir == "." ? ".lint_config" : "{dir}/.lint_config"
        with_config_table(cfg, "format") $(var fmt_jv) {
            take_format_key(fmt_jv, "format_enabled", pol.format_enabled, enabled_decided)
            take_format_key(fmt_jv, "force_clean_comments", pol.force_clean_comments, clean_decided)
        }
        break if (enabled_decided && clean_decided)
        var st : FStat
        break if (stat(path_join(dir, ".git"), st))
        let up = dir_name(dir)
        if (empty(up) || up == dir) {
            break if (dir == ".")
            dir = "."
        } else {
            dir = up
        }
    }
    return pol
}




def public is_user_authored_body(fn : Function?) : bool {
    return true if (fn == null || !fn.flags.generated)
    return fn.flags._lambda || fn.moreFlags2.localFunction
}




def public is_lint_fixture_name(base : string) : bool {
    return starts_with(base, "_") && find(base, "fixture") >= 0
}

let public LINT_SKIP_HEADER_LINES = 16




def public lint_file_skip_reason(file : string; expect_skips : bool = true) : string {
    let text = fread(file)
    return "" if (empty(text))
    for (line, ln in split(text, "\n"), count()) {
        let trimmed = line |> strip
        return "(intentional compile errors via `expect`)" if (expect_skips && trimmed |> starts_with("expect "))
        if (ln < LINT_SKIP_HEADER_LINES && trimmed |> starts_with("// lint-skip-file")) {
            let colon = find(trimmed, ":")
            let reason = colon >= 0 ? strip(slice(trimmed, colon + 1)) : ""
            return empty(reason) ? "(lint-skip-file directive)" : "(lint-skip-file: {reason})"
        }
    }
    return ""
}


struct public LintIssue {
    code : string           
    message : string        
    file : string           
    line : int              
    column : int            
    last_line : int         
    last_column : int       
}



def public make_lint_issue(message : string; at : LineInfo) : LintIssue {
    return LintIssue(
        code = extract_lint_code(message),
        message = message,
        file = at.fileInfo != null ? "{at.fileInfo.name}" : "",
        line = int(at.line),
        column = int(at.column),
        last_line = int(at.last_line),
        last_column = int(at.last_column))
}
