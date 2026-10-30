import "DataBlock" as DataBlock
from "%sqstd/platform.nut" import isSony
from "dagor.localize" import getLocTextForLang
from "string" import split_by_chars
from "%scripts/dagui_natives.nut" import get_localization_blk_copy
from "%scripts/dagui_library.nut" import *
from "types" import String

local unlocksPunctuationWithoutSpace = ","
let setUnlocksPunctuationWithoutSpace = @(p)
  unlocksPunctuationWithoutSpace = p

const activityFeedRequestLocParams = {
  player        = "$USER_NAME_OR_ID"
  count         = "$STORY_COUNT"
  onlineUserId  = "$ONLINE_ID"
  productName   = "$PRODUCT_NAME"
  titleName     = "$TITLE_NAME"
  fiveStarValue = "$FIVE_STAR_VALUE"
  sourceCount   = "$SOURCE_COUNT"
}

function getLocIdsArray(keyValue) {
  if (keyValue == null)
    return [""]

  let parsedString = split_by_chars(keyValue, "; ")
  if (parsedString.len() <= 1)
    return [keyValue]

  let result = []
  foreach (idx, namePart in parsedString) {
    if (namePart.len() == 1 && unlocksPunctuationWithoutSpace.indexof(namePart) != null)
      result.remove(result.len() - 1) 

    result.append(namePart)
    
    if (idx != (parsedString.len() - 1))
      result.append(" ")
  }

  return result
}

function getLocalizedTextWithAbbreviation(locId) {
  if (!locId || !isSony)
    return {}

  let locBlk = DataBlock()
  get_localization_blk_copy(locBlk)

  if (!locBlk || ("abbreviation_languages_table" not in locBlk))
    return {}

  let abbreviationsList = locBlk.abbreviation_languages_table

  let output = {}
  for (local i = 0; i < abbreviationsList.paramCount(); i++) {
    let param = abbreviationsList.getParamValue(i)
    if (!(param instanceof String))
      continue

    let abbrevName = abbreviationsList.getParamName(i)
    let text = locId.len() > 1 ? getLocTextForLang(locId, param, "") : locId
    if (text == "") {
      log($"Error: not found localized text for locId = '{locId}', lang = '{param}'")
      continue
    }

    output[abbrevName] <- text
  }

  return output
}

function getFilledFeedTextByLang(locIdsArray) {
  let localizedTables = {}
  foreach (locId in locIdsArray) {
    let table = getLocalizedTextWithAbbreviation(locId)
    foreach (abbrev, string in table) {
      if (abbrev not in localizedTables)
        localizedTables[abbrev] <- ""
      localizedTables[abbrev] = "".concat(localizedTables[abbrev], string)
    }
  }

  let captions = []
  foreach (lang, string in localizedTables)
    captions.append({
      abbreviation = lang
      text = string.subst(activityFeedRequestLocParams).replace("\t", "")
    })

  return captions
}

return freeze({
  getLocIdsArray
  getLocalizedTextWithAbbreviation
  getFilledFeedTextByLang
  setUnlocksPunctuationWithoutSpace
})