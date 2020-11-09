local { isPlatformSony } = require("scripts/clientState/platform.nut")
local {
  getPreferredVersion = @() -1
} = isPlatformSony
  ? require("sonyLib/webApi.nut")
  : null

::g_localization <- {
  activityFeedRequestLocParams = {
    player = "$USER_NAME_OR_ID",
    count = "$STORY_COUNT",
    onlineUserId = "$ONLINE_ID",
    productName = "$PRODUCT_NAME",
    titleName = "$TITLE_NAME",
    fiveStarValue = "$FIVE_STAR_VALUE",
    sourceCount = "$SOURCE_COUNT"
  }

  function getLocIdsArray(config, key = "locId") {
    local keyValue = config?[key] ?? ""
    local parsedString = ::split(keyValue, "; ")
    if (parsedString.len() <= 1)
      return [keyValue]

    local result = []
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

    local locBlk = ::DataBlock()
    ::get_localization_blk_copy(locBlk)

    if (!locBlk || (!("abbreviation_languages_table" in locBlk)))
      return {}

    local abbreviationsList = locBlk.abbreviation_languages_table?[getPreferredVersion().tostring()] ?? ::DataBlock()

    local output = {}
    for (local i = 0; i < abbreviationsList.paramCount(); i++)
    {
      local param = abbreviationsList.getParamValue(i)
      if (typeof(param) != "string")
        continue

      local abbrevName = abbreviationsList.getParamName(i)
      local text = locId.len() > 1 ? ::dagor.getLocTextForLang(locId, param) : locId
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

g_localization.getFilledFeedTextByLang <- function getFilledFeedTextByLang(locIdsArray, customFeedParams = {})
{
  local localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- getLocalizedTextWithAbbreviation(customFeedParams[name])

  local activityFeed_config = ::combine_tables(activityFeedRequestLocParams, customFeedParams)

  local captions = []

  local localizedTables = {}
  foreach (locId in locIdsArray)
  {
    local table = getLocalizedTextWithAbbreviation(locId)
    foreach (abbrev, string in table)
    {
      if (!(abbrev in localizedTables))
        localizedTables[abbrev] <- ""
      localizedTables[abbrev] += string
    }
  }

  foreach(lang, string in localizedTables)
  {
    local localizationTable = {}
    foreach(name, value in activityFeed_config)
      localizationTable[name] <- localizedKeyWords?[name][lang] ?? value

    captions.append({
      abbreviation = lang
      text = ::stringReplace(string.subst(localizationTable), "\t", "")
    })
  }

  return captions
}

g_localization.formatLangTextsInStringStyle <- function formatLangTextsInStringStyle(langTextsArray)
{
  local formatedArray = ::u.map(langTextsArray, @(table) ::format("\"%s\":\"%s\"", table.abbreviation, table.text))
  return ::g_string.implode(formatedArray, ",")
}
