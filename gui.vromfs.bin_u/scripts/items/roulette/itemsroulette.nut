local u = require("sqStdLibs/helpers/u.nut")

/*
ItemsRoulette API:
  resetData() - rewrite params for future usage;
  reinitParams() - gather outside params once, eg. gui.blk;
  logDebugData() - print debug data into log;

  init - main launch function;
  fillDropChances() - calculate drop chances for items;
  generateItemsArray() - create array of tables of items which can be dropped in single copy,
                                                 recieves a trophyName as a main parameter;

  gatherItemsArray() - create main strip of items by random chances
  getItemsStack() - recieve items array peer slot in roulette
  getRandomItem() - recieve item, by random drop chance;
  insertCurrentReward() - insert into randomly generated strip
                                                 rewards which player really recieved;
*/

const MIN_ITEMS_OFFSET = 0.1
const MAX_ITEMS_OFFSET = 0.4

local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local rouletteAnim = require("scripts/items/roulette/rouletteAnim.nut")

local ROULETTE_PARAMS_DEFAULTS = {
  rouletteObj = null
  ownerHandler = null

  trophyItem = null
  insertRewardIdx = 0
  isGotTopPrize = false
  topPrizeLayout = null

  mainAnimationTimer = null
}

local ROULETTE_DEBUG_PARAMS_DEFAULTS = {
  mainLength = 0
  result = []
  unknown = []
  step = []
  beginChances = []
  trophyData = {}
  itemsLens = {}
  trophySlots = {}
  trophyDrop = {}
}

::ItemsRoulette <- ROULETTE_PARAMS_DEFAULTS.__merge({debugData = ROULETTE_DEBUG_PARAMS_DEFAULTS})

ItemsRoulette.resetData <- function resetData()
{
  this.__update(ROULETTE_PARAMS_DEFAULTS)
  this.debugData.__update(ROULETTE_DEBUG_PARAMS_DEFAULTS)
}

ItemsRoulette.reinitParams <- function reinitParams()
{
  local params = ["items_roulette_multiplier_slots",
                  "items_roulette_min_trophy_drop_mult"]

  local loadParams = false
  foreach(param in params)
  {
    if (::getTblValue(param, ::ItemsRoulette, null) == null)
    {
      loadParams = true
      break
    }
  }

  if (!loadParams)
    return

  local blk = ::configs.GUI.get()
  foreach(param in params)
  {
    local val = blk?[param] ?? 1.0
    ::ItemsRoulette[param] <- val
    ::ItemsRoulette.debugData[param] <- val
  }
}

ItemsRoulette.logDebugData <- function logDebugData()
{
  ::dagor.debug("ItemsRoulette: Print debug data of previously finished roulette")
  debugTableData(::ItemsRoulette.debugData, {recursionLevel = 10})
}

