from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let getShipFlags = require("%scripts/customization/shipFlags.nut")
let { get_decals_blk, get_skins_blk, get_attachable_blk } = require("blkGetters")
let { get_avail_ship_flags_blk } = require("unitCustomization")


function getDecorTypeBlk(decorTypeName) {
  if (decorTypeName == "FLAGS") {
    let resBlk = DataBlock()
    let flagsBlk = get_avail_ship_flags_blk() ?? getShipFlags()
    if (flagsBlk != null)
      resBlk.setFrom(flagsBlk)
    return resBlk
  }
  else if (decorTypeName == "DECALS") {
    let resBlk = DataBlock()
    get_decals_blk(resBlk)
    return resBlk
  }
  else if (decorTypeName == "ATTACHABLES") {
    return get_attachable_blk()
  }
  else if (decorTypeName == "SKINS") {
    return get_skins_blk()
  }
  else { 
    return DataBlock()
  }
}

function needCacheDecorTypeByCategories(decorTypeName) {
  return decorTypeName != "SKINS"
}

return {
  getDecorTypeBlk
  needCacheDecorTypeByCategories
}