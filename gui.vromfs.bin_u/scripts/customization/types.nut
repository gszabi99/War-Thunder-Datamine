let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let guidParser = require("%scripts/guidParser.nut")
let time = require("%scripts/time.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let memoizeByEvents = require("%scripts/utils/memoizeByEvents.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { updateDownloadableSkins } = require("%scripts/customization/downloadableDecorators.nut")

let function memoizeByProfile(func, hashFunc = null) {
  // When player buys any decarator, profile always updates.
  return memoizeByEvents(func, hashFunc, [ "ProfileUpdated" ])
}

::g_decorator_type <- {
  types = []
  cache = {
    byListId = {}
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
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_decal.png"
    prizeTypeIcon = "#ui/gameuiskin#item_type_unlock.svg"
    defaultStyle = ""

    getAvailableSlots = function(unit) { return 0 }
    getMaxSlots = function() {return 1 }

    getImage = function(decorator) { return "" }
    getRatio = function(decorator) { return 1 }
    getImageSize = function(decorator) { return "0, 0" }

    getSmallIcon = @(decorator) decorator ? prizeTypeIcon : ""

    getLocName = function(decoratorName, addUnitName = false) { return ::loc(decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc(decoratorName + "/desc", "") }
    hasLocations = @(decoratorName) false
    getLocParamsDesc = @(decorator) ""

    function getTypeDesc(decorator)
    {
      local text = ::loc("trophy/unlockables_names/" + resourceType)
      if (decorator.category != "" && categoryPathPrefix != "")
        text += ::loc("ui/comma") + ::loc(categoryPathPrefix + decorator.category)
      if (decorator.group != "" && groupPathPrefix != "")
        text += ::loc("ui/comma") + ::loc(groupPathPrefix + decorator.group)
      return text
    }

    getCost = function(decoratorName) { return ::Cost() }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false) { return "" }
    getDecoratorGroupInSlot = function(slotIdx, unitName, skinId, checkPremium = false) { return "" }

    hasFreeSlots = @(unit, skinId = null, checkPremium = false) getFreeSlotIdx(unit, skinId, checkPremium) != -1
    getFreeSlotIdx = function(unit, skinId = null, checkPremium = false)
    {
      skinId = skinId || ::hangar_get_last_skin(unit.name)
      let slotsCount = checkPremium ? getMaxSlots() : getAvailableSlots(unit)
      for (local i = 0; i < slotsCount; i++)
        if (getDecoratorNameInSlot(i, unit.name, skinId, checkPremium) == "")
          return i
      return -1
    }

    isAvailable = @(unit, checkUnitUsable = true) false
    isAllowed = function(decoratorName) { return true }
    isVisible = function(block, decorator)
    {
      if (!block)
        return true
      if (!isAllowed(block.getBlockName()))
        return false
      if (block?.psn && !isPlatformSony)
        return false
      if (block?.ps_plus && !require("sony.user").hasPremium())
        return false
      if (block?.showByEntitlement && !::has_entitlement(block.showByEntitlement))
        return false
      if ((block % "hideForLang").indexof(::g_language.getLanguageName()) != null)
        return false
      foreach (feature in block % "reqFeature")
        if (!::has_feature(feature))
          return false

      if (!isPlayerHaveDecorator(decorator.id))
      {
        local isVisibleOnlyUnlocked = block?.hideUntilUnlocked || !decorator.canRecieve()
        if (block?.beginDate || block?.endDate)
          isVisibleOnlyUnlocked = !time.isInTimerangeByUtcStrings(block?.beginDate, block?.endDate)
        if (isVisibleOnlyUnlocked)
          return false
      }
      return true
    }
    isPlayerHaveDecorator = function(decoratorName) { return false }

    getBlk = function() { return ::DataBlock() }
    getSpecialDecorator = function(id) { return null }
    getLiveDecorator = @(id, cache) null
    canPreviewLiveDecorator = @() true

    specifyEditableSlot = @(slotIdx, needFocus = true) null
    addDecorator = function(decoratorName) {}
    exitEditMode = function(apply, save = false, callback = function (){}) {}
    enterEditMode = function(decoratorName) {}
    removeDecorator = @(slotIdx, save) false
    replaceDecorator = function(slotIdx, decoratorName) {}

    buyFunc = function(unitName, id) {}
    save = function(unitName, showProgressBox) {}

    canRotate = function() { return false }
    canResize = function() { return false }
    canMirror = function() { return false }
    canToggle = function() { return false }
    updateDownloadableDecoratorsInfo = function(decorator) {}
  }
}

enums.addTypesByGlobalName("g_decorator_type", {
  UNKNOWN = {
  }

  DECALS = {
    unlockedItemType = ::UNLOCKABLE_DECAL
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

    getAvailableSlots = function(unit) { return ::get_num_decal_slots(unit.name) }
    getMaxSlots = function() { return ::get_max_num_decal_slots() }

    getImage = function(decorator)
    {
      return decorator
        ? ("@!" + decorator.tex + "*")
        : ""
    }

    getRatio = function(decorator) { return decorator?.aspect_ratio ?? 1 }
    getImageSize = function(decorator) { return format("256@sf/@pf, %d@sf/@pf", ::floor(256.0 / getRatio(decorator) + 0.5)) }

    getLocName = function(decoratorName, ...) { return ::loc("decals/" + decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc("decals/" + decoratorName + "/desc", "") }

    getCost = function(decoratorName)
    {
      return ::Cost(max(0, ::get_decal_cost_wp(decoratorName)),
                    max(0, ::get_decal_cost_gold(decoratorName)))
    }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false)
    {
      return ::hangar_get_decal_in_slot(unitName, skinId, slotIdx, checkPremium) //slow function
    }

    isAllowed = function(decoratorName) { return ::is_decal_allowed(decoratorName, "") }
    isAvailable = @(unit, checkUnitUsable = true) !!unit && ::has_feature("DecalsUse")
      && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(::player_have_decal)

    getBlk = function() { return ::get_decals_blk() }

    specifyEditableSlot = function(slotIdx, needFocus = true)
    {
      ::hangar_set_current_decal_slot(slotIdx)
      if (needFocus)
        ::hangar_focus_on_current_decal()
    }
    addDecorator = function(decoratorName) { return ::hangar_set_decal_in_slot(decoratorName) }
    removeDecorator = function(slotIdx, save)
    {
      specifyEditableSlot(slotIdx, false)
      enterEditMode("")
      return exitEditMode(true, save)
    }

    replaceDecorator = function(slotIdx, decoratorName)
    {
      specifyEditableSlot(slotIdx)
      addDecorator(decoratorName)
    }
    enterEditMode = function(decoratorName) { return ::hangar_enter_decal_mode(decoratorName) }
    exitEditMode = function(apply, save = false, callback = function () {}) {
      let res = ::hangar_exit_decal_mode(apply, save)
      if (res.success)
      {
        if (res.taskId != -1)
          jobCallbacksStack[res.taskId] <- callback
        else
          callback()
      }
      return res.success
    }

    buyFunc = function(unitName, id, cost, afterSuccessFunc)
    {
      let blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "decal"
      blk["unitName"] = unitName
      blk["cost"] = cost.wp
      blk["costGold"] = cost.gold

      let taskId = ::char_send_blk("cln_buy_resource", blk)
      let taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    save = function(unitName, showProgressBox)
    {
      if (!::has_feature("DecalsUse"))
        return

      let taskId = ::save_decals(unitName)
      let taskOptions = { showProgressBox = showProgressBox }
      ::g_tasker.addTask(taskId, taskOptions)
    }

    canRotate = @() true
    canResize = @() true
    canMirror = @() true
    canToggle = @() true

    canPreviewLiveDecorator = @() ::has_feature("EnableLiveDecals")
  }

  ATTACHABLES = {
    unlockedItemType = ::UNLOCKABLE_ATTACHABLE
    resourceType = "attachable"
    defaultLimitUsage = 1
    listId = "slots_attachable_list"
    listHeaderLocId = "decorators"
    currentOpenedCategoryLocalSafePath = "wnd/attachablesCategory"
    categoryPathPrefix = "attachables/category/"
    groupPathPrefix = "attachables/group/"
    removeDecoratorLocId = "mainmenu/requestDeleteDecorator"
    emptySlotLocId = "mainmenu/attachableFreeSlot"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_attachable.png"
    prizeTypeIcon = "#ui/gameuiskin#item_type_attachable.svg"
    defaultStyle = "reward_attachable"

    getAvailableSlots = function(unit) { return ::get_num_attachables_slots(unit.name) }
    getMaxSlots = function() { return ::get_max_num_attachables_slots() }

    getImage = @(decorator) decorator
        ? (decorator?.blk.image ?? $"#ui/images/attachables/{decorator.id}.png")
        : ""
    getImageSize = function(...) { return "128@sf/@pf, 128@sf/@pf" }

    getLocName = function(decoratorName, ...) { return ::loc("attachables/" + decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc("attachables/" + decoratorName + "/desc", "") }
    getLocParamsDesc = function(decorator)
    {
      let paramPathPrefix = "attachables/param/"
      let angle = decorator.blk?.maxSurfaceAngle
      if (!angle)
        return ""

      return ::loc(paramPathPrefix + "maxSurfaceAngle", {value = angle})
    }

    getCost = function(decoratorName)
    {
      return ::Cost(max(0, ::get_attachable_cost_wp(decoratorName)),
                    max(0, ::get_attachable_cost_gold(decoratorName)))
    }
    getDecoratorNameInSlot = function(slotIdx, ...) { return ::hangar_get_attachable_name(slotIdx) }
    getDecoratorGroupInSlot = function(slotIdx, ...) { return ::hangar_get_attachable_group(slotIdx) }

    isAvailable = @(unit, checkUnitUsable = true) !!unit && ::has_feature("AttachablesUse")
      && (unit.isTank() || unit.isShipOrBoat())
      && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(::player_have_attachable)

    getBlk = function() { return ::get_attachable_blk() }

    removeDecorator = function(slotIdx, save)
    {
      ::hangar_remove_attachable(slotIdx)
      exitEditMode(true, save)
    }

    specifyEditableSlot = @(slotIdx, needFocus = true) ::hangar_select_attachable_slot(slotIdx)
    enterEditMode = function(decoratorName) { return ::hangar_add_attachable(decoratorName) }
    exitEditMode = function(apply, save, callback = function () {}) {
      let res = ::hangar_exit_attachables_mode(apply, save)
      if (res)
        callback()
      return res
    }

    buyFunc = function(unitName, id, cost, afterSuccessFunc)
    {
      let blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "attachable"
      blk["unitName"] = unitName
      blk["cost"] = cost.wp
      blk["costGold"] =-cost.gold

      let taskId = ::char_send_blk("cln_buy_resource", blk)
      let taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    save = function(unitName, showProgressBox)
    {
      if (!::has_feature("AttachablesUse"))
        return

      let taskId = ::save_attachables(unitName)
      let taskOptions = { showProgressBox = showProgressBox }
      ::g_tasker.addTask(taskId, taskOptions)
    }

    canRotate = @() true
  }
  SKINS = {
    unlockedItemType = ::UNLOCKABLE_SKIN
    resourceType = "skin"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_skin.png"
    prizeTypeIcon = "#ui/gameuiskin#item_type_skin.svg"
    defaultStyle = "reward_skin"

    getImage = function(decorator)
    {
      if (!decorator)
        return ""
      let mask = skinLocations.getSkinLocationsMaskBySkinId(decorator.id)
      let iconType = skinLocations.getIconTypeByMask(mask)
      let suffix =  iconType == "forest" ? "" : $"_{iconType}"
      return $"#ui/gameuiskin/item_skin{suffix}.png"
    }

    getSmallIcon = function(decorator)
    {
      if (!decorator)
        return ""
      return $"#ui/gameuiskin#icon_skin_{skinLocations.getIconTypeByMask(skinLocations.getSkinLocationsMaskBySkinId(decorator.id))}.svg"

    }

    getLocName = function(decoratorName, addUnitName = false)
    {
      if (guidParser.isGuid(decoratorName))
        return ::loc(decoratorName, ::loc("default_live_skin_loc"))

      local name = ""

      let unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)
      let unit = ::getAircraftByName(unitName)
      if (unit)
      {
        let skinNameId = ::g_unlocks.getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.nameLocId ?? "") != "")
          name = ::loc(skinBlock.nameLocId)
      }

      if (name == "")
      {
        if (::g_unlocks.isDefaultSkin(decoratorName))
          decoratorName = ::loc(unitName + "/default", ::loc("default_skin_loc"))

        name = ::loc(decoratorName)
      }

      if (addUnitName && !::u.isEmpty(unitName))
        name += ::loc("ui/parentheses/space", { text = ::getUnitName(unit) })

      return name
    }

    getLocDesc = function(decoratorName)
    {
      let unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)
      let unit = ::getAircraftByName(unitName)
      if (unit)
      {
        let skinNameId = ::g_unlocks.getSkinNameBySkinId(decoratorName)
        let skinBlock = unit.getSkinBlockById(skinNameId)
        if (skinBlock && (skinBlock?.descLocId ?? "") != "")
          return ::loc(skinBlock.descLocId)
      }

      let defaultLocId = guidParser.isGuid(decoratorName) ? "default_live_skin_loc/desc" : "default_skin_loc/desc"
      return ::loc(decoratorName + "/desc", ::loc(defaultLocId))
    }

    hasLocations = function(decoratorName)
    {
      let unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)
      let unit = ::getAircraftByName(unitName)
      return unit?.isTank() ?? false
    }

    function getTypeDesc(decorator)
    {
      let unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decorator.id))
      if (!unit)
        return ::loc("trophy/unlockables_names/skin")
      return ::loc("reward/skin_for") + " " +
        ::getUnitName(unit) + ::loc("ui/comma") + ::loc(::getUnitCountry(unit))
    }

    getCost = function(decoratorName)
    {
      let unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)
      return ::Cost(max(0, ::get_skin_cost_wp(unitName, decoratorName)),
                    max(0, ::get_skin_cost_gold(unitName, decoratorName)))
    }

    getFreeSlotIdx = @(...) 0
    isAvailable = @(unit, checkUnitUsable = true) !!unit && (!checkUnitUsable || unit.isUsable())
    isPlayerHaveDecorator = memoizeByProfile(function isPlayerHaveDecorator(decoratorName)
    {
      if (decoratorName == "")
        return false
      if (::g_unlocks.isDefaultSkin(decoratorName))
        return true

      return ::player_have_skin(::g_unlocks.getPlaneBySkinId(decoratorName),
                                ::g_unlocks.getSkinNameBySkinId(decoratorName))
    })

    getBlk = function() { return ::get_skins_blk() }

    buyFunc = function(unitName, id, cost, afterSuccessFunc)
    {
      let blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "skin"
      blk["unitName"] = unitName
      blk["cost"] = cost.wp
      blk["costGold"] = cost.gold

      let taskId = ::char_send_blk("cln_buy_resource", blk)
      let taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    getSpecialDecorator = function(id)
    {
      if (::g_unlocks.getSkinNameBySkinId(id) == "default")
        return ::Decorator(id, this)
      return null
    }

    getLiveDecorator = function(id, cache)
    {
      if (id in cache)
        return cache[id]

      let isLiveDownloaded = guidParser.isGuid(::g_unlocks.getSkinNameBySkinId(id))
      let isLiveItemContent = !isLiveDownloaded && guidParser.isGuid(id)
      if (!isLiveDownloaded && !isLiveItemContent)
        return null

      cache[id] <- ::Decorator(getBlk()?[id] ?? id, this)
      return cache[id]
    }

    canPreviewLiveDecorator = @() ::has_feature("EnableLiveSkins")

    updateDownloadableDecoratorsInfo = function(decorator) {
      let unitName = ::g_unlocks.getPlaneBySkinId(decorator.id)
      let unit = ::getAircraftByName(unitName)
      if (!unit)
        return

      updateDownloadableSkins(unitName)
    }
  }
}, null, "name")

g_decorator_type.getTypeByListId <- function getTypeByListId(listId)
{
  return enums.getCachedType("listId", listId, ::g_decorator_type.cache.byListId, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}

g_decorator_type.getTypeByUnlockedItemType <- function getTypeByUnlockedItemType(UnlockedItemType)
{
  return enums.getCachedType("unlockedItemType", UnlockedItemType, ::g_decorator_type.cache.byUnlockedItemType, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}

g_decorator_type.getTypeByResourceType <- function getTypeByResourceType(resourceType)
{
  return enums.getCachedType("resourceType", resourceType, ::g_decorator_type.cache.byResourceType, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}
