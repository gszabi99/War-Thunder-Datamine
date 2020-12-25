local elemModelType = require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local { isModUpgradeable, hasActiveOverdrive } = require("scripts/weaponry/modificationInfo.nut")

elemModelType.addTypes({
  MOD_UPGRADE = {
    hasUpgradeItems = null

    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    onEventModUpgraded = @(p) notify([p.unit.name, p.mod.name])
    onEventOverdriveActivated = @(p) notify([])
    onEventInventoryUpdate = function(p)
    {
      hasUpgradeItems = null
      notify([])
    }

    needShowAvailableUpgrades = function()
    {
      if (hasUpgradeItems == null)
        hasUpgradeItems = ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE).len() > 0
      return hasUpgradeItems
    }
  }
})

elemViewType.addTypes({
  MOD_UPGRADE_ICON = {
    model = elemModelType.MOD_UPGRADE
    getBhvParamsString = @(params) bhvParamsToString(
      params.__merge({
        subscriptions = [params?.unit || "", params?.mod || ""]
      }))
    createMarkup = @(params, objId = null) ::format("modUpgradeImg { id:t='%s'; value:t='%s' } ",
      objId || "", ::g_string.stripTags(getBhvParamsString(params)))

    updateView = function(obj, params)
    {
      local unitName = params?.unit
      obj.show(!!unitName)
      if (!unitName)
        return

      local modName = params?.mod
      local upgradeIcon = null
      if (modName)
        if (::get_modification_level(unitName, modName))
          upgradeIcon = "#ui/gameuiskin#mark_upgrade.svg"
        else if (model.needShowAvailableUpgrades() && isModUpgradeable(modName))
          upgradeIcon = "#ui/gameuiskin#mark_can_upgrade.svg"
      local upgradeColor = upgradeIcon ? "#FFFFFFFF" : "#00000000"

      if (upgradeIcon)
        obj.set_prop_latent("background-image", upgradeIcon)
      obj.set_prop_latent("background-color", upgradeColor)
      obj.set_prop_latent("foreground-color",
        modName && hasActiveOverdrive(unitName, modName) ? "#FFFFFFFF" : "#00000000")
      obj.updateRendElem()
    }
  }
})

local makeConfig = @(unitName, modName) unitName && modName ? { unit = unitName, mod = modName } : {}
return {
  createMarkup = @(objId = null, unitName = null, modName = null)
    elemViewType.MOD_UPGRADE_ICON.createMarkup(makeConfig(unitName, modName), objId)
  setValueToObj = @(obj, unitName, modName)
    ::check_obj(obj) && obj.setValue(elemViewType.MOD_UPGRADE_ICON.getBhvParamsString(makeConfig(unitName, modName)))
}