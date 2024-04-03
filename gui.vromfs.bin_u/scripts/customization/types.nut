//-file:plus-string
from "%scripts/dagui_natives.nut" import player_have_attachable, get_decal_cost_wp, get_skin_cost_wp, player_have_skin, player_have_decal, get_num_attachables_slots, get_skin_cost_gold, get_attachable_cost_gold, save_attachables, get_max_num_attachables_slots, is_decal_allowed, has_entitlement, get_decal_cost_gold, get_attachable_cost_wp
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock = require("DataBlock")
let { floor } = require("math")
let { format } = require("string")
let { get_last_skin, get_decal_in_slot, set_current_decal_slot, set_decal_in_slot,
  enter_decal_mode, add_attachable, remove_attachable, select_attachable_slot,
  exit_attachables_mode, get_attachable_name, get_attachable_group, focus_on_current_decal,
  get_num_decal_slots, get_max_num_decal_slots, exit_decal_mode, save_decals,
  enter_ship_flags_mode, exit_ship_flags_mode, get_default_ship_flag,
  apply_ship_flag, get_ship_flag_in_slot, get_avail_ship_flags_blk
} = require("unitCustomization")
let enums = require("%sqStdLibs/helpers/enums.nut")
let guidParser = require("%scripts/guidParser.nut")
let time = require("%scripts/time.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let memoizeByEvents = require("%scripts/utils/memoizeByEvents.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { updateDownloadableSkins } = require("%scripts/customization/downloadableDecorators.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getPlaneBySkinId, getSkinNameBySkinId, isDefaultSkin } = require("%scripts/customization/skinUtils.nut")
let { get_decals_blk, get_skins_blk, get_attachable_blk } = require("blkGetters")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let getShipFlags = require("%scripts/customization/shipFlags.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

function memoizeByProfile(func, hashFunc = null) {
  // When player buys any decarator, profile always updates.
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
    categoryPathPrefix = ""
    groupPathPrefix = ""
    removeDecoratorLocId = ""
    emptySlotLocId = ""
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_decal"
    prizeTypeIcon = "#ui/gameuiskin#item_type_unlock.svg"
    defaultStyle = ""

    getAvailableSlots = function(_unit) { return 0 }
    getMaxSlots = function() { return 1 }

    getImage = function(_decorator) { return "" }
    getRatio = function(_decorator) { return 1 }
    getImageSize = function(_decorator) { return "0, 0" }

    getSmallIcon = @(decorator) decorator ? this.prizeTypeIcon : ""

    getLocName = function(decoratorName, _addUnitName = false) { return loc(decoratorName) }
    getLocDesc = function(decoratorName) { return loc(decoratorName + "/desc", "") }
    hasLocations = @(_decoratorName) false
    getLocParamsDesc = @(_decorator) ""

    function getTypeDesc(decorator) {
      local text = loc($"trophy/unlockables_names/{this.resourceType}")
      if (decorator.category != "" && this.categoryPathPrefix != "")
        text += loc("ui/comma") + loc(this.categoryPathPrefix + decorator.category)
      if (decorator.group != "" && this.groupPathPrefix != "")
        text += loc("ui/comma") + loc(this.groupPathPrefix + decorator.group)
      return text
    }

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
      if (block?.ps_plus && !require("sony.user").hasPremium())
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

    getBlk = function() { return DataBlock() }
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

enums.addTypes(decoratorTypes, {
  UNKNOWN = {
  }

  FLAGS = {
    unlockedItemType = UNLOCKABLE_SHIP_FLAG
    resourceType = "ship_flag"
    listId = "flags_list"
    listHeaderLocId = "flags"
    currentOpenedCategoryLocalSafePath = "wnd/flagsCategory"
    categoryPathPrefix = "flags/category/"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_mission"
    getAvailableSlots = @(_unit) 1
    getMaxSlots = @() 1

    getImage = @(decorator) decorator ? $"@!{decorator.blk.texture}" : ""
    getRatio = @(decorator) decorator?.aspect_ratio ?? 0.8
    getImageSize = @(_decorator) "256@sf/@pf, 204@sf/@pf"
    getLocName = @(decoratorName, ...) loc(getDecorator(decoratorName, this)?.blk.nameLocId ?? "")
    getLocDesc = @(decoratorName) loc(getDecorator(decoratorName, this)?.blk.descLocId ?? "")
    getTypeDesc = @(_decorator) ""
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

    function getBlk() {
      let resBlk = DataBlock()
      let flagsBlk = get_avail_ship_flags_blk() ?? getShipFlags()
      if (flagsBlk != null)
        resBlk.setFrom(flagsBlk)
      return resBlk
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
    categoryPathPrefix = "decals/category/"
    groupPathPrefix = "decals/group/"
    removeDecoratorLocId = "mainmenu/requestDeleteDecal"
    emptySlotLocId = "mainmenu/decalFreeSlot"
    prizeTypeIcon = "#ui/gameuiskin#item_type_decal.svg"
    defaultStyle = "reward_decal"

    jobCallbacksStack = {}

    getAvailableSlots = function(unit) { return get_num_decal_slots(unit.name) }
    getMaxSlots = function() { return get_max_num_decal_slots() }

    getImage = function(decorator) {
      return decorator
        ? ("@!" + decorator.tex + "*")
        : ""
    }

    getRatio = function(decorator) { return decorator?.aspect_ratio ?? 1 }
    getImageSize = function(decorator) { return format("256@sf/@pf, %d@sf/@pf", floor(256.0 / this.getRatio(decorator) + 0.5)) }

    getLocName = function(decoratorName, ...) { return loc("decals/" + decoratorName) }
    getLocDesc = function(decoratorName) { return loc($"decals/{decoratorName}/desc", "") }

    getCost = function(decorator) {
      return Cost(max(0, get_decal_cost_wp(decorator.id)),
                    max(0, get_decal_cost_gold(decorator.id)))
    }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false) {
      return get_decal_in_slot(unitName, skinId, slotIdx, checkPremium) //slow function
    }

    isAllowed = function(decoratorName) { return is_decal_allowed(decoratorName, "") }
    isAvailable = @(unit, checkUnitUsable = true) !!unit && hasFeature("DecalsUse")
      && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(player_have_decal)

    getBlk = function() {
      let decalsBlk = DataBlock()
      get_decals_blk(decalsBlk)
      return decalsBlk
    }

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
          this.jobCallbacksStack[res.taskId] <- callback
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
    categoryPathPrefix = "attachables/category/"
    groupPathPrefix = "attachables/group/"
    removeDecoratorLocId = "mainmenu/requestDeleteDecorator"
    emptySlotLocId = "mainmenu/attachableFreeSlot"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_attachable"
    prizeTypeIcon = "#ui/gameuiskin#item_type_attachable.svg"
    defaultStyle = "reward_attachable"

    getAvailableSlots = function(unit) { return get_num_attachables_slots(unit.name) }
    getMaxSlots = function() { return get_max_num_attachables_slots() }

    getImage = @(decorator) decorator
        ? (decorator?.blk.image ?? $"#ui/images/attachables/{decorator.id}")
        : ""
    getImageSize = function(...) { return "128@sf/@pf, 128@sf/@pf" }

    getLocName = function(decoratorName, ...) { return loc("attachables/" + decoratorName) }
    getLocDesc = function(decoratorName) { return loc($"attachables/{decoratorName}/desc", "") }
    getLocParamsDesc = function(decorator) {
      let paramPathPrefix = "attachables/param/"
      let angle = decorator.blk?.maxSurfaceAngle
      if (!angle)
        return ""

      return loc(paramPathPrefix + "maxSurfaceAngle", { value = angle })
    }

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

    getBlk = function() { return get_attachable_blk() }

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
    prizeTypeIcon = "#ui/gameuiskin#item_type_skin.svg"
    defaultStyle = "reward_skin"

    getImage = function(decorator) {
      if (!decorator)
        return ""

      let item = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
      let itemIconName = (item?.getIconName() ?? "")
      if (itemIconName != "")
        return itemIconName

      let mask = skinLocations.getSkinLocationsMaskBySkinId(decorator.id, this)
      let iconType = skinLocations.getIconTypeByMask(mask)
      let suffix =  iconType == "forest" ? "" : $"_{iconType}"
      return $"#ui/gameuiskin/item_skin{suffix}"
    }

    getSmallIcon = function(decorator) {
      if (!decorator)
        return ""
      return $"#ui/gameuiskin#icon_skin_{skinLocations.getIconTypeByMask(skinLocations.getSkinLocationsMaskBySkinId(decorator.id, this))}.svg"

    }

    getLocName = function(decoratorName, addUnitName = false) {
      if (guidParser.isGuid(decoratorName))
        return loc(decoratorName, loc("default_live_skin_loc"))

      local name = ""

      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      if (unit) {
        let skinNameId = getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.nameLocId ?? "") != "")
          name = loc(skinBlock.nameLocId)
      }

      if (name == "") {
        if (isDefaultSkin(decoratorName))
          decoratorName = loc(unitName + "/default", loc("default_skin_loc"))

        name = loc(decoratorName)
      }

      if (addUnitName && !u.isEmpty(unitName))
        name += loc("ui/parentheses/space", { text = getUnitName(unit) })

      return name
    }

    getLocDesc = function(decoratorName) {
      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      if (unit) {
        let skinNameId = getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.descLocId ?? "") != "")
          return loc(skinBlock.descLocId)
      }

      let defaultLocId = guidParser.isGuid(decoratorName) ? "default_live_skin_loc/desc" : "default_skin_loc/desc"
      return loc(decoratorName + "/desc", loc(defaultLocId))
    }

    hasLocations = function(decoratorName) {
      let unitName = getPlaneBySkinId(decoratorName)
      let unit = getAircraftByName(unitName)
      return unit?.isTank() ?? false
    }

    function getTypeDesc(decorator) {
      let unit = getAircraftByName(getPlaneBySkinId(decorator.id))
      if (!unit)
        return loc("trophy/unlockables_names/skin")
      return loc("reward/skin_for") + " " +
        getUnitName(unit) + loc("ui/comma") + loc(getUnitCountry(unit))
    }

    getCost = function(decorator) {
      let unitName = getPlaneBySkinId(decorator.id)
      return Cost(max(0, get_skin_cost_wp(unitName, decorator.id)),
                    max(0, get_skin_cost_gold(unitName, decorator.id)))
    }

    getFreeSlotIdx = @(...) 0
    isAvailable = @(unit, checkUnitUsable = true) !!unit && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(function isPlayerHaveDecorator(decoratorName) {
      if (decoratorName == "")
        return false
      if (isDefaultSkin(decoratorName))
        return true

      return player_have_skin(getPlaneBySkinId(decoratorName),
                                getSkinNameBySkinId(decoratorName))
    })

    getBlk = function() { return get_skins_blk() }

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

      cache[id] <- ::Decorator(this.getBlk()?[id] ?? id, this)
      return cache[id]
    }

    canPreviewLiveDecorator = @() hasFeature("EnableLiveSkins")

    updateDownloadableDecoratorsInfo = function(decorator) {
      let unitName = getPlaneBySkinId(decorator.id)
      let unit = getAircraftByName(unitName)
      if (!unit)
        return

      updateDownloadableSkins(unitName, this)
    }
  }
}, null, "name")

function getTypeByUnlockedItemType(unlockedItemType) {
  return enums.getCachedType("unlockedItemType", unlockedItemType, decoratorTypes.cache.byUnlockedItemType, decoratorTypes, decoratorTypes.UNKNOWN)
}

function getTypeByResourceType(resourceType) {
  return enums.getCachedType("resourceType", resourceType, decoratorTypes.cache.byResourceType, decoratorTypes, decoratorTypes.UNKNOWN)
}

::g_decorator_type <- decoratorTypes
::g_decorator_type.getTypeByResourceType <- getTypeByResourceType


return {
  decoratorTypes
  getTypeByUnlockedItemType
  getTypeByResourceType
}