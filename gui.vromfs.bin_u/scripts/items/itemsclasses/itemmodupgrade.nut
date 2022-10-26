from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")

::items_classes.ModUpgrade <- class extends BaseItemModClass
{
  static iType = itemType.MOD_UPGRADE
  static defaultLocId = "modUpgrade"
  static defaultIcon = "#ui/gameuiskin#overdrive_upgrade_bg.png"
  static typeIcon = "#ui/gameuiskin#item_type_upgrade.svg"

  canBuy = true
  allowBigPicture = false

  level = 0

  getConditionsBlk = @(configBlk) configBlk?.modUpgradeParams

  getActivateInfo  = @() loc("item/modUpgrade/activateInModifications")

  function initConditions(conditionsBlk)
  {
    base.initConditions(conditionsBlk)
    this.level = conditionsBlk?.level ?? 0
  }

  function getDescriptionIntroArray()
  {
    if (this.level)
      return [ loc("multiplayer/level") + loc("ui/colon") + colorize("activeTextColor", this.level) ]
    return null
  }

  getIconMainLayer = @() ::LayersIcon.findLayerCfg("mod_upgrade")

  function canActivateOnMod(unit, mod)
  {
    if (this.modsList && !isInArray(mod.name, this.modsList)
      && !isInArray(::get_modifications_blk()?.modifications?[mod.name]?.modUpgradeType, this.modsList))
      return false
    if (this.countries && !isInArray(unit.shopCountry, this.countries))
      return false
    if (this.rankRange && (unit.rank < this.rankRange.x || unit.rank > this.rankRange.y))
      return false
    if (this.unitTypes && !isInArray(unit.unitType.lowerName, this.unitTypes))
      return false
    if (this.level - 1 != ::get_modification_level(unit.name, mod.name))
      return false
    return true
  }

  function activateOnMod(unit, mod, extSuccessCb = null)
  {
    let uid = this.uids?[0]
    if (uid == null)
      return false

    let successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      ::broadcastEvent("ModUpgraded", { unit = unit, mod = mod })
    }

    let blk = ::DataBlock()
    blk.uid = uid
    blk.unit = unit.name
    blk.mod = mod.name

    ::g_tasker.addTask(
      ::char_send_blk("cln_upgrade_modification_item", blk),
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      successCb
    )
  }
}