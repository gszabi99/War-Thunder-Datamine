options gen2
options indenting = 4
options strict_smart_pointers = true

module sql shared public














require daslib/option public
require daslib/result public
require strings

typedef SqlError = Option<string>




def sql_quote_id(s : string) : string {
    
    let escaped = s |> replace("\"", "\"\"")
    return "\"{escaped}\""
}

def sql_quote_lit(s : string) : string {
    
    
    let escaped = s |> replace("'", "''")
    return "'{escaped}'"
}



enum SqlType {
    Integer            
    Real               
    Text               
    Blob               
    Null               
}

struct ColumnInfo {
    name : string                  
    data_type : SqlType            
    is_pk : bool                   
    is_nullable : bool             
    default_expr : string          
    is_computed : bool             
}
