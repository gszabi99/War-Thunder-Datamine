from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let u = require("%sqStdLibs/helpers/u.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")

local ModificationBase = class extends ::BaseItem
{
  modsList = null
  unitTypes = null
  countries = null
  rankRange = null

  shouldAlwaysShowRank = false

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    let conditionsBlk = getConditionsBlk(blk)
    if (u.isDataBlock(conditionsBlk))
      initConditions(conditionsBlk)
  }

  getConditionsBlk = @(_configBlk) null

  function initConditions(conditionsBlk)
  {
    if ("mod" in conditionsBlk)
      modsList = conditionsBlk % "mod"
    if ("unitType" in conditionsBlk)
      unitTypes = conditionsBlk % "unitType"
    if ("country" in conditionsBlk)
      countries = conditionsBlk % "country"

    let minRank = conditionsBlk?.minRank
    let maxRank = conditionsBlk?.maxRank
    if (shouldAlwaysShowRank || minRank || maxRank)
      rankRange = ::Point2(minRank || 1, maxRank || ::max_country_rank)
  }

  getDescriptionIntroArray = @() null
  getDescriptionOutroArray = @() null

  function getDescription()
  {
    let textParts = [base.getDescription()]

    let intro = getDescriptionIntroArray()
    if (intro)
      textParts.extend(intro)

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      textParts.append(expireText)

    if (modsList)
    {
      let locMods = u.map(modsList,
        function(mod)
        {
          local res = loc("modification/" + mod + "/short", "")
          if (!res.len())
            res = loc("modification/" + mod)
          return res
        })
      textParts.append(loc("multiAward/type/modification") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locMods, ", ")))
    }

    if (countries)
    {
      let locCountries = u.map(countries, @(country) loc("unlockTag/" + country))
      textParts.append(loc("trophy/unlockables_names/country") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locCountries, ", ")))
    }
    if (unitTypes)
    {
      let processedUnitTypes = processUnitTypeArray(unitTypes)
      let locUnitTypes = u.map(processedUnitTypes, @(unitType) loc($"mainmenu/type_{unitType}"))
      textParts.append(loc("mainmenu/btnUnits") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locUnitTypes, ", ")))
    }

    let rankText = getRankText()
    if (rankText.len())
      textParts.append(loc("sm_rank") + loc("ui/colon") + colorize("activeTextColor", rankText))

    let outro = getDescriptionOutroArray()
    if (outro)
      textParts.extend(outro)

    return ::g_string.implode (textParts, "\n")
  }

  function getRankText()
  {
    if (rankRange)
      return ::get_roman_numeral(rankRange.x) +
        ((rankRange.x != rankRange.y) ? "-" + ::get_roman_numeral(rankRange.y) : "")
    return ""
  }

  function getIcon(_addItemName = true)
  {
    local res = ::LayersIcon.genDataFromLayer(getIconBgLayer())
    res += ::LayersIcon.genDataFromLayer(getIconMainLayer())
    res += ::LayersIcon.genDataFromLayer(getIconRankLayer())
    return res
  }

  getIconBgLayer = @() ::LayersIcon.findLayerCfg("mod_upgrade_bg")
  getIconMainLayer = @() null

  getIconRankLayer = function()
  {
    if (!rankRange)
      return null

    let res = ::LayersIcon.findLayerCfg("mod_upgrade_rank")
    if (res)
      res.img = $"#ui/gameuiskin#item_rank_{clamp(rankRange.y, 1, 6)}.png"
    return res
  }
}

return ModificationBase