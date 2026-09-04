options gen2
options indenting = 4
options _comment_hygiene = true

module linq_fold_sql shared public









require daslib/linq_fold_common public   
require daslib/ast_boost
require daslib/ast




[macro_function]
def sql_linq_loaded(prog : ProgramPtr) : bool {
    var found = false
    program_for_each_module(prog) $(mod) {
        if (mod.name == "sql_linq") {
            found = true
        }
    }
    return found
}

def private is_sql_table_select(c : ExprCall?) : bool {
    
    if (c._type == null || !c._type.isGoodArrayType || c._type.firstType == null) return false
    let st = c._type.firstType.structType
    if (st == null) return false
    for (annDecl in st.annotations) {
        if (annDecl.annotation.name == "sql_table" || annDecl.annotation.name == "sql_view"
                || annDecl.annotation.name == "sql_fts5") return true
    }
    return false
}




[macro_function]
def extract_sql_source(var expr : Expression?) : ExprCall? {
    var e = expr
    while (e != null && e is ExprCall) {
        var c = e as ExprCall
        if (get_call_short_name(c) == "select_from") {
            return is_sql_table_select(c) ? c : null
        }
        if (empty(c.arguments)) break
        e = c.arguments[0]
    }
    return null
}
