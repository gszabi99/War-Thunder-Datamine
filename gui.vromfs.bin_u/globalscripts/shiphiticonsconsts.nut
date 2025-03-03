let { get_game_params_blk } = require("blkGetters")

let IS_SHIP_HIT_NOTIFICATIONS_VISIBLE = get_game_params_blk()?.isVisibleShipHitCounters ?? false

enum ShipHitIconId {
  HIT
  HIT_EFFECTIVE
  HIT_INEFFECTIVE
  HIT_PIERCE_THROUGH
}

let ShipHitIconVisibilityMask = {
  [ShipHitIconId.HIT]                = 1,
  [ShipHitIconId.HIT_EFFECTIVE]      = 2,
  [ShipHitIconId.HIT_INEFFECTIVE]    = 4,
  [ShipHitIconId.HIT_PIERCE_THROUGH] = 8
}

let ShipHitIconCfgId = {  // map to id used in loc and in hud.blk
  [ShipHitIconId.HIT]                = "simpleHit",
  [ShipHitIconId.HIT_EFFECTIVE]      = "effectiveHit",
  [ShipHitIconId.HIT_INEFFECTIVE]    = "ineffectiveHit",
  [ShipHitIconId.HIT_PIERCE_THROUGH] = "pierceThroughHit"
}

let SHIP_HIT_ICONS_VIS_ALL_FLAGS = ShipHitIconVisibilityMask
  .values()
  .reduce(@(sf, val) sf | val, 0)

return { ShipHitIconId, ShipHitIconVisibilityMask, ShipHitIconCfgId,
  IS_SHIP_HIT_NOTIFICATIONS_VISIBLE, SHIP_HIT_ICONS_VIS_ALL_FLAGS }