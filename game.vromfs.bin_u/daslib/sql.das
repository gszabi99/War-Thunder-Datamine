options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module sql shared public














require daslib/option public
require daslib/result public








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
}
