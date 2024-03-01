//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { Point2 } = require("dagor.math")


let ModificationBase = class (BaseItem) {
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
      let locMods = this.modsList.map(function(mod) {
          local res = loc($"modification/{mod}/short", "")
          if (!res.len())
            res = loc($"modification/{mod}")
          return res
        })
      textParts.append(loc("multiAward/type/modification") + loc("ui/colon")
          + colorize("activeTextColor", ", ".join(locMods, true)))
    }

    if (this.countries) {
      let locCountries = this.countries.map(@(country) loc("unlockTag/" + country))
      textParts.append(loc("trophy/unlockables_names/country") + loc("ui/colon")
          + colorize("activeTextColor", ", ".join(locCountries, true)))
    }
    if (this.unitTypes) {
      let processedUnitTypes = processUnitTypeArray(this.unitTypes)
      let locUnitTypes = processedUnitTypes.map(@(unitType) loc($"mainmenu/type_{unitType}"))
      textParts.append(loc("mainmenu/btnUnits") + loc("ui/colon")
          + colorize("activeTextColor", ", ".join(locUnitTypes, true)))
    }

    let rankText = this.getRankText()
    if (rankText.len())
      textParts.append(loc("sm_rank") + loc("ui/colon") + colorize("activeTextColor", rankText))

    let outro = this.getDescriptionOutroArray()
    if (outro)
      textParts.extend(outro)

    return "\n".join(textParts, true)
  }

  function getRankText() {
    if (!this.rankRange)
      return ""
    let minText = get_roman_numeral(this.rankRange.x)
    return this.rankRange.x == this.rankRange.y ? minText
      : $"{minText}-{get_roman_numeral(this.rankRange.y)}"
  }

  function getIcon(_addItemName = true) {
    local res = LayersIcon.genDataFromLayer(this.getIconBgLayer())
    res += LayersIcon.genDataFromLayer(this.getIconMainLayer())
    res += LayersIcon.genDataFromLayer(this.getIconRankLayer())
    return res
  }

  getIconBgLayer = @() LayersIcon.findLayerCfg("mod_upgrade_bg")
  getIconMainLayer = @() null

  getIconRankLayer = function() {
    if (!this.rankRange)
      return null

    let res = LayersIcon.findLayerCfg("mod_upgrade_rank")
    if (res)
      res.img = $"#ui/gameuiskin#item_rank_{clamp(this.rankRange.y, 1, 6)}"
    return res
  }
}

return ModificationBase