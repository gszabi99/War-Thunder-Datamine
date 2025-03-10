from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import save_to_json


let u = require("%sqStdLibs/helpers/u.nut")
let { parse_json } = require("json")






































































let LOC_ID = "l"
let VALUE_ID = "t"
let COLOR_ID = "c"

let colors = {}
let getColorByTag = @(tag) colors?[tag] ?? ""

let locTags = {}
let getLocId = @(locTag) locTags?[locTag] ?? locTag

function registerColors(colorsTable) { 
  foreach (tag, color in colorsTable) {
    assert(!(tag in colors), $"SystemMsg: Duplicate color tag: {tag} = {color}")
    colors[tag] <- color
  }
}

function registerLocTags(locTagsTable) { 
  foreach (tag, locId in locTagsTable) {
    assert(!(tag in locTags), $"SystemMsg: Duplicate locId tag: {tag} = {locId}")
    locTags[tag] <- locId
  }
}

let systemMsg = { 
  function validateLangConfig(langConfig, valueValidateFunction) {
    return langConfig.map(function(value) {
        if (u.isString(value))
          return valueValidateFunction(value)
        else if (u.isTable(value) || u.isArray(value))
          return this.validateLangConfig(value, valueValidateFunction)
        return value
      }.bindenv(this)
    )
  }

  function configToJsonString(langConfig, textValidateFunction = null) {
    if (textValidateFunction)
      langConfig = this.validateLangConfig(langConfig, textValidateFunction)

    let jsonString = save_to_json(langConfig)
    return jsonString
  }

  function convertAny(langConfig, paramValidateFunction = null, separator = "", defaultLocValue = null) {
    if (u.isTable(langConfig))
      return this.convertTable(langConfig, paramValidateFunction)
    if (u.isArray(langConfig)) {
      let resArray = langConfig.map((@(cfg) this.convertAny(cfg, paramValidateFunction) || "").bindenv(this))
      return separator.join(resArray, true)
    }
    if (u.isString(langConfig))
      return loc(getLocId(langConfig), defaultLocValue)
    return null
  }

  function convertTable(configTbl, paramValidateFunction = null) {
    local res = ""
    let locId = configTbl?[LOC_ID]
    if (!u.isString(locId)) { 
      let value = configTbl?[VALUE_ID]
      if (value == null)
        return res

      res = value.tostring()
      if (paramValidateFunction)
        res = paramValidateFunction(res)
    }
    else { 
      let params = {}
      foreach (key, param in configTbl) {
        let text = this.convertAny(param, paramValidateFunction, "", "")
        if (!u.isEmpty(text)) {
          params[key] <- text
          continue
        }

        local paramOut
        if (paramValidateFunction && u.isString(param))
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

  function jsonStringToLang(jsonString, paramValidateFunction = null, separator = "") {
    let langConfig = parse_json(jsonString)
    return this.convertAny(langConfig, paramValidateFunction, separator)
  }
}











































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

  
  makeColoredValue = @(colorTag, value) { [COLOR_ID] = colorTag, [VALUE_ID] = value }
  
  makeColoredLocId = @(colorTag, locId) { [COLOR_ID] = colorTag, [LOC_ID] = locId }
}