ItemsRoulette.init <- function init(trophyName, rewardsArray, imageObj, handler, afterDoneFunc = null)
{
  if (!::checkObj(imageObj))
    return false

  local placeObj = imageObj.findObject("reward_roullete")
  if (!::checkObj(placeObj))
    return false

  resetData()

  rouletteObj = placeObj.findObject("rewards_list")
  if (!::checkObj(rouletteObj))
    return false

  reinitParams()

  ownerHandler = handler

  local totalLen = ::to_integer_safe(placeObj?.totalLen, 1)
  local insertRewardFromEnd = ::to_integer_safe(placeObj?.insertRewardFromEnd, 1)
  insertRewardIdx = totalLen - insertRewardFromEnd - 1
  if (insertRewardIdx < 0 || insertRewardIdx >= totalLen)
  {
    ::dagor.assertf(false, "Insert index is wrong: " + insertRewardIdx + " / " + totalLen)
    return false
  }

  trophyItem = ::ItemsManager.findItemById(trophyName)
  if (!trophyItem || trophyItem.skipRoulette())
    return false

  local trophyData = ::ItemsRoulette.generateItemsArray(trophyName)
  ::ItemsRoulette.debugData.trophyData = trophyData

  local trophyArray = trophyData?.trophy ?? []
  if (!::has_feature("ItemsRoulette")
      || trophyArray.len() == 0
      || (trophyArray.len() == 1 && !("trophy" in trophyArray[0]))
     )
    return false

  topPrizeLayout = null
  isGotTopPrize = false
  foreach (prize in rewardsArray)
    isGotTopPrize = isGotTopPrize || trophyItem.isHiddenTopPrize(prize)

  local processedItemsArray = ::ItemsRoulette.gatherItemsArray(trophyData, totalLen)

  ::ItemsRoulette.insertCurrentReward(processedItemsArray, rewardsArray)
  ::ItemsRoulette.insertHiddenTopPrize(processedItemsArray)

  local data = createItemsMarkup(processedItemsArray)
  placeObj.getScene().replaceContentFromText(rouletteObj, data, data.len(), handler)
  placeObj.show(true)

  ::updateTransparencyRecursive(placeObj, 0)
  placeObj.animation = "show"

  local blackoutObj = imageObj.findObject("blackout_background")
  if (::checkObj(blackoutObj))
    blackoutObj.animation = "show"

  local afterDoneCb = function() {
    ::ItemsRoulette.showTopPrize(rewardsArray)
    afterDoneFunc()
  }

  local anim = rouletteAnim.get(trophyItem.getOpeningAnimId())
  dagor.debug("ItemsRoulette: open trophy " + trophyItem.id + ", animaton = " + anim.id)
  anim.startAnim(rouletteObj, insertRewardIdx)

  placeObj.getScene().applyPendingChanges(false)
  local delay = rouletteAnim.getTimeLeft(rouletteObj) || 0.1
  mainAnimationTimer = ::Timer(placeObj, delay, afterDoneCb, handler).weakref()
  return true
}

ItemsRoulette.skipAnimation <- function skipAnimation(obj)
{
  rouletteAnim.DEFAULT.skipAnim(obj)
  if (mainAnimationTimer)
    mainAnimationTimer.destroy()
}

ItemsRoulette.generateItemsArray <- function generateItemsArray(trophyName)
{
  local trophy = ::ItemsManager.findItemById(trophyName) || ItemGenerators.get(trophyName)
  if (!trophy)
  {
    ::dagor.debug("ItemsRoulette: Cannot find trophy by name " + trophyName)
    return {}
  }

  if (trophy?.iType != itemType.TROPHY && trophy?.iType != itemType.CHEST && !trophy?.genType)
  {
    ::dagor.debug("ItemsRoulette: Founded item is not a trophy")
    ::dagor.debug(trophy.tostring())
    return {}
  }

  local itemsArray = []
  local commonParams = {
    dropChance = 0.0
    multDiff = 0.0
  }

  local debug = {trophy = trophyName}
  local content = trophy.getContentNoRecursion()
  //!!FIX ME: do not use _getContentFixedAmount outside of prizes list. it very specific for prizes stacks description
  local countContent = ::PrizesView._getContentFixedAmount(content)
  local shouldOnlyImage = countContent > 1
  foreach(block in content)
  {
    if (block?.trophy)
    {
      local table = clone commonParams
      local trophyData = ::ItemsRoulette.generateItemsArray(block.trophy)
      table.trophy <- trophyData.trophy
      table.trophyId <- block.trophy
      table.count <- ::getTblValue("count", block, 1)
      table.rewardsCount <- 0
      table.trophiesCount <- 0
      itemsArray.append(table)
    }
    else
    {
      debug[::ItemsRoulette.getUniqueTableKey(block)] <- 0
      local table = clone commonParams
      table.reward <- block
      table.layout <- ::ItemsRoulette.getRewardLayout(block, shouldOnlyImage)
      itemsArray.append(table)
    }
  }

  ::ItemsRoulette.debugData.result.append(debug)
  return {
    trophy = itemsArray,
    count = countContent
  }
}

