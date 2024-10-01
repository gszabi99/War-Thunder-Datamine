from "%scripts/dagui_natives.nut" import char_send_blk, get_modification_level
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { get_modifications_blk } = require("blkGetters")
let { addTask } = require("%scripts/tasker.nut")

let ModUpgrade = class (BaseItemModClass) {
  static iType = itemType.MOD_UPGRADE
  static name = "ModUpgrade"
  static defaultLocId = "modUpgrade"
  static defaultIcon = "#ui/gameuiskin#overdrive_upgrade_bg"
  static typeIcon = "#ui/gameuiskin#item_type_upgrade.svg"

  canBuy = true
  allowBigPicture = false

  level = 0

  getConditionsBlk = @(configBlk) configBlk?.modUpgradeParams

  getActivateInfo  = @() loc("item/modUpgrade/activateInModifications")

  function initConditions(conditionsBlk) {
    base.initConditions(conditionsBlk)
    this.level = conditionsBlk?.level ?? 0
  }

  function getDescriptionIntroArray() {
    if (this.level)
      return [ "".concat(loc("multiplayer/level"), loc("ui/colon"), colorize("activeTextColor", this.level)) ]
    return null
  }

  getIconMainLayer = @() LayersIcon.findLayerCfg("mod_upgrade")

  function canActivateOnMod(unit, mod) {
    if (this.modsList && !isInArray(mod.name, this.modsList)
      && !isInArray(get_modifications_blk()?.modifications?[mod.name]?.modUpgradeType, this.modsList))
      return false
    if (this.countries && !isInArray(unit.shopCountry, this.countries))
      return false
    if (this.rankRange && (unit.rank < this.rankRange.x || unit.rank > this.rankRange.y))
      return false
    if (this.unitTypes && !isInArray(unit.unitType.lowerName, this.unitTypes))
      return false
    if (this.level - 1 != get_modification_level(unit.name, mod.name))
      return false
    return true
  }

  function activateOnMod(unit, mod, extSuccessCb = null) {
    let uid = this.uids?[0]
    if (uid == null)
      return false

    let successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      broadcastEvent("ModUpgraded", { unit = unit, mod = mod })
    }

    let blk = DataBlock()
    blk.uid = uid
    blk.unit = unit.name
    blk.mod = mod.name

    addTask(
      char_send_blk("cln_upgrade_modification_item", blk),
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      successCb
    )
  }
}
return {ModUpgrade}