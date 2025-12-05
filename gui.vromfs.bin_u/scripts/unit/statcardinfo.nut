from "%scripts/dagui_library.nut" import *
let DataBlock = require("DataBlock")
let statCache = DataBlock()

function getStatCardInfo() {
  if(statCache.blockCount() > 0)
    return statCache

  statCache.tryLoad("config/statcard_info.blk") 
  return statCache
}

return {
  getStatCardInfo
}