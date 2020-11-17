local u = require("sqStdLibs/helpers/u.nut")
local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local Set = require("workshopSet.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local seenWorkshop = require("scripts/seen/seenList.nut").get(SEEN.WORKSHOP)

local OUT_OF_DATE_DAYS_WORKSHOP = 28

local isInited = false
local setsList = []
local markingPresetsList = {}
local emptySet = Set(::DataBlock())

local visibleSeenIds = null
local seenIdCanBeNew = {}
local additionalRecipes = {}

local customLocalizationPresets = {}
local effectOnStartCraftPresets = {}
local effectOnOpenChestPresets = {}

local function initOnce()
{
  if (isInited || !::g_login.isProfileReceived())
    return
  isInited = true
  setsList.clear()

  local wBlk = ::DataBlock()
  wBlk.load("config/workshop.blk")
  for(local i = 0; i < wBlk.blockCount(); i++)
  {
    local set = Set(wBlk.getBlock(i))
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
    foreach (itemBlk in (wBlk.additionalRecipes % "item"))
    {
      local item = ::DataBlock()
      item.setFrom(itemBlk)
      local itemId = ::to_integer_safe(item.id)
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

local function invalidateCache()
{
  setsList.clear()
  markingPresetsList = {}
  customLocalizationPresets = {}
  effectOnStartCraftPresets = {}
  effectOnOpenChestPresets = {}
  additionalRecipes = {}
  isInited = false
}

local function getSetsList()
{
  initOnce()
  return setsList
}

local function getMarkingPresetsById(presetName)
{
  initOnce()
  return markingPresetsList?[presetName]
}

local function shouldDisguiseItem(item)
{
  foreach(set in getSetsList())
    if (set.isItemInSet(item))
      return set.shouldDisguiseItem(item)
  return false
}

local function getVisibleSeenIds()
{
  if (!visibleSeenIds)
  {
    visibleSeenIds = {}
    foreach(set in getSetsList())
      if (set.isVisible())
        visibleSeenIds.__update(set.getVisibleSeenIds())
  }
  return visibleSeenIds
}

local function invalidateItemsCache()
{
  visibleSeenIds = null
  seenIdCanBeNew.clear()
  foreach(set in getSetsList())
    set.invalidateItemsCache()
  if (ItemsManager.isInventoryFullUpdated)
    seenWorkshop.setDaysToUnseen(OUT_OF_DATE_DAYS_WORKSHOP)
  seenWorkshop.onListChanged()
}

local function canSeenIdBeNew(seenId)
{
  if (!(seenId in seenIdCanBeNew))
  {
    local id = ::to_integer_safe(seenId, seenId, false) //ext inventory items id need to convert to integer.
    local item = ::ItemsManager.findItemById(id)
    seenIdCanBeNew[seenId] <- item && !shouldDisguiseItem(item)
  }
  return seenIdCanBeNew[seenId]
}

local getCustomLocalizationPresets = function(name) {
  initOnce()
  return customLocalizationPresets?[name] ?? {}
}

local function getItemAdditionalRecipesById(id)
{
  initOnce()
  return additionalRecipes?[id] ?? []
}

local getEffectOnStartCraftPresetById = function(name) {
  initOnce()
  return effectOnStartCraftPresets?[name] ?? {}
}

local getEffectOnOpenChestPresetById = function(name) {
  initOnce()
  return effectOnOpenChestPresets?[name] ?? {}
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  InventoryUpdate = @(p) invalidateItemsCache()
  ItemsShopUpdate = @(p) invalidateItemsCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

seenWorkshop.setListGetter(getVisibleSeenIds)
seenWorkshop.setCanBeNewFunc(canSeenIdBeNew)

return {
  emptySet = emptySet

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