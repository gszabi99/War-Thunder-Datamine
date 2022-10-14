from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

/*
   systemMsg  allow to send messages via config to localize and color on receiver side.
   It has short keys to be compact in json format allowed to use in irc chat etc.
   Also it save enough to be user generated.

  langConfig (table or array of tables):
  {
    [systemMsg.LOC_ID] - locId used to localize this config
                              when it set, all other keys in config are used as params for localizaation
                              but any param also can be langConfig
    [systemMsg.VALUE_ID] - exact value to show. used only when systemMsg.LOC_ID not set
    [systemMsg.COLOR_ID] - colorTag to colorize result of localize this config
                                can be used only colors from COLOR_TAG enum
                                to avoid broken markup by mistake or by users
  }
    also langConfig can be a simple string.
    it will be equal to { [systemMsg.LOC_ID] = "string" }

  example:
****  [
****    {
****      [systemMsg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
****      [systemMsg.COLOR_ID] = COLOR_TAG.ACTIVE,
****      chosenTeam =  {
****        [systemMsg.VALUE_ID] = "A",
****        [systemMsg.COLOR_ID] = COLOR_TAG.TEAM_BLUE,
****      }
****      otherTeam = {
****        [systemMsg.LOC_ID] = ::g_team.B.shortNameLocId,
****        [systemMsg.COLOR_ID] = COLOR_TAG.TEAM_RED,
****      }
****      chosenTeamCount = 5
****      otherTeamCount =  3
****      reqOtherteamCount = 4
****    }
****    "simpleLocIdNotColored"
****    {
****      [systemMsg.VALUE_ID] = "\nsome unlocalized text"
****    }
****  ]

also you can find example function below - dbgExample


  API:
  function configToLang(langConfig, paramValidateFunction = null)
    creates localized string by given <langConfig>
    but validate each text param by <paramValidateFunction>
    return null if failed to convert

  function configToJsonString(langConfig, paramValidateFunction = null)
    convert <langConfig> to json string,
    with prevalidation each config param by <paramValidateFunction>

  function jsonStringToLang(jsonString, paramValidateFunction = null)
    convert jsonString to langConfig and return localized string maked from it
    return null if failed to convert

  function makeColoredValue(colorTag, value)
    return simple langConfig with colored value
      { [COLOR_ID] = colorTag, [VALUE_ID] = value }

  function makeColoredLocId(colorTag, locId)
    return simple langConfig with colored localizationId (locId)
      { [COLOR_ID] = colorTag, [LOC_ID] = locId }
*/



let LOC_ID = "l"
let VALUE_ID = "t"
let COLOR_ID = "c"

let colors = {}
let getColorByTag = @(tag) colors?[tag] ?? ""

let locTags = {}
let getLocId = @(locTag) locTags?[locTag] ?? locTag

let function registerColors(colorsTable) //tag = color
{
  foreach(tag, color in colorsTable)
  {
    assert(!(tag in colors), "SystemMsg: Duplicate color tag: " + tag + " = " + color)
    colors[tag] <- color
  }
}

let function registerLocTags(locTagsTable) //tag = locId
{
  foreach(tag, locId in locTagsTable)
  {
    assert(!(tag in locTags), "SystemMsg: Duplicate locId tag: " + tag + " = " + locId)
    locTags[tag] <- locId
  }
}

