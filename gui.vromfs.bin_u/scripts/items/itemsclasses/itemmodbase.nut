//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let u = require("%sqStdLibs/helpers/u.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { Point2 } = require("dagor.math")


local ModificationBase = class extends ::BaseItem {
  modsList = null
  unitTypes = null
  countries = null
  rankRange = null

  shouldAlwaysShowRank = false

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)

    let conditionsBlk = this.getConditionsBlk(blk)
    if (u.isDataBlock(conditionsBlk))
      this.initConditions(conditionsBlk)
  }

  getConditionsBlk = @(_configBlk) null

  function initConditions(conditionsBlk) {
    if ("mod" in conditionsBlk)
      this.modsList = conditionsBlk % "mod"
    if ("unitType" in conditionsBlk)
      this.unitTypes = conditionsBlk % "unitType"
    if ("country" in conditionsBlk)
      this.countries = conditionsBlk % "country"

    let minRank = conditionsBlk?.minRank
    let maxRank = conditionsBlk?.maxRank
    if (this.shouldAlwaysShowRank || minRank || maxRank)
      this.rankRange = Point2(minRank || 1, maxRank || ::max_country_rank)
  }

  getDescriptionIntroArray = @() null
  getDescriptionOutroArray = @() null

  function getDescription() {
    let textParts = [base.getDescription()]

    let intro = this.getDescriptionIntroArray()
    if (intro)
      textParts.extend(intro)

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      textParts.append(expireText)

    if (this.modsList) {
      let locMods = u.map(this.modsList,
        function(mod) {
          local res = loc("modification/" + mod + "/short", "")
          if (!res.len())
            res = loc("modification/" + mod)
          return res
        })
      textParts.append(loc("multiAward/type/modification") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locMods, ", ")))
    }

    if (this.countries) {
      let locCountries = u.map(this.countries, @(country) loc("unlockTag/" + country))
      textParts.append(loc("trophy/unlockables_names/country") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locCountries, ", ")))
    }
    if (this.unitTypes) {
      let processedUnitTypes = processUnitTypeArray(this.unitTypes)
      let locUnitTypes = u.map(processedUnitTypes, @(unitType) loc($"mainmenu/type_{unitType}"))
      textParts.append(loc("mainmenu/btnUnits") + loc("ui/colon")
          + colorize("activeTextColor", ::g_string.implode(locUnitTypes, ", ")))
    }

    let rankText = this.getRankText()
    if (rankText.len())
      textParts.append(loc("sm_rank") + loc("ui/colon") + colorize("activeTextColor", rankText))

    let outro = this.getDescriptionOutroArray()
    if (outro)
      textParts.extend(outro)

    return ::g_string.implode (textParts, "\n")
  }

  function getRankText() {
    if (this.rankRange)
      return ::get_roman_numeral(this.rankRange.x) +
        ((this.rankRange.x != this.rankRange.y) ? "-" + ::get_roman_numeral(this.rankRange.y) : "")
    return ""
  }

  function getIcon(_addItemName = true) {
    local res = ::LayersIcon.genDataFromLayer(this.getIconBgLayer())
    res += ::LayersIcon.genDataFromLayer(this.getIconMainLayer())
    res += ::LayersIcon.genDataFromLayer(this.getIconRankLayer())
    return res
  }

  getIconBgLayer = @() ::LayersIcon.findLayerCfg("mod_upgrade_bg")
  getIconMainLayer = @() null

  getIconRankLayer = function() {
    if (!this.rankRange)
      return null

    let res = ::LayersIcon.findLayerCfg("mod_upgrade_rank")
    if (res)
      res.img = $"#ui/gameuiskin#item_rank_{clamp(this.rankRange.y, 1, 6)}"
    return res
  }
}

return ModificationBase