ItemsRoulette.getUniqueTableKey <- function getUniqueTableKey(rewardBlock)
{
  if (!rewardBlock)
  {
    ::ItemsRoulette.logDebugData()
    ::dagor.assertf(false, "Bad block for unique key")
    return ""
  }

  local tKey = ::trophyReward.getType(rewardBlock)
  local tVal = rewardBlock?[tKey] ?? ""
  return tKey + "_" + tVal
}

ItemsRoulette.getTopItem <- function getTopItem(trophyBlock)
{
  if ("reward" in trophyBlock)
    return trophyBlock

  return u.isArray(trophyBlock) ? getTopItem(trophyBlock[0])
         : "trophy" in trophyBlock ? getTopItem(trophyBlock.trophy)
         : null
}

ItemsRoulette.gatherItemsArray <- function gatherItemsArray(trophyData, mainLength)
{
  ::ItemsRoulette.debugData.mainLength = mainLength

  local topItem = ::ItemsRoulette.getTopItem(trophyData.trophy)
  topItem = topItem? clone topItem : null

  local shouldSearchTopReward = topItem?.hasTopRewardAsFirstItem ?? false
  local topRewardKey = ::ItemsRoulette.getUniqueTableKey(topItem?.reward)

  ::ItemsRoulette.fillDropChances(trophyData.trophy)

  local topRewardFound = false
  local resultArray = []
  for (local i = 0; i < mainLength; i++)
  {
    local tablesArray = ::ItemsRoulette.getItemsStack(trophyData)
    foreach(table in tablesArray)
    {
      if (shouldSearchTopReward)
        topRewardFound = topRewardFound || topRewardKey == ::getTblValue("tKey", table)
    }

    ::ItemsRoulette.debugData.step.append(tablesArray)
    resultArray.append(tablesArray)
  }

  if (shouldSearchTopReward && !topRewardFound)
  {
    local insertIdx = insertRewardIdx + 1 // Interting teaser item next to reward.
    if (insertIdx >= mainLength)
      insertIdx = 0
    ::dagor.debug("ItemsRoulette: Top reward by key " + topRewardKey + " not founded." +
         "Insert manually into " + insertIdx + ".")

    local slot = resultArray[insertIdx]
    if (slot.len() == 0)
      slot.append(topItem)
    else
      slot[0] = topItem
  }

  return resultArray
}

/*  Rules for drop chances
1) Trophies have increased drop chance percent
   on param items_roulette_multiplier_slots readed from gui.blk;
2) Trophy slots fills proportionally to count of items in trophies
3) Trophy drop chance calculates as
    (Trophy Slots Num * Current trophy Items Length / All trophies items length)
4) Check max value, cos minimal value of items from trophy
   is set as Current trophy Items Length * items_roulette_min_trophy_drop_mult (set in gui.blk)
*/