let systemMsg = { //functons here need to be able recursive call self
  function validateLangConfig(langConfig, valueValidateFunction)
  {
    return ::u.map(
      langConfig,
      function(value) {
        if (::u.isString(value))
          return valueValidateFunction(value)
        else if (::u.isTable(value) || ::u.isArray(value))
          return validateLangConfig(value, valueValidateFunction)
        return value
      }.bindenv(this)
    )
  }

  function configToJsonString(langConfig, textValidateFunction = null)
  {
    if (textValidateFunction)
      langConfig = validateLangConfig(langConfig, textValidateFunction)

    let jsonString = ::save_to_json(langConfig)
    return jsonString
  }

  function convertAny(langConfig, paramValidateFunction = null, separator = "", defaultLocValue = null)
  {
    if (::u.isTable(langConfig))
      return convertTable(langConfig, paramValidateFunction)
    if (::u.isArray(langConfig))
    {
      let resArray = ::u.map(langConfig,
        (@(cfg) convertAny(cfg, paramValidateFunction) || "").bindenv(this))
      return ::g_string.implode(resArray, separator)
    }
    if (::u.isString(langConfig))
      return loc(getLocId(langConfig), defaultLocValue)
    return null
  }

  function convertTable(configTbl, paramValidateFunction = null)
  {
    local res = ""
    let locId = configTbl?[LOC_ID]
    if (!::u.isString(locId)) //res by value
    {
      let value = configTbl?[VALUE_ID]
      if (value == null)
        return res

      res = value.tostring()
      if (paramValidateFunction)
        res = paramValidateFunction(res)
    }
    else //res by locId with params
    {
      let params = {}
      foreach(key, param in configTbl)
      {
        let text = convertAny(param, paramValidateFunction, "", "")
        if (!::u.isEmpty(text))
        {
          params[key] <- text
          continue
        }

        local paramOut
        if (paramValidateFunction && ::u.isString(param))
          paramOut = paramValidateFunction(param)
        else
          paramOut = param
        params[key] <- paramOut
      }
      res = loc(getLocId(locId), params)
    }

    let colorName = getColorByTag(configTbl?[COLOR_ID])
    res = colorize(colorName, res)
    return res
  }

  function jsonStringToLang(jsonString, paramValidateFunction = null, separator = "")
  {
    let langConfig = ::parse_json(jsonString)
    return convertAny(langConfig, paramValidateFunction, separator)
  }
}

/*
getroottable().dbgExample <- function(textObjId = "menu_chat_text")
{
  local systemMsg = require("%scripts/utils/systemMsg.nut")
  local json = systemMsg.configToJsonString([
    {
      [systemMsg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
      [systemMsg.COLOR_ID] = COLOR_TAG.ACTIVE,
      chosenTeam = systemMsg.makeColoredValue(COLOR_TAG.TEAM_BLUE, ::g_team.A.getShortName())
      otherTeam = systemMsg.makeColoredValue(COLOR_TAG.TEAM_RED, ::g_team.B.getShortName())
      chosenTeamCount = 5
      otherTeamCount =  3
      reqOtherteamCount = 4
    }
    {
      [systemMsg.VALUE_ID] = "\n-------------------------------------\n"
    }
    {
      [systemMsg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
      [systemMsg.COLOR_ID] = COLOR_TAG.ACTIVE,
      chosenTeam = {
        [systemMsg.LOC_ID] = ::g_team.A.shortNameLocId,
        [systemMsg.COLOR_ID] = COLOR_TAG.TEAM_BLUE,
      }
      otherTeam = {
        [systemMsg.LOC_ID] = ::g_team.B.shortNameLocId,
        [systemMsg.COLOR_ID] = COLOR_TAG.TEAM_RED,
      }
      chosenTeamCount = 5
      otherTeamCount =  3
      reqOtherteamCount = 4
    }
  ])

  local res = systemMsg.jsonStringToLang(json)
  local testObj = ::get_gui_scene()[textObjId]
  if (checkObj(testObj))
    testObj.setValue(res)
  return json
}
*/

return {
  LOC_ID = LOC_ID
  VALUE_ID = VALUE_ID
  COLOR_ID = COLOR_ID

  registerColors = registerColors
  registerLocTags = registerLocTags

  configToJsonString  = @(langConfig, textValidateFunction = null)
    systemMsg.configToJsonString(langConfig, textValidateFunction)
  jsonStringToLang    = @(jsonString, paramValidateFunction = null, separator = "")
    systemMsg.jsonStringToLang(jsonString, paramValidateFunction, separator)
  configToLang        = @(langConfig, paramValidateFunction = null, separator = "", defaultLocValue = null)
    systemMsg.convertAny(langConfig, paramValidateFunction, separator, defaultLocValue)

  //return config of value which will be colored in result
  makeColoredValue = @(colorTag, value) { [COLOR_ID] = colorTag, [VALUE_ID] = value }
  //return config of localizationId which will be colored in result
  makeColoredLocId = @(colorTag, locId) { [COLOR_ID] = colorTag, [LOC_ID] = locId }
}