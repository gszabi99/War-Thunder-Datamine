from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")

let flagsCache = DataBlock()
function getShipFlags() {
  if(flagsCache.blockCount() > 0)
    return flagsCache

  flagsCache.tryLoad("config/ship_flags.blk") 
  return flagsCache
}

return getShipFlags