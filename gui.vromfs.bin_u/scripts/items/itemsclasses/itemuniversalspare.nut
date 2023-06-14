//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")


let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")

::items_classes.UniversalSpare <- class extends BaseItemModClass {
  static iType = itemType.UNIVERSAL_SPARE
  static defaultLocId = "universalSpare"
  static defaultIcon = "#ui/gameuiskin#item_uni_spare"
  static typeIcon = "#ui/gameuiskin#item_type_uni_spare.svg"

  canBuy = true
  allowBigPicture = false

  numSpares = 1
  shouldAlwaysShowRank = true

  getConditionsBlk = @(configBlk) configBlk?.universalSpareParams

  function initConditions(conditionsBlk) {
    base.initConditions(conditionsBlk)
    this.numSpares = conditionsBlk?.numSpares ?? 1
  }

  function getDescriptionIntroArray() {
    let res = [loc("items/universalSpare/description/uponActivation")]
    if (this.numSpares > 1)
      res.append(loc("items/universalSpare/numSpares") + loc("ui/colon") + colorize("activeTextColor", this.numSpares))
    return res
  }

  getDescriptionOutroArray = @() [ colorize("fadedTextColor", loc("items/universalSpare/description")) ]

  function getName(colored = true) {
    return base.getName(colored) + " " + this.getRankText()
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
      broadcastEvent("UniversalSpareActivated")
    }

    let blk = DataBlock()
    blk.uid = this.uids[0]
    blk.unit = unit.name
    blk.useItemsCount = count
    let taskId = ::char_send_blk("cln_apply_spare_item", blk)
    return ::g_tasker.addTask(taskId, { showProgressBox = true }, successCb)
  }

  function getIcon(_addItemName = true) {
    local res = LayersIcon.genDataFromLayer(this._getBaseIconCfg())
    res += LayersIcon.genDataFromLayer(this._getFlagLayer())
    res += LayersIcon.genDataFromLayer(this._getuUnitTypesLayer())
    res += LayersIcon.getTextDataFromLayer(this._getRankLayer())
    return res
  }

  function _getBaseIconCfg() {
    let layerId = "universal_spare_base"
    return LayersIcon.findLayerCfg(layerId)
  }

  function _getuUnitTypesLayer() {
    if (!this.unitTypes || this.unitTypes.len() != 1)
      return LayersIcon.findLayerCfg("universal_spare_all")
    return LayersIcon.findLayerCfg("universal_spare_" + this.unitTypes[0])
  }

  function _getRankLayer() {
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
    layerCfg.img <- ::get_country_icon(this.countries[0])
    return layerCfg
  }
}
