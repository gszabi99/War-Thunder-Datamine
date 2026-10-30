options gen2







module env_registry shared public

require daslib/clargs
require daslib/rtti
require daslib/fio
require strings
require daslib/strings_boost






def public env_is_set(name : string) : bool {
    return has_env_variable(name) && !empty(get_env_variable(name))
}

def public env_value_of(name : string) : string {
    return get_env_variable(name)
}



struct public EnvDocRow {
    name : string
    kind : string
    dflt : string
    doc : string
}

def public write_env_row(var w : StringBuilderWriter; name, kind, dflt, doc : string) {
    w |> write("| `{name}` | {kind} | {empty(dflt) ? "unset" : dflt} | {doc} |\n")
}

def public write_env_row(var w : StringBuilderWriter; row : EnvDocRow) {
    write_env_row(w, row.name, row.kind, row.dflt, row.doc)
}

def public write_env_info_rows(var w : StringBuilderWriter; info : CommandInfo) {
    for (a in info.args) {
        var kind = "number"
        if (a.value_type == Type.tBool) {
            kind = "flag"
        } elif (a.value_type == Type.tString) {
            kind = a.is_path ? "path" : "text"
        }
        var dflt = a.default_doc
        if (a.value_type == Type.tBool) {
            dflt = dflt == "true" ? "on" : (dflt == "false" ? "off" : dflt)
        }
        write_env_row(w, a.env_name, kind, dflt, a.doc_string)
    }
}

def public write_env_section(var w : StringBuilderWriter; title, note : string) {
    w |> write("\n## {title}\n\n")
    if (!empty(note)) {
        w |> write("{note}\n\n")
    }
    w |> write("| Variable | Type | Default | Effect |\n|---|---|---|---|\n")
}




def public write_env_doc_semantics(var w : StringBuilderWriter) {
    w |> write("Types: **flag** is unset-means-default, `0`/`false`/`off`/`no` (any case) is false and\n")
    w |> write("anything else true; **number** falls back to the default when unset or unparseable, with\n")
    w |> write("a logged warning on garbage; **text** and **path** are taken verbatim. A SET-BUT-EMPTY\n")
    w |> write("variable counts as unset everywhere. Every knob loads ONCE, at context init, into the\n")
    w |> write("`g_env_*` globals - hot code reads struct fields, and `set_env_variable` after startup\n")
    w |> write("is invisible (arm a child process's environment instead).\n")
}



def public push_info_names(var out : array<string>; info : CommandInfo) {
    out |> reserve(length(out) + length(info.args))
    for (a in info.args) {
        out |> push(a.env_name)
    }
}



def public save_generated_doc(path, body : string) : bool {
    var f = fopen(path, "wb")
    if (f == null) {
        to_log(LOG_ERROR, "env_registry: cannot write {path}\n")
        return false
    }
    fwrite(f, body)
    fclose(f)
    to_log(LOG_INFO, "env_registry: wrote {path} ({long_length(body)} bytes)\n")
    return true
}

let public ENV_READ_MARKERS = [
    "get_env_variable(\"",
    "has_env_variable(\"",
    "env_config_flag(\"",
    "env_config_int(\"",
    "env_config_int64(\"",
    "env_config_float(\"",
    "env_config_string(\"",
    "env_config_text(\""
]

let public ENV_SANCTIONED_MARKERS = [
    "env_is_set(\"",
    "env_value_of(\""
]

let public ENV_WRITE_MARKERS = [
    "set_env_variable(\""
]

let public ENV_BANNED_HELPERS = [
    "def private env_or(",
    "def env_or(",
    "def private pf_env_int(",
    "def private win_env_int(",
    "def env_int64(",
    "def private env_int64(",
    "def env_int(",
    "def private env_int(",
    "def env_str(",
    "def private env_str(",
    "def env_flag(",
    "def private env_flag(",
    "def env_int64_min(",
    "def private env_int64_min("
]

def private skip_path(path : string; skip : array<string>) : bool {
    let p = replace(path, "\\", "/")
    if (find(p, "_aot_generated") >= 0) {
        return true
    }
    for (s in skip) {
        if (find(p, s) >= 0) {
            return true
        }
    }
    return false
}

def private walk_das(dirpath : string; skip : array<string>; blk : block<(path : string; text : string) : void>) {
    dir(dirpath) $(name : string) {
        return if (name == "." || name == "..")
        let full = "{dirpath}/{name}"
        if (stat(full).is_dir) {
            return if (name == "_aot_generated" || name == "_llvm_aot_generated")
            walk_das(full, skip, blk)
        } elif (ends_with(name, ".das") && !skip_path(full, skip)) {
            let text = fread(full)
            if (!empty(text)) {
                blk |> invoke(full, text)
            }
        }
    }
}

def private collect_names(text : string; markers : array<string>; var out : table<string>) {
    peek_data(text) $(d) {
        for (marker in markers) {
            var from = 0
            while (true) {
                let hit = find(d, marker, from)
                break if (hit < 0)
                let start = hit + length(marker)
                let close = find(d, "\"", start)
                break if (close < 0)
                let name = slice(d, start, close)
                if (!empty(name) && !key_exists(out, name)) {
                    out |> insert(name)
                }
                from = close + 1
            }
        }
    }
}




def public scan_env_raw_reads(roots, skip : array<string>) : array<string> {
    var offenders : array<string>
    for (root in roots) {
        walk_das("{get_das_root()}/{root}", skip) $(path, text) {
            for (marker in ENV_READ_MARKERS) {
                if (find(text, marker) >= 0) {
                    offenders |> push("{path}: {marker}...\")")
                    break
                }
            }
        }
    }
    return <- offenders
}



def public scan_env_used_names(roots, skip : array<string>; var used : table<string>) : int {
    var files = 0
    for (root in roots) {
        walk_das("{get_das_root()}/{root}", skip) $(_path, text) {
            files++
            collect_names(text, ENV_READ_MARKERS, used)
            collect_names(text, ENV_SANCTIONED_MARKERS, used)
            collect_names(text, ENV_WRITE_MARKERS, used)
        }
    }
    return files
}


def public scan_env_banned_helpers(roots, skip : array<string>) : array<string> {
    var offenders : array<string>
    for (root in roots) {
        walk_das("{get_das_root()}/{root}", skip) $(path, text) {
            for (sig in ENV_BANNED_HELPERS) {
                if (find(text, sig) >= 0) {
                    offenders |> push("{base_name(path)}: {sig}...)")
                }
            }
        }
    }
    return <- offenders
}




def public env_undeclared_names(used : table<string>; declared : array<string>) : array<string> {
    var known : table<string>
    for (n in declared) {
        known |> insert(n)
    }
    var missing <- [for (n in keys(used)); n; where !key_exists(known, n)]
    delete known
    return <- missing
}


def public env_duplicate_names(names : array<string>) : array<string> {
    var seen : table<string>
    var dupes : array<string>
    for (n in names) {
        if (key_exists(seen, n)) {
            dupes |> push(n)
        } else {
            seen |> insert(n)
        }
    }
    delete seen
    return <- dupes
}


def public env_undocumented_rows(md : string) : array<string> {
    var undocumented : array<string>
    for (line in split(md, "\n")) {
        continue if (!starts_with(line, "| `"))
        var cols <- split(line, "|")
        if (length(cols) >= 5 && empty(strip(cols[4]))) {
            undocumented |> push(strip(cols[1]))
        }
        delete cols
    }
    return <- undocumented
}
