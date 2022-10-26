#no-root-fallback
#explicit-this

//this code is done for compatibility betweene sqplus and sqrat bindings
let DataBlock = getroottable()?["DataBlock"] ?? require("DataBlock")
return { DataBlock }