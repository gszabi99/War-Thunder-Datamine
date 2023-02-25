//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock  = require("DataBlock")
let { frnd } = require("dagor.random")
let u = require("%sqStdLibs/helpers/u.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let Set = require("workshopSet.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let seenWorkshop = require("%scripts/seen/seenList.nut").get(SEEN.WORKSHOP)
let { isArray } = require("%sqstd/underscore.nut")

let OUT_OF_DATE_DAYS_WORKSHOP = 28

local isInited = false
let setsList = []
local markingPresetsList = {}
let emptySet = Set(DataBlock())

local visibleSeenIds = null
let seenIdCanBeNew = {}
local additionalRecipes = {}

local customLocalizationPresets = {}
local effectOnStartCraftPresets = {}
local effectOnOpenChestPresets = {}

let function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return
  isInited = true
  setsList.clear()

  let wBlk = DataBlock()
  wBlk.load("config/workshop.blk")
  for (local i = 0; i < wBlk.blockCount(); i++) {
    let set = Set(wBlk.getBlock(i))
    if (!set.isValid())
      continue

    set.uid = setsList.len()
    setsList.append(set)

    if (set.isVisible())
      inventoryClient.requestItemdefsByIds(set.itemdefsSorted)

    seenWorkshop.setSubListGetter(set.getSeenId(), @() set.getVisibleSeenIds())
  }
  Set.clearOutdatedData(setsList)

  // Collecting itemdefs from additional recipes list
  if (wBlk?.additionalRecipes)
    foreach (itemBlk in (wBlk.additionalRecipes % "item")) {
      let item = DataBlock()
      item.setFrom(itemBlk)
      let itemId = ::to_integer_safe(item.id)
      if (!additionalRecipes?[itemId])
        additionalRecipes[itemId] <- []
      additionalRecipes[itemId].append(item)
      foreach (paramName in ["fakeRecipe", "trueRecipe"])
        inventoryClient.requestItemdefsByIds(itemBlk % paramName)
    }

  markingPresetsList = ::buildTableFromBlk(wBlk?.itemMarkingPresets)
  customLocalizationPresets = ::buildTableFromBlk(wBlk?.customLocalizationPresets)
  effectOnStartCraftPresets = ::buildTableFromBlk(wBlk?.effectOnStartCraftPresets)
  effectOnOpenChestPresets = ::buildTableFromBlk(wBlk?.effectOnOpenChestPresets)
}

let function invalidateCache() {
  setsList.clear()
  markingPresetsList = {}
  customLocalizationPresets = {}
  effectOnStartCraftPresets = {}
  effectOnOpenChestPresets = {}
  additionalRecipes = {}
  isInited = false
}

let function getSetsList() {
  initOnce()
  return setsList
}

let function getMarkingPresetsById(presetName) {
  initOnce()
  return markingPresetsList?[presetName]
}

let function shouldDisguiseItem(item) {
  foreach (set in getSetsList())
    if (set.isItemInSet(item))
      return set.shouldDisguiseItem(item)
  return false
}

let function getVisibleSeenIds() {
  if (!visibleSeenIds) {
    visibleSeenIds = {}
    foreach (set in getSetsList())
      if (set.isVisible())
        visibleSeenIds.__update(set.getVisibleSeenIds())
  }
  return visibleSeenIds
}

let function invalidateItemsCache() {
  visibleSeenIds = null
  seenIdCanBeNew.clear()
  foreach (set in getSetsList())
    set.invalidateItemsCache()
  if (::ItemsManager.isInventoryFullUpdated)
    seenWorkshop.setDaysToUnseen(OUT_OF_DATE_DAYS_WORKSHOP)
  seenWorkshop.onListChanged()
}

let function canSeenIdBeNew(seenId) {
  if (!(seenId in seenIdCanBeNew)) {
    let id = ::to_integer_safe(seenId, seenId, false) //ext inventory items id need to convert to integer.
    let item = ::ItemsManager.findItemById(id)
    seenIdCanBeNew[seenId] <- item && !shouldDisguiseItem(item)
  }
  return seenIdCanBeNew[seenId]
}

let getCustomLocalizationPresets = function(name) {
  initOnce()
  return customLocalizationPresets?[name] ?? {}
}

let function getItemAdditionalRecipesById(id) {
  initOnce()
  return additionalRecipes?[id] ?? []
}

let getEffectOnStartCraftPresetById = function(name) {
  initOnce()
  return effectOnStartCraftPresets?[name] ?? {}
}

let getEffectOnOpenChestPresetById = function(name) {
  initOnce()
  return effectOnOpenChestPresets?[name] ?? {}
}

let function getRandomEffect(effects) {
  return isArray(effects)
    ? effects?[(frnd() * effects.len()).tointeger()] ?? ""
    : effects
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  InventoryUpdate = @(_p) invalidateItemsCache()
  ItemsShopUpdate = @(_p) invalidateItemsCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

seenWorkshop.setListGetter(getVisibleSeenIds)
seenWorkshop.setCanBeNewFunc(canSeenIdBeNew)

return {
  emptySet = emptySet
  getRandomEffect
  isAvailable = @() u.search(getSetsList(), @(s) s.isVisible()) != null
  getSetsList = getSetsList
  getMarkingPresetsById = getMarkingPresetsById
  shouldDisguiseItem = shouldDisguiseItem
  getSetById = @(id) u.search(getSetsList(), @(s) s.id == id)
  getSetByItemId = @(itemId) u.search(getSetsList(), @(s) s.isItemIdInSet(itemId))
  getCustomLocalizationPresets = getCustomLocalizationPresets
  getItemAdditionalRecipesById = getItemAdditionalRecipesById
  getEffectOnStartCraftPresetById = getEffectOnStartCraftPresetById
  getEffectOnOpenChestPresetById = getEffectOnOpenChestPresetById
}