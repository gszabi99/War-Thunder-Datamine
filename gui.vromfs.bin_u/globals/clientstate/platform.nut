from "blkGetters" import get_settings_blk
from "%appGlobals/user/nickTools.nut" import isXBoxPlayerName, isPS4PlayerName
from "auth_wt" import get_player_tags
from "ps4" import ps4_get_region
from "guiScriptUtils" import has_entitlement
from "%sqstd/platform.nut" import isSony, isPC, is_android, is_gdk
from "%globalScripts/sceRegionConsts.nut" import *
import "%globalScripts/sharedWatched.nut" as sharedWatched

let PS4_REGION_NAMES = {
  [SCE_REGION_SCEE]  = "scee",
  [SCE_REGION_SCEA]  = "scea",
  [SCE_REGION_SCEJ]  = "scej"
}

let isPlayerFromXboxOne = @(name) is_gdk && isXBoxPlayerName(name)
let isPlayerFromPS4 = @(name) isSony && isPS4PlayerName(name)

let isMePS4Player = @() get_player_tags().indexof("ps4") != null
let isMeXBOXPlayer = @() get_player_tags().indexof("xbone") != null

let canSpendRealMoney = @() !isPC || is_gdk || (!has_entitlement("XBOXAccount") && !has_entitlement("PSNAccount"))

function isPlatformShieldTv() {
  return is_android && (get_settings_blk()?.deviceType ?? "") == "shieldTv"
}

let isPs4VsyncEnabled = sharedWatched("isPs4VsyncEnabled", @() true)

return freeze({
  isXBoxPlayerName = isXBoxPlayerName
  isPS4PlayerName = isPS4PlayerName
  isPlayerFromXboxOne = isPlayerFromXboxOne
  isPlayerFromPS4 = isPlayerFromPS4

  isMePS4Player = isMePS4Player
  isMeXBOXPlayer = isMeXBOXPlayer

  canSpendRealMoney = canSpendRealMoney

  ps4RegionName = @() PS4_REGION_NAMES[ps4_get_region()]

  isPlatformShieldTv
  isPs4VsyncEnabled
})
