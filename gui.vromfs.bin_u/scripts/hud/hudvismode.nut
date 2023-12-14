from "%scripts/dagui_natives.nut" import get_hud_game_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let enums = require("%sqStdLibs/helpers/enums.nut")

::g_hud_vis_mode <- {
  types = []

  cache = { byHudGm = {} }
}

::g_hud_vis_mode.template <- {
  hudGm = HUD_GAME_MODE_DEFAULT
  locId = ""
  parts = HUD_VIS_PART.NONE

  getName = function() { return loc(this.locId) }
  isAvailable = function(_diffCode) { return true }
  isPartVisible = function(part) { return (this.parts & part) != 0 }
}

enums.addTypesByGlobalName("g_hud_vis_mode", {
  DEFAULT = {
    hudGm = HUD_GAME_MODE_DEFAULT
    locId = "options/hudDefault"
  }

  FULL = {
    hudGm = HUD_GAME_MODE_FULL
    locId = "options/hudFull"
    parts = HUD_VIS_PART.ALL
    isAvailable = function(diffCode) { return diffCode == DIFFICULTY_ARCADE || diffCode == DIFFICULTY_REALISTIC }
  }

  MINIMAL = {
    hudGm = HUD_GAME_MODE_MINIMAL
    locId = "options/hudNecessary"
    parts = HUD_VIS_PART.DMG_PANEL | HUD_VIS_PART.MAP | HUD_VIS_PART.CAPTURE_ZONE_INFO
            | HUD_VIS_PART.KILLCAMERA | HUD_VIS_PART.RACE_INFO
  }

  DISABLED = {
    hudGm = HUD_GAME_MODE_DISABLED
    locId = "options/hudMinimal"
    parts = HUD_VIS_PART.NONE
  }
})

::g_hud_vis_mode.types.sort(function(a, b) {
  return a.hudGm > b.hudGm ? 1 : (a.hudGm < b.hudGm ? -1 : 0)
})

::g_hud_vis_mode.getModeByHudGm <- function getModeByHudGm(hudGm, defValue = ::g_hud_vis_mode.DEFAULT) {
  return enums.getCachedType("hudGm", hudGm, ::g_hud_vis_mode.cache.byHudGm,
    ::g_hud_vis_mode, defValue)
}

::g_hud_vis_mode.getCurMode <- function getCurMode() {
  return this.getModeByHudGm(get_hud_game_mode(), ::g_hud_vis_mode.FULL)
}
