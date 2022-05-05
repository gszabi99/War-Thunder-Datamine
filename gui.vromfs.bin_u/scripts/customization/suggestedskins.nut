let { getSuggestedSkins } = require("%scripts/customization/downloadableDecorators.nut")

const SUGGESTED_SKIN_SAVE_ID = "seen/suggestedSkins/"

let getSaveId = @(unitName) $"{SUGGESTED_SKIN_SAVE_ID}{unitName}"

let getSkin = @(skinId) ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)

let getSeenSuggestedSkins = @(unitName) ::load_local_account_settings(getSaveId(unitName))

let function needSuggestSkin(unitName, skinId) {
  let skinIds = getSuggestedSkins(unitName)
  if (skinId not in skinIds)
    return false

  return !(getSkin(skinIds[skinId])?.isUnlocked() ?? true)
}

let function getSuggestedSkin(unitName) {
  let skinIds = getSuggestedSkins(unitName)
  if (skinIds.len() == 0)
    return null
  let seenSuggestedSkins = getSeenSuggestedSkins(unitName)
  let skinId = skinIds.findvalue(@(s, key) !(seenSuggestedSkins?[key] ?? false) && !(getSkin(s)?.isUnlocked() ?? true))
  return getSkin(skinId)
}

let function saveSeenSuggestedSkin(unitName, skinId) {
  let skinIds = getSuggestedSkins(unitName)
  if (skinId not in skinIds)
    return

  let seenSuggestedSkins = getSeenSuggestedSkins(unitName) ?? {}
  if (seenSuggestedSkins?[skinId] ?? false)
    return

  seenSuggestedSkins[skinId] <- true
  ::save_local_account_settings(getSaveId(unitName), seenSuggestedSkins)
}

return {
  getSuggestedSkin
  needSuggestSkin
  saveSeenSuggestedSkin
}
