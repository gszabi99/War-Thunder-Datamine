//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getSuggestedSkins } = require("%scripts/customization/downloadableDecorators.nut")
let DataBlock = require("DataBlock")

const SUGGESTED_SKIN_SAVE_ID = "seen/suggestedUnitsSkins/"
const UNIT_DATE_SAVE_ID = "lastSuggestedDate"
const UNIT_DELAY_TIME_SEC = 604800      //1 week
const SKIN_DELAY_TIME_SEC = 7776000     //90 days

let getSaveId = @(unitName) $"{SUGGESTED_SKIN_SAVE_ID}{unitName}"

let getSkin = @(skinId) ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)

let function getSeenSuggestedSkins(unitName) {
  let seenSkinsList = ::load_local_account_settings(getSaveId(unitName))
  //this code need for compatibility with old format. Format changed in 2.16.1.X, 31.05.2022
  let oldSaveId = $"seen/suggestedSkins/{unitName}"
  let oldSeenSkinsList = ::load_local_account_settings(oldSaveId)
  if (oldSeenSkinsList == null)
    return seenSkinsList

  let skinCount = oldSeenSkinsList.paramCount()
  let currentTime = ::get_charserver_time_sec()
  let validSkinsCfg = DataBlock()
  for (local i = 0; i < skinCount; i++)
    validSkinsCfg[oldSeenSkinsList.getParamName(i)] = currentTime

  ::save_local_account_settings(getSaveId(unitName), validSkinsCfg)
  ::save_local_account_settings(oldSaveId, null)
  return validSkinsCfg
}

let function isSeenSkin(skinId, seenSkinsList) {
  let seenTime = seenSkinsList?[skinId]
  if (seenTime == null)
    return false

  return seenTime + SKIN_DELAY_TIME_SEC > ::get_charserver_time_sec()
}

let function needSuggestSkin(unitName, skinId) {
  let skinIds = getSuggestedSkins(unitName)
  if (skinId not in skinIds)
    return false

  return !(getSkin(skinIds[skinId])?.isUnlocked() ?? true)
}

let function getSuggestedSkin(unitName) {
  if (!::g_login.isProfileReceived())
    return null
  let skinIds = getSuggestedSkins(unitName)
  if (skinIds.len() == 0)
    return null
  let seenSuggestedSkins = getSeenSuggestedSkins(unitName)
  let curTime = ::get_charserver_time_sec()
  let lastTime = seenSuggestedSkins?[UNIT_DATE_SAVE_ID]
  if (lastTime != null && (lastTime + UNIT_DELAY_TIME_SEC > curTime))
    return null
  let skinId = skinIds.findvalue(@(s, key) !isSeenSkin(key, seenSuggestedSkins)
    && !(getSkin(s)?.isUnlocked() ?? true))
  return getSkin(skinId)
}

let function saveSeenSuggestedSkin(unitName, skinId) {
  if (!::g_login.isProfileReceived())
    return
  let skinIds = getSuggestedSkins(unitName)
  if (skinId not in skinIds)
    return

  let seenSuggestedSkins = getSeenSuggestedSkins(unitName) ?? DataBlock()
  let curTime = ::get_charserver_time_sec()
  seenSuggestedSkins[skinId] = curTime
  seenSuggestedSkins[UNIT_DATE_SAVE_ID] = curTime
  ::save_local_account_settings(getSaveId(unitName), seenSuggestedSkins)
}

return {
  getSuggestedSkin
  needSuggestSkin
  saveSeenSuggestedSkin
}
