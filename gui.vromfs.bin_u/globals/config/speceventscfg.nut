from "%globalScripts/unitTypeConsts.nut" import *

const eventsFilters = [
  {
    id = $"unitType_{ES_UNIT_TYPE_AIRCRAFT}"
    locId = "options/chooseUnitsType/aircraft"
  }
  {
    id = $"unitType_{ES_UNIT_TYPE_TANK}"
    locId = "options/chooseUnitsType/tank"
  }
  {
    id = $"unitType_{ES_UNIT_TYPE_SHIP}"
    locId = "options/chooseUnitsType/ship"
  }
]


let eventsCfg = {
  ["2026_08_ship/tasks"] = {
    eventLocId = "unlocks/chapter/2026_08_ship"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/ussr_battleship_oktyabrskaya_revolutsiya_promo.png"
    groups = ["2026_08_ship/coupon_upgrade", "2026_08_ship/tasks"]
    unitType = ES_UNIT_TYPE_SHIP
  },
  ["2026_07_tank/tasks"] = {
    eventLocId = "unlocks/chapter/2026_07_tank"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/uk_fv107_scimitar_mk2_promo.png"
    groups = ["2026_07_tank/coupon_upgrade", "2026_07_tank/tasks"]
    unitType = ES_UNIT_TYPE_TANK
  },
  ["2026_06_air/tasks"] = {
    eventLocId = "unlocks/chapter/2026_06_air"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/spitfire_mk5b_float_promo.png"
    groups = ["2026_06_air/coupon_upgrade", "2026_06_air/tasks"]
    unitType = ES_UNIT_TYPE_AIRCRAFT
  },
  ["2026_05_ship/tasks"] = {
    eventLocId = "unlocks/chapter/2026_05_ship"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/fr_trident_class_glaive_p671_promo.png"
    groups = ["2026_05_ship/coupon_upgrade", "2026_05_ship/tasks"]
    unitType = ES_UNIT_TYPE_SHIP
  },
  ["2026_05_tank/tasks"] = {
    eventLocId = "unlocks/chapter/2026_05_tank"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/ussr_kv_8_promo.png"
    groups = ["2026_05_tank/coupon_upgrade", "2026_05_tank/tasks"]
    unitType = ES_UNIT_TYPE_TANK
  },
  ["2026_04_air/tasks"] = {
    eventLocId = "unlocks/chapter/2026_04_air"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/f_6c_pakistan_promo.png"
    groups = ["2026_04_air/coupon_upgrade", "2026_04_air/tasks"]
    unitType = ES_UNIT_TYPE_AIRCRAFT
  },
  ["2026_03_ship/tasks"] = {
    eventLocId = "unlocks/chapter/2026_03_ship"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/us_battleship_oklahoma_promo.png"
    groups = ["2026_03_ship/coupon_upgrade", "2026_03_ship/tasks"]
    unitType = ES_UNIT_TYPE_SHIP
  },
  ["2026_02_air/tasks"] = {
    eventLocId = "unlocks/chapter/2026_02_air"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/f_16a_block_5_netherlands_promo.png"
    groups = ["2026_02_air/coupon_upgrade", "2026_02_air/tasks"]
    unitType = ES_UNIT_TYPE_AIRCRAFT
  },
  ["2026_01_tank/tasks"] = {
    eventLocId = "unlocks/chapter/2026_01_tank"
    bgImage = "!https://static-ggc.gaijin.net/event_promo/ussr_t_72b3_arena_promo.png"
    groups = ["2026_01_tank/coupon_upgrade", "2026_01_tank/tasks"]
    unitType = ES_UNIT_TYPE_TANK
  },

  





























}

return freeze({
  eventsCfg
  eventsFilters
})
