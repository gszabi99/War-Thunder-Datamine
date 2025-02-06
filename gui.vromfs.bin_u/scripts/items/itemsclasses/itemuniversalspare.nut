from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getUsedItemCount } = require("%scripts/items/usedItemsInBattle.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")

let UniversalSpare = class (BaseItemModClass) {
  static iType = itemType.UNIVERSAL_SPARE
  static name = "UniversalSpare"
  static defaultLocId = "universalSpare"
  static defaultIcon = "#ui/gameuiskin#item_uni_spare"
  static typeIcon = "#ui/gameuiskin#item_type_uni_spare.svg"

  canBuy = true
  allowBigPicture = false

  numSpares = 1
  shouldAlwaysShowRank = true
  isCoveringAllRanks = false

  getConditionsBlk = @(configBlk) configBlk?.universalSpareParams

  function initConditions(conditionsBlk) {
    base.initConditions(conditionsBlk)
    this.numSpares = conditionsBlk?.numSpares ?? 1
    this.isCoveringAllRanks = this.rankRange.x == 1 && this.rankRange.y == MAX_COUNTRY_RANK
  }

  function getDescriptionIntroArray() {
    let res = [loc("items/universalSpare/description/uponActivation")]
    if (this.numSpares > 1)
      res.append("".concat(loc("items/universalSpare/numSpares"), loc("ui/colon"), colorize("activeTextColor", this.numSpares)))
    return res
  }

  getDescriptionOutroArray = @() [ colorize("fadedTextColor", loc("items/universalSpare/description")) ]

  function getName(colored = true) {
    let name = base.getName(colored)
    let conditions = this._getConditionsText()
    return conditions != ""
      ? " ".concat(name, loc("ui/parentheses", {text = conditions}))
      : name
  }

  function canActivateOnUnit(unit) {
    if (this.countries && !isInArray(unit.shopCountry, this.countries))
      return false
    if (unit.rank < this.rankRange.x || unit.rank > this.rankRange.y)
      return false
    if (this.unitTypes && !isInArray(unit.unitType.lowerName, this.unitTypes))
      return false
    return true
  }

  function activateOnUnit(unit, count, extSuccessCb = null) {
    if (!this.canActivateOnUnit(unit)
      || !this.isInventoryItem || !this.uids.len()
      || count <= 0 || count > this.getAmount())
      return false

    let successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      broadcastEvent("UniversalSpareActivated", { unit })
    }

    let blk = DataBlock()
    blk.uid = this.uids[0]
    blk.unit = unit.name
    blk.useItemsCount = count
    let taskId = char_send_blk("cln_apply_spare_item", blk)
    return addTask(taskId, { showProgressBox = true }, successCb)
  }

  function getAmount() {
    return this.amount
      - ((this.uids?.len() ?? 0) > 0 ? getUsedItemCount(this.iType, this.uids[0]) : 0)
  }

  getIcon = @(_addItemName = true) "".concat(
    LayersIcon.genDataFromLayer(this._getBaseIconCfg()),
    LayersIcon.genDataFromLayer(this._getFlagLayer()),
    LayersIcon.genDataFromLayer(this._getuUnitTypesLayer()),
    LayersIcon.getTextDataFromLayer(this._getRankLayer()))

  function _getBaseIconCfg() {
    let layerId = "universal_spare_base"
    return LayersIcon.findLayerCfg(layerId)
  }

  function _getuUnitTypesLayer() {
    if (!this.unitTypes || this.unitTypes.len() != 1)
      return LayersIcon.findLayerCfg("universal_spare_all")
    return LayersIcon.findLayerCfg("".concat("universal_spare_", this.unitTypes[0]))
  }

  function _getRankLayer() {
    if (this.isCoveringAllRanks)
      return null
    let textLayerStyle = "universal_spare_rank_text"
    let layerCfg = LayersIcon.findLayerCfg(textLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.text <- this.getRankText()
    return layerCfg
  }

  function _getFlagLayer() {
    if (!this.countries || this.countries.len() != 1)
      return null
    let flagLayerStyle = "universal_spare_flag"
    let layerCfg = LayersIcon.findLayerCfg(flagLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.img <- getCountryIcon(this.countries[0])
    return layerCfg
  }

  function _getConditionsText() {
    let rankCond = !this.isCoveringAllRanks
      ?  " ".concat(this.getRankText(), loc("measureUnits/rank")) : ""
    let countryCond = this.countries?.len() == 1 ? loc(this.countries[0]) : ""
    local unitTypeCond = ""
    if (this.unitTypes?.len() == 1) {
      let [uType] = processUnitTypeArray(this.unitTypes)
      unitTypeCond = loc($"mainmenu/type_{uType}")
    }

    return ", ".join([unitTypeCond, countryCond, rankCond], true)
  }
}
return {UniversalSpare}