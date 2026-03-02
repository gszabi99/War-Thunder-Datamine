from "%scripts/dagui_natives.nut" import has_entitlement, player_have_attachable, get_decal_cost_wp, player_have_skin, player_have_decal, get_num_attachables_slots, get_attachable_cost_gold, save_attachables, get_max_num_attachables_slots, is_decal_allowed, get_decal_cost_gold, get_attachable_cost_wp
from "%scripts/dagui_library.nut" import *
from "%sqDagui/daguiNativeApi.nut" import *

let time = require("%scripts/time.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { hasPremium } = require("sony.user")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { enumsAddTypes, getCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { Cost } = require("%scripts/money.nut")
let { get_last_skin, get_decal_in_slot, set_current_decal_slot, set_decal_in_slot,
  enter_decal_mode, add_attachable, remove_attachable, select_attachable_slot,
  exit_attachables_mode, get_attachable_name, get_attachable_group, focus_on_current_decal,
  get_num_decal_slots, get_max_num_decal_slots, exit_decal_mode, save_decals,
  enter_ship_flags_mode, exit_ship_flags_mode, get_default_ship_flag,
  apply_ship_flag, get_ship_flag_in_slot
} = require("unitCustomization")
let guidParser = require("%scripts/guidParser.nut")
let memoizeByEvents = require("%scripts/utils/memoizeByEvents.nut")
let { getPlaneBySkinId, getSkinNameBySkinId, isDefaultSkin, getSkinCost } = require("%scripts/customization/skinUtils.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { debug_dump_stack } = require("dagor.debug")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getDecorTypeBlk } = require("%scripts/customization/decoratorTypeUtils.nut")

function memoizeByProfile(func, hashFunc = null) {
  
  return memoizeByEvents(func, hashFunc, [ "ProfileUpdated" ])
}

let decoratorTypes = {
  types = []
  cache = {
    byUnlockedItemType = {}
    byResourceType = {}
  }

  template = {
    unlockedItemType = -1
    resourceType = ""
    defaultLimitUsage = -1
    listId = ""
    listHeaderLocId = ""
    currentOpenedCategoryLocalSafePath = "wnd/unknownCategory"
    removeDecoratorLocId = ""
    emptySlotLocId = ""
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_decal"
    defaultStyle = ""

    getAvailableSlots = function(_unit) { return 0 }
    getMaxSlots = function() { return 1 }

    hasLocations = @(_decoratorName) false

    getCost = function(_decorator) { return Cost() }
    getDecoratorNameInSlot = function(_slotIdx, _unitName, _skinId, _checkPremium = false) { return "" }
    getDecoratorGroupInSlot = function(_slotIdx, _unitName, _skinId, _checkPremium = false) { return "" }

    hasFreeSlots = @(unit, skinId = null, checkPremium = false) this.getFreeSlotIdx(unit, skinId, checkPremium) != -1
    getFreeSlotIdx = function(unit, skinId = null, checkPremium = false) {
      skinId = skinId || get_last_skin(unit.name)
      let slotsCount = checkPremium ? this.getMaxSlots() : this.getAvailableSlots(unit)
      for (local i = 0; i < slotsCount; i++)
        if (this.getDecoratorNameInSlot(i, unit.name, skinId, checkPremium) == "")
          return i
      return -1
    }

    isAvailable = @(_unit, _checkUnitUsable = true) false
    isAllowed = function(_decoratorName) { return true }
    isVisible = function(block, decorator) {
      if (!block)
        return true
      if (!this.isAllowed(block.getBlockName()))
        return false
      if (block?.psn && !isPlatformSony)
        return false
      if (block?.ps_plus && !hasPremium())
        return false
      if (block?.showByEntitlement && !has_entitlement(block.showByEntitlement))
        return false
      if ((block % "hideForLang").indexof(getLanguageName()) != null)
        return false
      foreach (feature in block % "reqFeature")
        if (!hasFeature(feature))
          return false
      foreach (feature in block % "hideFeature")
        if (hasFeature(feature))
          return false

      if (!this.isPlayerHaveDecorator(decorator.id)) {
        local isVisibleOnlyUnlocked = block?.hideUntilUnlocked || !decorator.canReceive()
        if (block?.beginDate || block?.endDate)
          isVisibleOnlyUnlocked = !time.isInTimerangeByUtcStrings(block?.beginDate, block?.endDate)
        if (isVisibleOnlyUnlocked)
          return false
      }
      return true
    }
    isPlayerHaveDecorator = function(_decoratorName) { return false }

    getSpecialDecorator = function(_id) { return null }
    getLiveDecorator = @(_id, _cache) null
    canPreviewLiveDecorator = @() true

    specifyEditableSlot = @(_slotIdx, _needFocus = true) null
    addDecorator = function(_decoratorName) {}
    exitEditMode = function(_apply, _save = false, _callback = function () {}) {}
    enterEditMode = function(_decoratorName) {}
    removeDecorator = @(_slotIdx, _save) false
    replaceDecorator = function(_slotIdx, _decoratorName) {}

    save = function(_unitName, _showProgressBox) {}

    canRotate = function() { return false }
    canResize = function() { return false }
    canMirror = function() { return false }
    canToggle = function() { return false }
    updateDownloadableDecoratorsInfo = function(_decorator) {}
  }
}

function addEnumDecoratorTypes(types) {
  enumsAddTypes(decoratorTypes, types, null, "name")
}

let decalsJobCallbacksStack = {}

addEnumDecoratorTypes({
  UNKNOWN = {}

  FLAGS = {
    unlockedItemType = UNLOCKABLE_SHIP_FLAG
    resourceType = "ship_flag"
    listId = "flags_list"
    listHeaderLocId = "flags"
    currentOpenedCategoryLocalSafePath = "wnd/flagsCategory"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_mission"
    getAvailableSlots = @(_unit) 1
    getMaxSlots = @() 1

    getCost = @(decorator) Cost().setGold(decorator?.unlockBlk.costGold ?? 0)
    getDecoratorNameInSlot = @(_slotIdx, unitName, skinId, _checkPremium = false) get_ship_flag_in_slot(unitName, skinId)

    isAllowed = @(decoratorName) is_decal_allowed(decoratorName, "")

    isAvailable = @(unit, checkUnitUsable = true) !!unit && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = @(id) isUnlockOpened(id) || id == get_default_ship_flag()
    isVisible = function(block, _decorator) {
      if ("unlockId" not in block)
        return false
      let unlock = getUnlockById(block.unlockId)
      if(unlock?.hideUntilUnlocked == true && !isUnlockOpened(block.unlockId))
        return false
      return true
    }

    enterEditMode = function(flagName) {
      let enterResult = enter_ship_flags_mode()
      apply_ship_flag(flagName, false)
      return enterResult
    }

    exitEditMode = function(apply, save = false, callback = @() null) {
      let res = exit_ship_flags_mode(apply, save)
      if (res)
        callback()
      return res
    }
  }

  DECALS = {
    unlockedItemType = UNLOCKABLE_DECAL
    resourceType = "decal"
    listId = "slots_list"
    listHeaderLocId = "decals"
    currentOpenedCategoryLocalSafePath = "wnd/decalsCategory"
    removeDecoratorLocId = "mainmenu/requestDeleteDecal"
    emptySlotLocId = "mainmenu/decalFreeSlot"
    defaultStyle = "reward_decal"

    getAvailableSlots = function(unit) { return get_num_decal_slots(unit.name) }
    getMaxSlots = function() { return get_max_num_decal_slots() }

    getCost = function(decorator) {
      return Cost(max(0, get_decal_cost_wp(decorator.id)),
                    max(0, get_decal_cost_gold(decorator.id)))
    }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false) {
      return get_decal_in_slot(unitName, skinId, slotIdx, checkPremium) 
    }

    isAllowed = function(decoratorName) { return is_decal_allowed(decoratorName, "") }
    isAvailable = @(unit, checkUnitUsable = true) !!unit && hasFeature("DecalsUse")
      && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(player_have_decal)

    specifyEditableSlot = function(slotIdx, needFocus = true) {
      set_current_decal_slot(slotIdx)
      if (needFocus)
        focus_on_current_decal()
    }
    addDecorator = function(decoratorName) { return set_decal_in_slot(decoratorName) }
    removeDecorator = function(slotIdx, save) {
      this.specifyEditableSlot(slotIdx, false)
      this.enterEditMode("")
      return this.exitEditMode(true, save)
    }

    replaceDecorator = function(slotIdx, decoratorName) {
      this.specifyEditableSlot(slotIdx)
      this.addDecorator(decoratorName)
    }
    enterEditMode = function(decoratorName) { return enter_decal_mode(decoratorName) }
    exitEditMode = function(apply, save = false, callback = function () {}) {
      let res = exit_decal_mode(apply, save)
      if (res.success) {
        if (res.taskId != -1)
          decalsJobCallbacksStack[res.taskId] <- callback
        else
          callback()
      }
      return res.success
    }

    save = function(unitName, showProgressBox) {
      if (!hasFeature("DecalsUse"))
        return

      let taskId = save_decals(unitName)
      let taskOptions = { showProgressBox = showProgressBox }
      addTask(taskId, taskOptions)
    }

    canRotate = @() true
    canResize = @() true
    canMirror = @() true
    canToggle = @() true

    canPreviewLiveDecorator = @() hasFeature("EnableLiveDecals")
  }

  ATTACHABLES = {
    unlockedItemType = UNLOCKABLE_ATTACHABLE
    resourceType = "attachable"
    defaultLimitUsage = 1
    listId = "slots_attachable_list"
    listHeaderLocId = "decorators"
    currentOpenedCategoryLocalSafePath = "wnd/attachablesCategory"
    removeDecoratorLocId = "mainmenu/requestDeleteDecorator"
    emptySlotLocId = "mainmenu/attachableFreeSlot"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_attachable"
    defaultStyle = "reward_attachable"

    getAvailableSlots = function(unit) { return get_num_attachables_slots(unit.name) }
    getMaxSlots = function() { return get_max_num_attachables_slots() }

    getCost = function(decorator) {
      return Cost(max(0, get_attachable_cost_wp(decorator.id)),
                    max(0, get_attachable_cost_gold(decorator.id)))
    }
    getDecoratorNameInSlot = function(slotIdx, ...) { return get_attachable_name(slotIdx) }
    getDecoratorGroupInSlot = function(slotIdx, ...) { return get_attachable_group(slotIdx) }

    isAvailable = @(unit, checkUnitUsable = true) !!unit && hasFeature("AttachablesUse")
      && (unit.isTank() || unit.isShipOrBoat())
      && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(player_have_attachable)

    removeDecorator = function(slotIdx, save) {
      remove_attachable(slotIdx)
      this.exitEditMode(true, save)
    }

    specifyEditableSlot = @(slotIdx, _needFocus = true) select_attachable_slot(slotIdx)
    enterEditMode = function(decoratorName) { return add_attachable(decoratorName) }
    exitEditMode = function(apply, save, callback = function () {}) {
      let res = exit_attachables_mode(apply, save)
      if (res)
        callback()
      return res
    }

    save = function(unitName, showProgressBox) {
      if (!hasFeature("AttachablesUse"))
        return

      let taskId = save_attachables(unitName)
      let taskOptions = { showProgressBox = showProgressBox }
      addTask(taskId, taskOptions)
    }

    canRotate = @() true
  }

  SKINS = {
    unlockedItemType = UNLOCKABLE_SKIN
    resourceType = "skin"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_skin"
    defaultStyle = "reward_skin"

    hasLocations = function(decoratorName) {
      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      return unit?.isTank() ?? false
    }

    getCost = @(decorator) getSkinCost(decorator.id)

    getFreeSlotIdx = @(...) 0
    isAvailable = @(unit, checkUnitUsable = true) !!unit && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(function isPlayerHaveDecorator(decoratorName) {
      if (decoratorName == "")
        return false
      if (isDefaultSkin(decoratorName))
        return true

      let unitName = getPlaneBySkinId(decoratorName)
      if (unitName == "") {
        debug_dump_stack()
        logerr("isPlayerHaveDecorator for skin: missing unitName")
        return false
      }

      let skinName = getSkinNameBySkinId(decoratorName)
      if (skinName == "") {
        if (guidParser.isGuid(unitName))
          return player_have_skin(unitName, unitName)
        debug_dump_stack()
        logerr("isPlayerHaveDecorator for skin: missing skinName")
        return false
      }
      return player_have_skin(unitName, skinName)
    })

    getSpecialDecorator = function(id) {
      if (getSkinNameBySkinId(id) == "default")
        return ::Decorator(id, this)
      return null
    }

    getLiveDecorator = function(id, cache) {
      if (id in cache)
        return cache[id]

      let isLiveDownloaded = guidParser.isGuid(getSkinNameBySkinId(id))
      let isLiveItemContent = !isLiveDownloaded && guidParser.isGuid(id)
      if (!isLiveDownloaded && !isLiveItemContent)
        return null

      cache[id] <- ::Decorator(getDecorTypeBlk("SKINS")?[id] ?? id, this)
      return cache[id]
    }

    canPreviewLiveDecorator = @() hasFeature("EnableLiveSkins")

    updateDownloadableDecoratorsInfo = function(decorator) {
      let unitName = getPlaneBySkinId(decorator.id)
      let unit = getAircraftByName(unitName)
      if (!unit)
        return

      eventbus_send("updateDownloadableDecoratorsInfo", { unitName, skinType = this})
    }
  }
})

function getTypeByUnlockedItemType(unlockedItemType) {
  return getCachedType("unlockedItemType", unlockedItemType, decoratorTypes.cache.byUnlockedItemType, decoratorTypes, decoratorTypes.UNKNOWN)
}

function getTypeByResourceType(resourceType) {
  return getCachedType("resourceType", resourceType, decoratorTypes.cache.byResourceType, decoratorTypes, decoratorTypes.UNKNOWN)
}

function on_decal_job_complete(data) {
  let { taskID } = data
  let callback = decalsJobCallbacksStack?[taskID]
  if (callback) {
    callback()
    decalsJobCallbacksStack.$rawdelete(taskID)
  }

  broadcastEvent("DecalJobComplete")
}

eventbus_subscribe("on_decal_job_complete", on_decal_job_complete)

return {
  decoratorTypes
  getTypeByUnlockedItemType
  getTypeByResourceType
}