//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { getLocTextForLang } = require("dagor.localize")
let DataBlock = require("DataBlock")
let { split_by_chars } = require("string")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let {
  getPreferredVersion = @() -1
} = isPlatformSony
  ? require("%sonyLib/webApi.nut")
  : null

let activityFeedRequestLocParams = freeze({
  player        = "$USER_NAME_OR_ID"
  count         = "$STORY_COUNT"
  onlineUserId  = "$ONLINE_ID"
  productName   = "$PRODUCT_NAME"
  titleName     = "$TITLE_NAME"
  fiveStarValue = "$FIVE_STAR_VALUE"
  sourceCount   = "$SOURCE_COUNT"
})

let function getLocIdsArray(keyValue) {
  if (keyValue == null)
    return [""]

  let parsedString = split_by_chars(keyValue, "; ")
  if (parsedString.len() <= 1)
    return [keyValue]

  let result = []
  foreach (idx, namePart in parsedString) {
    if (namePart.len() == 1 && ::unlocks_punctuation_without_space.indexof(namePart) != null)
      result.remove(result.len() - 1) // remove previous space

    result.append(namePart)
    // Because of complexe string in result, better to manually add required spaces
    if (idx != (parsedString.len() - 1))
      result.append(" ")
  }

  return result
}

let function getLocalizedTextWithAbbreviation(locId) {
  if (!locId)
    return {}

  let locBlk = DataBlock()
  ::get_localization_blk_copy(locBlk)

  if (!locBlk || ("abbreviation_languages_table" not in locBlk))
    return {}

  let abbreviationsList = locBlk.abbreviation_languages_table?[getPreferredVersion().tostring()] ?? DataBlock()

  let output = {}
  for (local i = 0; i < abbreviationsList.paramCount(); i++) {
    let param = abbreviationsList.getParamValue(i)
    if (type(param) != "string")
      continue

    let abbrevName = abbreviationsList.getParamName(i)
    let text = locId.len() > 1 ? getLocTextForLang(locId, param) : locId
    if (text == null) {
      log($"Error: not found localized text for locId = '{locId}', lang = '{param}'")
      continue
    }

    output[abbrevName] <- text
  }

  return output
}

let function getFilledFeedTextByLang(locIdsArray, customFeedParams = {}) {
  let localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach (name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- getLocalizedTextWithAbbreviation(customFeedParams[name])

  let localizedTables = {}
  foreach (locId in locIdsArray) {
    let table = getLocalizedTextWithAbbreviation(locId)
    foreach (abbrev, string in table) {
      if (abbrev not in localizedTables)
        localizedTables[abbrev] <- ""
      localizedTables[abbrev] += string
    }
  }

  let activityFeedConfig = customFeedParams.__merge(activityFeedRequestLocParams)
  let captions = []
  foreach (lang, string in localizedTables) {
    let localizationTable = {}
    foreach (name, value in activityFeedConfig)
      localizationTable[name] <- localizedKeyWords?[name][lang] ?? value

    captions.append({
      abbreviation = lang
      text = ::stringReplace(string.subst(localizationTable), "\t", "")
    })
  }

  return captions
}

return {
  getLocIdsArray
  getLocalizedTextWithAbbreviation
  getFilledFeedTextByLang
}