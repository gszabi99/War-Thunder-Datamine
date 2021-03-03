//this code is done for compatibility betweene sqplus and sqrat bindings
local DataBlock = ("DataBlock" in getroottable()) ? ::DataBlock
 : require("DataBlock")
return { DataBlock }