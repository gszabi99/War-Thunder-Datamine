from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { enable_modifications, open_weapons_for_unit } = require("%scripts/weaponry/weaponryActions.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { addTask } = require("%scripts/tasker.nut")
let { getItemStatusTbl } = require("%scripts/weaponry/itemInfo.nut")
let { updateUnitAfterSwitchMod } = require("%scripts/unit/unitChecks.nut")
let { getModsListByType } = require("%scripts/unit/unitWeaponryInfo.nut")
let { getTooltipId } = require("%scripts/weaponry/weaponryVisual.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")


let modGroups = ["scope", "stock", "magazine", "underbarrel", "tactical", "grip", "muzzle"]


let class ModsSetupHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/customization/modsSetupWnd.blk"
  modGroupBlkName = "%gui/customization/modsSlot.blk"
  unit = null
  modifications = []
  modsListByType = {}
  groups = []
  selectedGroupIdx = -1

  activeColor = "#FFFFFFFF"
  lockColor = "#FF777777"

  function getEquippedByModGroup(modGroup) {
    if (modGroup == null)
      return null

    let { name } = this.unit
    let mods = this.modsListByType[modGroup]
    for (local i = 0; i < mods.len(); i++) {
      let mod = this.modifications[mods[i]]
      if (shopIsModificationEnabled(name, mod.name))
        return mod
    }

    return null
  }


  function updateUnitMods(unit, groupIdx = 0) {
    let isModVisible = unit.isHuman()
    this.scene.show(isModVisible)
    if (!isModVisible)
      return

    this.unit = unit
    this.modifications = unit.modifications ?? []
    let groupsByType = getModsListByType(this.modifications)
    this.modsListByType = groupsByType
    this.groups = modGroups.filter(@(v) v in groupsByType)
    let grCount = this.groups.len()
    if (grCount == 0) {
      this.scene.show(false)
      return
    }

    let container = this.scene.findObject("modifications_groups")
    let addCount = grCount - container.childrenCount()
    if (addCount > 0)
      this.guiScene.createMultiElementsByObject(container, this.modGroupBlkName,
        "imgButton", addCount, this)

    for (local i = 0; i < container.childrenCount(); i++) {
      let buttonObj = container.getChild(i)
      buttonObj.idx = $"{i}"
      let isSlotVisible = i < grCount
      buttonObj.show(isSlotVisible)
      if (!isSlotVisible)
        continue

      buttonObj.modGroup = this.groups[i]
      let equipped = this.getEquippedByModGroup(this.groups?[i])
      let imageObj = buttonObj.findObject("mod_img")
      imageObj["background-image"] = equipped == null
        ? $"!#ui/gameuiskin#mod_group_{this.groups[i]}.svg"
        : equipped.image
      buttonObj.findObject("empty_txt").show(equipped == null)
    }

    if (grCount > 0) {
      this.selectedGroupIdx = groupIdx
      this.updateModsSlots()
      container.setValue(this.selectedGroupIdx)
    }
  }

  function updateModsSlots() {
    let modGroup = this.groups?[this.selectedGroupIdx]
    if (modGroup == null)
      return

    let container = this.scene.findObject("modifications_slots")
    let mods = this.modsListByType[modGroup]
    let count = mods.len() + 1 - container.childrenCount()
    if (count > 0)
      this.guiScene.createMultiElementsByObject(container, this.modGroupBlkName, "imgButton", count, this)

    let isConsole = showConsoleButtons.get()
    let removeButtonObj = container.getChild(0)
    removeButtonObj.enable(false)
    removeButtonObj.findObject("mod_img")["background-color"] = this.lockColor
    removeButtonObj.tooltip = loc("msgbox/btn_remove")
    for (local i = 1; i < container.childrenCount(); i++) {
      let buttonObj = container.getChild(i)
      let modIdx = i - 1
      buttonObj.show(modIdx < mods.len())
      if (modIdx >= mods.len())
        continue

      let mod = this.modifications[mods[modIdx]]
      let { name, image } = mod
      let { amount } = getItemStatusTbl(this.unit, mod)
      let hasEuipped = shopIsModificationEnabled(this.unit.name, name)
      let hasLocked = amount <= 0

      buttonObj.idx = $"{modIdx}"
      buttonObj.modIdx = $"{mods[modIdx]}"
      if (hasEuipped) {
        removeButtonObj.idx = $"{modIdx}"
        removeButtonObj.modIdx = $"{mods[modIdx]}"
        removeButtonObj.enable(true)
        removeButtonObj.findObject("mod_img")["background-color"] = this.activeColor
      }

      let imageObj = buttonObj.findObject("mod_img")
      imageObj["background-image"] = image
      imageObj["background-color"] = amount == 0 ? this.lockColor : this.activeColor

      let statusImg = buttonObj.findObject("status_sign")
      statusImg["background-image"] = hasLocked ? "#ui/gameuiskin#locked.svg" : "#ui/gameuiskin#check.svg"
      statusImg.show(hasEuipped || hasLocked)

      let tooltipId = isConsole ? "" : getTooltipId(this.unit.name, mod, { isPurchaseInfoHidden = true })
      let delayedTooltipId = isConsole ? getTooltipId(this.unit.name, mod, { isPurchaseInfoHidden = true }) : ""
      buttonObj.findObject("mod_tooltip").tooltipId = tooltipId
      buttonObj.tooltipId = delayedTooltipId
    }

    this.scene.findObject("mod_group_txt").setValue(loc($"modGroup/{modGroup}"))
  }

  function onModSlotClick(obj) {
    let { modGroup, modIdx, idx } = obj
    if (modGroup != "") {
      this.scene.findObject("modifications_groups").setValue(idx.tointeger())
      this.selectedGroupIdx = this.groups.findindex(@(v) v == modGroup) ?? -1
      this.updateModsSlots()
    }
    else if (modIdx != "") {
      let selectedUnit = this.unit
      let mod = this.modifications[modIdx.tointeger()]
      let { amount } = getItemStatusTbl(selectedUnit, mod)
      if (amount <= 0) {
        this.msgBox("locked_mod_msg", loc("msgbox/notAvailbleMod"), [
          [ "ok", function() {
            open_weapons_for_unit(selectedUnit, {
              needHideSlotbar = true
              curEdiff = this.getCurrentEdiff?() ?? getCurrentGameModeEdiff()
            })
          }],
          [ "cancel" ]
        ], "ok")
        return
      }
      let hasEuipped = shopIsModificationEnabled(this.unit.name, mod.name)
      this.doSwitchMod(this.unit, mod, hasEuipped)
    }
  }

  function doSwitchMod(unit, mod, hasEuipped) {
    showObjById("mod_wait_screen", true)

    let taskSuccessCallback = function() {
      updateUnitAfterSwitchMod(unit, mod.name)
      broadcastEvent("ModificationChanged")
      showObjById("mod_wait_screen", false)
    }

    let taskErrorCallback = @() showObjById("mod_wait_screen", false)
    let taskId = enable_modifications(this.unit.name, [mod.name], !hasEuipped)
    addTask(taskId, {}, taskSuccessCallback, taskErrorCallback)
  }

  function onEventModificationChanged(_p) {
    this.updateUnitMods(this.unit, this.selectedGroupIdx)
  }

  function onEventModificationPurchased(_p)  {
    this.updateUnitMods(this.unit, this.selectedGroupIdx)
  }
}

gui_handlers.ModsSetupHandler <- ModsSetupHandler

return function(scene) {
  if (!scene?.isValid())
    return null

  return handlersManager.loadHandler(ModsSetupHandler, { scene })
}
