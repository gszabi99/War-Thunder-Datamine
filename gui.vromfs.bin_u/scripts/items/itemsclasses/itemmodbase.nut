local u = require("sqStdLibs/helpers/u.nut")

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

    local conditionsBlk = getConditionsBlk(blk)
    if (u.isDataBlock(conditionsBlk))
      initConditions(conditionsBlk)
  }

  getConditionsBlk = @(configBlk) null

  function initConditions(conditionsBlk)
  {
    if ("mod" in conditionsBlk)
      modsList = conditionsBlk % "mod"
    if ("unitType" in conditionsBlk)
      unitTypes = conditionsBlk % "unitType"
    if ("country" in conditionsBlk)
      countries = conditionsBlk % "country"

    local minRank = conditionsBlk?.minRank
    local maxRank = conditionsBlk?.maxRank
    if (shouldAlwaysShowRank || minRank || maxRank)
      rankRange = ::Point2(minRank || 1, maxRank || ::max_country_rank)
  }

  getDescriptionIntroArray = @() null
  getDescriptionOutroArray = @() null

  function getDescription()
  {
    local textParts = [base.getDescription()]

    local intro = getDescriptionIntroArray()
    if (intro)
      textParts.extend(intro)

    if (modsList)
    {
      local locMods = u.map(modsList,
        function(mod)
        {
          local res = ::loc("modification/" + mod + "/short", "")
          if (!res.len())
            res = ::loc("modification/" + mod)
          return res
        })
      textParts.append(::loc("multiAward/type/modification") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locMods, ", ")))
    }

    if (countries)
    {
      local locCountries = u.map(countries, @(country) ::loc("unlockTag/" + country))
      textParts.append(::loc("trophy/unlockables_names/country") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locCountries, ", ")))
    }
    if (unitTypes)
    {
      local locUnitTypes = u.map(unitTypes, @(unitType) ::loc("mainmenu/type_" + unitType))
      textParts.append(::loc("mainmenu/btnUnits") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locUnitTypes, ", ")))
    }

    local rankText = getRankText()
    if (rankText.len())
      textParts.append(::loc("sm_rank") + ::loc("ui/colon") + ::colorize("activeTextColor", rankText))

    local outro = getDescriptionOutroArray()
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

  function getIcon(addItemName = true)
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

    local res = ::LayersIcon.findLayerCfg("mod_upgrade_rank")
    if (res)
      res.img = "#ui/gameuiskin#item_rank_" + ::clamp(rankRange.y, 1, 6)
    return res
  }
}

return ModificationBase