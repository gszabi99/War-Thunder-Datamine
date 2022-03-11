let BaseItemModClass = require("scripts/items/itemsClasses/itemModBase.nut")

::items_classes.UniversalSpare <- class extends BaseItemModClass
{
  static iType = itemType.UNIVERSAL_SPARE
  static defaultLocId = "universalSpare"
  static defaultIcon = "#ui/gameuiskin#item_uni_spare"
  static typeIcon = "#ui/gameuiskin#item_type_uni_spare"

  canBuy = true
  allowBigPicture = false

  numSpares = 1
  shouldAlwaysShowRank = true

  getConditionsBlk = @(configBlk) configBlk?.universalSpareParams

  function initConditions(conditionsBlk)
  {
    base.initConditions(conditionsBlk)
    numSpares = conditionsBlk?.numSpares ?? 1
  }

  function getDescriptionIntroArray()
  {
    let res = [::loc("items/universalSpare/description/uponActivation")]
    if (numSpares > 1)
      res.append(::loc("items/universalSpare/numSpares") + ::loc("ui/colon") + ::colorize("activeTextColor", numSpares))
    return res
  }

  getDescriptionOutroArray = @() [ ::colorize("fadedTextColor", ::loc("items/universalSpare/description")) ]

  function getName(colored = true)
  {
    return base.getName(colored) + " " + getRankText()
  }

  function canActivateOnUnit(unit)
  {
    if (countries && !::isInArray(unit.shopCountry, countries))
      return false
    if (unit.rank < rankRange.x || unit.rank > rankRange.y)
      return false
    if (unitTypes && !::isInArray(unit.unitType.lowerName, unitTypes))
      return false
    return true
  }

  function activateOnUnit(unit, count, extSuccessCb = null)
  {
    if (!canActivateOnUnit(unit)
      || !isInventoryItem || !uids.len()
      || count <= 0 || count > getAmount())
      return false

    let successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      ::broadcastEvent("UniversalSpareActivated")
    }

    let blk = ::DataBlock()
    blk.uid = uids[0]
    blk.unit = unit.name
    blk.useItemsCount = count
    let taskId = ::char_send_blk("cln_apply_spare_item", blk)
    return ::g_tasker.addTask(taskId, { showProgressBox = true }, successCb)
  }

  function getIcon(addItemName = true)
  {
    local res = ::LayersIcon.genDataFromLayer(_getBaseIconCfg())
    res += ::LayersIcon.genDataFromLayer(_getFlagLayer())
    res += ::LayersIcon.genDataFromLayer(_getuUnitTypesLayer())
    res += ::LayersIcon.getTextDataFromLayer(_getRankLayer())
    return res
  }

  function _getBaseIconCfg()
  {
    let layerId = "universal_spare_base"
    return ::LayersIcon.findLayerCfg(layerId)
  }

  function _getuUnitTypesLayer()
  {
    if (!unitTypes || unitTypes.len() != 1)
      return ::LayersIcon.findLayerCfg("universal_spare_all")
    return ::LayersIcon.findLayerCfg("universal_spare_" + unitTypes[0])
  }

  function _getRankLayer()
  {
    let textLayerStyle = "universal_spare_rank_text"
    let layerCfg = ::LayersIcon.findLayerCfg(textLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.text <- getRankText()
    return layerCfg
  }

  function _getFlagLayer()
  {
    if (!countries || countries.len() != 1)
      return null
    let flagLayerStyle = "universal_spare_flag"
    let layerCfg = ::LayersIcon.findLayerCfg(flagLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.img <- ::get_country_icon(countries[0])
    return layerCfg
  }
}