ItemsRoulette.fillDropChances <- function fillDropChances(trophyBlock)
{
  local trophyBlockTrophiesItemsCount = 0

  local isSingleReward = "reward" in trophyBlock
  local isTrophy = "trophy" in trophyBlock

  local itemsArray = trophyBlock //will be array from first call, from generateItemsArray
  if (isTrophy) // will be passed as a trophy block, but we need trophy params AND trophy items array
    itemsArray = trophyBlock.trophy
  else if (isSingleReward) //could be just a reward item, without trophy
    itemsArray = [trophyBlock]

  foreach(idx, block in itemsArray)
  {
    if ("reward" in block)
    {
      // Simple item block, last iteration of looped call
      local dropChance = itemsArray[idx].reward?.dropChance.tofloat() ?? 1.0
      ::ItemsRoulette.debugData.beginChances.append({[::ItemsRoulette.getUniqueTableKey(itemsArray[idx].reward)] = dropChance})
      itemsArray[idx].dropChance = dropChance
      itemsArray[idx].multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(false, dropChance)

      if (isSingleReward || !isTrophy)
        continue

      trophyBlock.rewardsCount++
      local dbgTrophyId = "trophy_" + trophyBlock.trophyId
      if (!(dbgTrophyId in ::ItemsRoulette.debugData.itemsLens))
        ::ItemsRoulette.debugData.itemsLens[dbgTrophyId] <- 0

      ::ItemsRoulette.debugData.itemsLens[dbgTrophyId]++
    }
    else if ("trophy" in block)
    {
      // Trophy block, need to go deeper first
      if (isTrophy)
      {
        fillDropChances(trophyBlock.trophy[idx])
        trophyBlock.trophiesCount++
        trophyBlockTrophiesItemsCount += block.trophy.len()
      }
      else
        fillDropChances(trophyBlock[idx])
    }
  }

  if (isSingleReward || !isTrophy)
    return

  local dbgTrophyNewId = "trophy_" + trophyBlock.trophyId

  local trophyBlockItemsCount = trophyBlock.rewardsCount + trophyBlock.trophiesCount
  local slots = trophyBlockItemsCount * ::ItemsRoulette.items_roulette_multiplier_slots - trophyBlock.rewardsCount
  ::ItemsRoulette.debugData.trophySlots[dbgTrophyNewId] <- slots

  local drop = trophyBlockTrophiesItemsCount > 0? (slots * trophyBlockItemsCount / trophyBlockTrophiesItemsCount) : 0

  local dropTrophy = ::max(drop, trophyBlockItemsCount * ::ItemsRoulette.items_roulette_min_trophy_drop_mult)

  trophyBlock.dropChance = dropTrophy / ::getTblValue("count", trophyBlock, 1)
  trophyBlock.multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(true, trophyBlock.dropChance)
  ::ItemsRoulette.debugData.beginChances.append({[dbgTrophyNewId] = trophyBlock.dropChance})

  ::ItemsRoulette.debugData.trophyDrop[dbgTrophyNewId] <- {
    slots = slots
    itemsLen = trophyBlockItemsCount
    trophiesItemsLength = trophyBlockTrophiesItemsCount
    defaultDrop = trophyBlockItemsCount * ::ItemsRoulette.items_roulette_min_trophy_drop_mult
    dropTrophy = dropTrophy
    count = ::getTblValue("count", trophyBlock, 1)
    dropChance = trophyBlock.dropChance
  }
}

ItemsRoulette.getItemsStack <- function getItemsStack(trophyData)
{
  local rndItemsArray = ::array(trophyData.count, null).map(@(elem) ::ItemsRoulette.getRandomItem(trophyData))

  foreach(item in rndItemsArray)
  {
    local tKey = ::ItemsRoulette.getUniqueTableKey(item?.reward)
    foreach(table in ::ItemsRoulette.debugData.result)
    {
      if (tKey in table)
      {
        item.tKey <- tKey
        table[tKey]++
        break
      }
    }
  }

  return rndItemsArray
}

ItemsRoulette.getRandomItem <- function getRandomItem(trophyBlock)
{
  local res = null
  local rndChance = ::math.frnd() * trophyBlock.trophy.reduce(@(res, v) res + v.dropChance, 0.0)

  foreach(idx, item in trophyBlock.trophy)
  {
    rndChance -= item.dropChance
    res = trophyBlock.trophy[idx]

    if (rndChance < 0)
      break
  }

  res.dropChance -= res.dropChance * res.multDiff

  if ("trophy" in res)
    return getRandomItem(res)

  return res
}

ItemsRoulette.getCurrentReward <- function getCurrentReward(rewardsArray)
{
  local res = []
  local shouldOnlyImage = rewardsArray.len() > 1
  foreach(idx, reward in rewardsArray)
  {
    rewardsArray[idx].layout <- ::ItemsRoulette.getRewardLayout(reward, shouldOnlyImage)
    res.append(reward)
  }
  return res
}

ItemsRoulette.insertCurrentReward <- function insertCurrentReward(readyItemsArray, rewardsArray)
{
  readyItemsArray[insertRewardIdx] = getCurrentReward(rewardsArray)
}

