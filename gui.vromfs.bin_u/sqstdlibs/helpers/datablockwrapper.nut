//this code is done for compatibility betweene sqplus and sqrat bindings
local DataBlock = require("DataBlock")
if ("DataBlock" in getroottable())
  DataBlock = ::DataBlock
return {DataBlock}