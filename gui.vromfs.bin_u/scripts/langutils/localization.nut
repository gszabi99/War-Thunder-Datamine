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
}

g_localization.getFilledFeedTextByLang <- function getFilledFeedTextByLang(locIdsArray, customFeedParams = {})
{
  local localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- ::get_localized_text_with_abbreviation(customFeedParams[name])

  local activityFeed_config = ::combine_tables(activityFeedRequestLocParams, customFeedParams)

  local captions = []

  local localizedTables = {}
  foreach (locId in locIdsArray)
  {
    local table = ::get_localized_text_with_abbreviation(locId)
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
