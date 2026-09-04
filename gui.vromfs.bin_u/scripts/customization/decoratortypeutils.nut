import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "blkGetters" import get_decals_blk, get_skins_blk, get_attachable_blk
from "unitCustomization" import get_avail_ship_flags_blk
from "%scripts/dagui_library.nut" import *

let getShipFlags = require("%scripts/customization/shipFlags.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")

let cachedBlkByType = {}

function getDecorTypeBlk(decorTypeName) {
  if (cachedBlkByType?[decorTypeName])
    return cachedBlkByType[decorTypeName]

  if (decorTypeName == "FLAGS") {
    let resBlk = DataBlock()
    let flagsBlk = get_avail_ship_flags_blk() ?? getShipFlags()
    if (flagsBlk != null)
      resBlk.setFrom(flagsBlk)
    cachedBlkByType[decorTypeName] <- resBlk
  }
  else if (decorTypeName == "DECALS") {
    let resBlk = DataBlock()
    get_decals_blk(resBlk)
    cachedBlkByType[decorTypeName] <- resBlk
  }
  else if (decorTypeName == "ATTACHABLES") {
    cachedBlkByType[decorTypeName] <- get_attachable_blk()
  }
  else if (decorTypeName == "SKINS") {
    cachedBlkByType[decorTypeName] <- get_skins_blk()
  }
  else
    cachedBlkByType[decorTypeName] <- DataBlock()

  return cachedBlkByType[decorTypeName]
}

function needCacheDecorTypeByCategories(decorTypeName) {
  return decorTypeName != "SKINS"
}

function invalidateCache() {
  cachedBlkByType.clear()
}

function invalidateFlagCache() {
  cachedBlkByType.$rawdelete("FLAGS")
}

addListenersWithoutEnv({
  DecorCacheInvalidate = @(_) invalidateCache()
  BlksDataStorageLoaded = @(_) invalidateCache()
  HangarModelLoaded = @(_) invalidateFlagCache()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getDecorTypeBlk
  needCacheDecorTypeByCategories
}