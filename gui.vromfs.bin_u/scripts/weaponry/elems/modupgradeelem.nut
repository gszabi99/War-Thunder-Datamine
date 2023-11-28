from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { isModUpgradeable, hasActiveOverdrive } = require("%scripts/weaponry/modificationInfo.nut")
let { stripTags } = require("%sqstd/string.nut")

elemModelType.addTypes({
  MOD_UPGRADE = {
    hasUpgradeItems = null

    init = @() subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    onEventModUpgraded = @(p) this.notify([p.unit.name, p.mod.name])
    onEventOverdriveActivated = @(_p) this.notify([])
    onEventInventoryUpdate = function(_p) {
      this.hasUpgradeItems = null
      this.notify([])
    }

    needShowAvailableUpgrades = function() {
      if (this.hasUpgradeItems == null)
        this.hasUpgradeItems = ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE).len() > 0
      return this.hasUpgradeItems
    }
  }
})

elemViewType.addTypes({
  MOD_UPGRADE_ICON = {
    model = elemModelType.MOD_UPGRADE
    getBhvParamsString = @(params) this.bhvParamsToString(
      params.__merge({
        subscriptions = [params?.unit || "", params?.mod || ""]
      }))
    createMarkup = @(params, objId = null) format("modUpgradeImg { id:t='%s'; value:t='%s' } ",
      objId || "", stripTags(this.getBhvParamsString(params)))

    updateView = function(obj, params) {
      let unitName = params?.unit
      obj.show(!!unitName)
      if (!unitName)
        return

      let modName = params?.mod
      local upgradeIcon = null
      if (modName)
        if (::get_modification_level(unitName, modName))
          upgradeIcon = "#ui/gameuiskin#mark_upgrade.svg"
        else if (this.model.needShowAvailableUpgrades() && isModUpgradeable(modName))
          upgradeIcon = "#ui/gameuiskin#mark_can_upgrade.svg"
      let upgradeColor = upgradeIcon ? "#FFFFFFFF" : "#00000000"

      if (upgradeIcon)
        obj.set_prop_latent("background-image", upgradeIcon)
      obj.set_prop_latent("background-color", upgradeColor)
      obj.set_prop_latent("foreground-color",
        modName && hasActiveOverdrive(unitName, modName) ? "#FFFFFFFF" : "#00000000")
      obj.updateRendElem()
    }
  }
})

let makeConfig = @(unitName, modName) unitName && modName ? { unit = unitName, mod = modName } : {}
return {
  createMarkup = @(objId = null, unitName = null, modName = null)
    elemViewType.MOD_UPGRADE_ICON.createMarkup(makeConfig(unitName, modName), objId)
  setValueToObj = @(obj, unitName, modName)
    checkObj(obj) && obj.setValue(elemViewType.MOD_UPGRADE_ICON.getBhvParamsString(makeConfig(unitName, modName)))
}