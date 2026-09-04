options gen2
options indenting = 4
options no_unused_function_arguments = false
options strict_smart_pointers

module sql_provider shared public

require daslib/ast public
require daslib/sql public
require strings










enum public SqlPkReport {
    
    LastInsertRowid
    ReturningPk
}

bitfield public SqlProviderCaps {
    
    fts5
    client_udfs
    returning
    distinct_on
}

struct public SchemaFromCol {
    
    
    
    name : string
    decl_type : string
    data_type : SqlType
    not_null : bool
    pk : bool
    generated : bool    
}

struct public SqlProviderInfo {
    
    
    
    name : string                                                
    runnerModule : string                                        
    runnerStruct : string                                        
    makeStmtType : function<() : TypeDeclPtr>                    
    makeStmtTypeConst : function<() : TypeDeclPtr>               
    renderPlaceholder : function<(ordinal : int) : string>       
    noLimitSpelling : string                                     
    renderJsonExtract : function<(target : string; jsonPath : string) : string>  
    quoteId : function<(id : string) : string>                   
    sqlTypeFor : function<(t : SqlType) : string>                
    identityDdl : string                                         
    readTableSchema : function<(path : string; tbl : string) : Result<array<SchemaFromCol>, string>>  
    caps : SqlProviderCaps
    pkReport : SqlPkReport
}

var private g_sql_providers : array<SqlProviderInfo>

def public sql_register_present_providers_done : bool {
    
    
    
    return !empty(g_sql_providers)
}

def public register_sql_provider(var info : SqlProviderInfo) {
    
    
    
    for (p in g_sql_providers) {
        if (p.runnerModule == info.runnerModule && p.runnerStruct == info.runnerStruct) {
            panic("register_sql_provider: duplicate runner key {info.runnerModule}::{info.runnerStruct} ({p.name} vs {info.name})")
        }
    }
    g_sql_providers |> emplace(info)
}

def public find_sql_provider_by_runner(runnerT : TypeDeclPtr) : int {
    
    
    if (runnerT == null || runnerT.structType == null) return -1
    let st = runnerT.structType
    if (st._module == null) return -1
    for (i in range(length(g_sql_providers))) {
        if (g_sql_providers[i].runnerStruct == st.name && g_sql_providers[i].runnerModule == st._module.name) {
            return i
        }
    }
    return -1
}

def public sql_provider_at(idx : int) : SqlProviderInfo {
    
    assert(idx >= 0 && idx < length(g_sql_providers), "sql_provider_at: index out of range")
    return g_sql_providers[idx]
}

def public sql_provider_count() : int => length(g_sql_providers)

def public sql_provider_names() : string {
    
    return build_string() $(var w) {
        for (i in range(length(g_sql_providers))) {
            if (i > 0) {
                w |> write(", ")
            }
            w |> write(g_sql_providers[i].name)
        }
    }
}
