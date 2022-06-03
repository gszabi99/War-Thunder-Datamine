let { format, split_by_chars } = require("string")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let {
  getPreferredVersion = @() -1
} = isPlatformSony
  ? require("%sonyLib/webApi.nut")
  : null

let activityFeedRequestLocParams = freeze({
  player = "$USER_NAME_OR_ID",
  count = "$STORY_COUNT",
  onlineUserId = "$ONLINE_ID",
  productName = "$PRODUCT_NAME",
  titleName = "$TITLE_NAME",
  fiveStarValue = "$FIVE_STAR_VALUE",
  sourceCount = "$SOURCE_COUNT"
})

::g_localization <- {
  function getLocIdsArray(config, key = "locId") {
    let keyValue = config?[key] ?? ""
    let parsedString = split_by_chars(keyValue, "; ")
    if (parsedString.len() <= 1)
      return [keyValue]

    let result = []
    foreach(idx, namePart in parsedString) {
      if (namePart.len() == 1 && ::unlocks_punctuation_without_space.indexof(namePart) != null)
        result.remove(result.len() - 1) //remove previouse space

      result.append(namePart)
      //Because of complexe string in result, better to manually add required spaces
      if (idx != (parsedString.len()-1))
        result.append(" ")
    }

    return result
  }

  function getLocalizedTextWithAbbreviation(locId)
  {
    if (!locId || (!("getLocTextForLang" in ::dagor)))
      return {}

    let locBlk = ::DataBlock()
    ::get_localization_blk_copy(locBlk)

    if (!locBlk || (!("abbreviation_languages_table" in locBlk)))
      return {}

    let abbreviationsList = locBlk.abbreviation_languages_table?[getPreferredVersion().tostring()] ?? ::DataBlock()

    let output = {}
    for (local i = 0; i < abbreviationsList.paramCount(); i++)
    {
      let param = abbreviationsList.getParamValue(i)
      if (typeof(param) != "string")
        continue

      let abbrevName = abbreviationsList.getParamName(i)
      let text = locId.len() > 1 ? ::dagor.getLocTextForLang(locId, param) : locId
      if (text == null)
      {
        ::dagor.debug("Error: not found localized text for locId = '" + locId + "', lang = '" + param + "'")
        continue
      }

      output[abbrevName] <- text
    }

    return output
  }
}

::g_localization.getFilledFeedTextByLang <- function getFilledFeedTextByLang(locIdsArray, customFeedParams = {})
{
  let localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- this.getLocalizedTextWithAbbreviation(customFeedParams[name])

  let activityFeed_config = customFeedParams.__merge(activityFeedRequestLocParams)

  let captions = []

  let localizedTables = {}
  foreach (locId in locIdsArray)
  {
    let table = this.getLocalizedTextWithAbbreviation(locId)
    foreach (abbrev, string in table)
    {
      if (!(abbrev in localizedTables))
        localizedTables[abbrev] <- ""
      localizedTables[abbrev] += string
    }
  }

  foreach(lang, string in localizedTables)
  {
    let localizationTable = {}
    foreach(name, value in activityFeed_config)
      localizationTable[name] <- localizedKeyWords?[name][lang] ?? value

    captions.append({
      abbreviation = lang
      text = ::stringReplace(string.subst(localizationTable), "\t", "")
    })
  }

  return captions
}

::g_localization.formatLangTextsInStringStyle <- function formatLangTextsInStringStyle(langTextsArray)
{
  let formatedArray = ::u.map(langTextsArray, @(table) format("\"%s\":\"%s\"", table.abbreviation, table.text))
  return ::g_string.implode(formatedArray, ",")
}