ItemsRoulette.getHiddenTopPrizeReward <- function getHiddenTopPrizeReward(params)
{
  local showType = params?.show_type ?? "vehicle"
  local layerCfg = clone ::LayersIcon.findLayerCfg("item_place_single")
  layerCfg.img <- "#ui/gameuiskin#item_" + showType
  local image = ::LayersIcon.genDataFromLayer(layerCfg)
  local layout = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)

  return {
    id = trophyItem.id
    item = null
    layout = layout
  }
}

ItemsRoulette.insertHiddenTopPrize <- function insertHiddenTopPrize(readyItemsArray)
{
  local hiddenTopPrizeParams = trophyItem.getHiddenTopPrizeParams()
  if (!hiddenTopPrizeParams)
    return

  local showFreq = (hiddenTopPrizeParams?.showFreq ?? "0").tointeger() / 100.0
  local shouldShowTeaser = ::math.frnd() >= 1.0 - showFreq
  if (!isGotTopPrize && !shouldShowTeaser)
    return

  if (isGotTopPrize)
    topPrizeLayout = ::g_string.implode(::u.map(readyItemsArray[insertRewardIdx], @(p) p.layout))

  local insertIdx = 0
  if (isGotTopPrize)
    insertIdx = insertRewardIdx
  else
  {
    local idxMax = insertRewardIdx
    local idxMin = ::max(insertRewardIdx /5*4, 0)
    insertIdx = idxMin + ((idxMax - idxMin) * ::math.frnd()).tointeger()
    if (insertIdx == insertRewardIdx)
      insertIdx++
  }

  local slot = readyItemsArray[insertIdx]
  if (!slot.len())
    slot.append({})
  slot[0] = { reward = ::ItemsRoulette.getHiddenTopPrizeReward(hiddenTopPrizeParams) }
}

ItemsRoulette.showTopPrize <- function showTopPrize(rewardsArray)
{
  if (!topPrizeLayout)
    return
  if (topPrizeLayout == "" && isGotTopPrize)
    topPrizeLayout = ::g_string.implode(::u.map(getCurrentReward(rewardsArray), @(p) p.layout))

  if (topPrizeLayout == "")
    return

  local obj = ::check_obj(rouletteObj) && rouletteObj.findObject("roulette_slot_" + insertRewardIdx)
  if (!::check_obj(obj))
    return
  local guiScene = rouletteObj.getScene()
  guiScene.replaceContentFromText(obj, topPrizeLayout, topPrizeLayout.len(), ownerHandler)
}

ItemsRoulette.createItemsMarkup <- function createItemsMarkup(completeArray)
{
  local result = ""
  foreach(idx, slot in completeArray)
  {
    local slotRes = []
    local offset = ::LayersIcon.getOffset(slot.len(), MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET)

    foreach(slotIdx, item in slot)
      slotRes.insert(0,
        ::LayersIcon.genDataFromLayer(
          { x = (offset * slotIdx) + "@itemWidth", w = "1@itemWidth" },
          item?.reward?.layout ?? item?.layout))

    local layerCfg = ::LayersIcon.findLayerCfg("roulette_slot")
    local width = 1
    if (slot.len() > 1)
      width += offset * (slot.len() - 1)
    layerCfg.w <- width + "@itemWidth"
    layerCfg.id <- "roulette_slot_" + idx

    result += ::LayersIcon.genDataFromLayer(layerCfg, ::g_string.implode(slotRes))
  }

  return result
}

ItemsRoulette.getRewardLayout <- function getRewardLayout(block, shouldOnlyImage = false)
{
  local config = block?.reward.reward ?? block
  local rType = ::trophyReward.getType(config)
  if (::trophyReward.isRewardItem(rType))
    return ::trophyReward.getImageByConfig(config, shouldOnlyImage, "roulette_item_place")

  local image = ::trophyReward.getImageByConfig(config, shouldOnlyImage, "item_place_single")
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)
}

ItemsRoulette.getChanceMultiplier <- function getChanceMultiplier(isTrophy, dropChance)
{
  local chanceMult = 0.5
  if (isTrophy)
    chanceMult = ::pow(0.5, 1.0/dropChance)
  return chanceMult
}
