from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { isArray } = require("%sqStdLibs/helpers/u.nut")
let { pow } = require("math")
let { frnd } = require("dagor.random")
let { GUI } = require("%scripts/utils/configs.nut")
let { getItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let rouletteAnim = require("%scripts/items/roulette/rouletteAnim.nut")
let { updateTransparencyRecursive } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getContentFixedAmount, getPrizeImageByConfig } = require("%scripts/items/prizesView.nut")
let { getTrophyRewardType, isRewardItem } = require("%scripts/items/trophyReward.nut")



















const MIN_ITEMS_OFFSET = 0.1
const MAX_ITEMS_OFFSET = 0.4

local insertRewardIdx = 0
local topPrizeLayout = null
local mainAnimationTimerWeekref = null

let debugData = {
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

let itemRouletteParams = {
  items_roulette_multiplier_slots = -1
  items_roulette_min_trophy_drop_mult = -1
}

function resetData() {
  insertRewardIdx = 0
  topPrizeLayout = null
  mainAnimationTimerWeekref = null

  debugData.mainLength = 0
  debugData.result.clear()
  debugData.unknown.clear()
  debugData.step.clear()
  debugData.beginChances.clear()
  debugData.trophyData.clear()
  debugData.itemsLens.clear()
  debugData.trophySlots.clear()
  debugData.trophyDrop.clear()
}

resetData()

function reinitParams() {
  if (itemRouletteParams.findvalue(@(v) v == -1) == null)
    return

  let blk = GUI.get()
  foreach (key, _v in itemRouletteParams) {
    let val = blk?[key] ?? 1.0
    itemRouletteParams[key] = val
    debugData[key] <- val
  }
}

function getRandomItem(trophyData) {
  local res = null
  local rndChance = frnd() * trophyData.trophy.reduce(@(resChance, v) resChance + v.dropChance, 0.0)

  foreach (item in trophyData.trophy) {
    res = item
    rndChance -= item.dropChance
    if (rndChance < 0)
      break
  }

  res.dropChance -= res.dropChance * res.multDiff
  return res
}

function getRandomItems(trophyData) {
  let self = callee()
  return array(trophyData.count, null)
    .map(@(_) getRandomItem(trophyData))
    .reduce(@(acc, v) acc.extend(v?.trophy ? self(v) : [v]), [])
}

function logDebugData() {
  log("ItemsRoulette: Print debug data of previously finished roulette")
  debugTableData(debugData, { recursionLevel = 10 })
}

function getUniqueTableKey(rewardBlock) {
  if (!rewardBlock) {
    logDebugData()
    assert(false, "Bad block for unique key")
    return ""
  }

  let tKey = getTrophyRewardType(rewardBlock)
  let tVal = rewardBlock?[tKey] ?? ""
  return $"{tKey}_{tVal}"
}

function getRewardLayout(block, shouldOnlyImage = false) {
  let config = block?.reward.reward ?? block
  let rType = getTrophyRewardType(config)
  if (isRewardItem(rType))
    return getPrizeImageByConfig(config, shouldOnlyImage, "roulette_item_place")

  let image = getPrizeImageByConfig(config, shouldOnlyImage, "item_place_single")
  return LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("roulette_item_place"), image)
}

function generateItemsArray(trophyName) {
  let trophy = findItemById(trophyName) || getItemGenerator(trophyName)
  if (!trophy) {
    log($"ItemsRoulette: Cannot find trophy by name {trophyName}")
    return {}
  }

  if (trophy?.iType != itemType.TROPHY && trophy?.iType != itemType.CHEST && !trophy?.genType) {
    log("ItemsRoulette: Founded item is not a trophy")
    log(trophy.tostring())
    return {}
  }

  let itemsArray = []
  let commonParams = {
    dropChance = 0.0
    multDiff = 0.0
  }

  let debug = { trophy = trophyName }
  let content = trophy.getContentNoRecursion()
  let countContent = getContentFixedAmount(content)
  let shouldOnlyImage = countContent > 1
  foreach (block in content) {
    if (block?.trophy) {
      let table = clone commonParams
      let trophyData = generateItemsArray(block.trophy)
      table.trophy <- trophyData.trophy
      table.trophyId <- block.trophy
      table.count <- getTblValue("count", block, 1)
      table.rewardsCount <- 0
      table.trophiesCount <- 0
      itemsArray.append(table)
    }
    else {
      debug[getUniqueTableKey(block)] <- 0
      let table = clone commonParams
      table.reward <- block
      table.layout <- getRewardLayout(block, shouldOnlyImage)
      itemsArray.append(table)
    }
  }

  debugData.result.append(debug)
  return {
    trophy = itemsArray,
    count = 1
  }
}

function getTopItem(trophyBlock) {
  if ("reward" in trophyBlock)
    return trophyBlock

  return isArray(trophyBlock) ? getTopItem(trophyBlock[0])
         : "trophy" in trophyBlock ? getTopItem(trophyBlock.trophy)
         : null
}

function getChanceMultiplier(isTrophy, dropChance) {
  local chanceMult = 0.5
  if (isTrophy)
    chanceMult = pow(0.5, 1.0 / dropChance)
  return chanceMult
}











function fillDropChances(trophyBlock) {
  local trophyBlockTrophiesItemsCount = 0

  let isSingleReward = "reward" in trophyBlock
  let isTrophy = "trophy" in trophyBlock

  local itemsArray = trophyBlock 
  if (isTrophy) 
    itemsArray = trophyBlock.trophy
  else if (isSingleReward) 
    itemsArray = [trophyBlock]

  foreach (idx, block in itemsArray) {
    if ("reward" in block) {
      
      let dropChance = itemsArray[idx].reward?.dropChance.tofloat() ?? 1.0
      debugData.beginChances.append({ [getUniqueTableKey(itemsArray[idx].reward)] = dropChance })
      itemsArray[idx].dropChance = dropChance
      itemsArray[idx].multDiff = 1 - getChanceMultiplier(false, dropChance)

      if (isSingleReward || !isTrophy)
        continue

      trophyBlock.rewardsCount++
      let dbgTrophyId =$"trophy_{trophyBlock.trophyId}"
      if (!(dbgTrophyId in debugData.itemsLens))
        debugData.itemsLens[dbgTrophyId] <- 0

      debugData.itemsLens[dbgTrophyId]++
    }
    else if ("trophy" in block) {
      
      if (isTrophy) {
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

  let dbgTrophyNewId =$"trophy_{trophyBlock.trophyId}"

  let trophyBlockItemsCount = trophyBlock.rewardsCount + trophyBlock.trophiesCount
  let slots = trophyBlockItemsCount * itemRouletteParams.items_roulette_multiplier_slots - trophyBlock.rewardsCount
  debugData.trophySlots[dbgTrophyNewId] <- slots

  let drop = trophyBlockTrophiesItemsCount > 0 ? (slots * trophyBlockItemsCount / trophyBlockTrophiesItemsCount) : 0

  let dropTrophy = max(drop, trophyBlockItemsCount * itemRouletteParams.items_roulette_min_trophy_drop_mult)

  trophyBlock.dropChance = dropTrophy / getTblValue("count", trophyBlock, 1)
  trophyBlock.multDiff = 1 - getChanceMultiplier(true, trophyBlock.dropChance)
  debugData.beginChances.append({ [dbgTrophyNewId] = trophyBlock.dropChance })

  debugData.trophyDrop[dbgTrophyNewId] <- {
    slots = slots
    itemsLen = trophyBlockItemsCount
    trophiesItemsLength = trophyBlockTrophiesItemsCount
    defaultDrop = trophyBlockItemsCount * itemRouletteParams.items_roulette_min_trophy_drop_mult
    dropTrophy = dropTrophy
    count = getTblValue("count", trophyBlock, 1)
    dropChance = trophyBlock.dropChance
  }
}

function getItemsStack(trophyData) {
  let rndItemsArray = getRandomItems(trophyData)
  foreach (item in rndItemsArray) {
    let tKey = getUniqueTableKey(item?.reward)
    foreach (table in debugData.result) {
      if (tKey in table) {
        item.tKey <- tKey
        table[tKey]++
        break
      }
    }
  }

  return rndItemsArray
}

function gatherItemsArray(trophyData, mainLength) {
  debugData.mainLength = mainLength

  local topItem = getTopItem(trophyData.trophy)
  topItem = topItem ? clone topItem : null

  let shouldSearchTopReward = topItem?.hasTopRewardAsFirstItem ?? false
  let topRewardKey = getUniqueTableKey(topItem?.reward)

  fillDropChances(trophyData.trophy)

  local topRewardFound = false
  let resultArray = []
  for (local i = 0; i < mainLength; i++) {
    let tablesArray = getItemsStack(trophyData)
    foreach (table in tablesArray) {
      if (shouldSearchTopReward)
        topRewardFound = topRewardFound || topRewardKey == getTblValue("tKey", table)
    }

    debugData.step.append(tablesArray)
    resultArray.append(tablesArray)
  }

  if (shouldSearchTopReward && !topRewardFound) {
    local insertIdx = insertRewardIdx + 1 
    if (insertIdx >= mainLength)
      insertIdx = 0
    log($"ItemsRoulette: Top reward by key {topRewardKey} not founded. Insert manually into {insertIdx}.")

    let slot = resultArray[insertIdx]
    if (slot.len() == 0)
      slot.append(topItem)
    else
      slot[0] = topItem
  }

  return resultArray
}

function getCurrentReward(rewardsArray) {
  let res = []
  let shouldOnlyImage = rewardsArray.len() > 1
  foreach (idx, reward in rewardsArray) {
    rewardsArray[idx].layout <- getRewardLayout(reward, shouldOnlyImage)
    res.append(reward)
  }
  return res
}

function insertCurrentReward(readyItemsArray, rewardsArray) {
  readyItemsArray[insertRewardIdx] = getCurrentReward(rewardsArray)
}

function getHiddenTopPrizeReward(trophyItem, showType) {
  let layerCfg = clone LayersIcon.findLayerCfg("item_place_single")
  layerCfg.img <- $"#ui/gameuiskin#item_{showType}"
  let image = LayersIcon.genDataFromLayer(layerCfg)
  let layout = LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("roulette_item_place"), image)

  return {
    id = trophyItem.id
    item = null
    layout = layout
  }
}

function insertHiddenTopPrize(readyItemsArray, trophyItem, isGotTopPrize) {
  let hiddenTopPrizeParams = trophyItem.getHiddenTopPrizeParams()
  if (!hiddenTopPrizeParams)
    return

  let showFreq = (hiddenTopPrizeParams?.showFreq ?? "0").tointeger() / 100.0
  let shouldShowTeaser = frnd() >= 1.0 - showFreq
  if (!isGotTopPrize && !shouldShowTeaser)
    return

  if (isGotTopPrize)
    topPrizeLayout = "".join(readyItemsArray[insertRewardIdx].map(@(p) p.layout), true)

  local insertIdx = 0
  if (isGotTopPrize)
    insertIdx = insertRewardIdx
  else {
    let idxMax = insertRewardIdx
    let idxMin = max(insertRewardIdx / 5 * 4, 0)
    insertIdx = idxMin + ((idxMax - idxMin) * frnd()).tointeger()
    if (insertIdx == insertRewardIdx)
      insertIdx++
  }

  let slot = readyItemsArray[insertIdx]
  if (!slot.len())
    slot.append({})
  slot[0] = { reward = getHiddenTopPrizeReward(
    trophyItem, hiddenTopPrizeParams?.show_type ?? "vehicle")
  }
}

function showTopPrize(rewardsArray, handler, rouletteObj, isGotTopPrize) {
  if (!(handler?.isValid() ?? false) || !(rouletteObj?.isValid() ?? false))
    return
  if (!topPrizeLayout)
    return
  if (topPrizeLayout == "" && isGotTopPrize)
    topPrizeLayout = "".join(getCurrentReward(rewardsArray).map(@(p) p.layout), true)

  if (topPrizeLayout == "")
    return

  let obj = rouletteObj.findObject($"roulette_slot_{insertRewardIdx}")
  if (!(obj?.isValid() ?? false))
    return
  let guiScene = rouletteObj.getScene()
  guiScene.replaceContentFromText(obj, topPrizeLayout,
    topPrizeLayout.len(), handler)
}

function createItemsMarkup(completeArray) {
  local result = ""
  foreach (idx, slot in completeArray) {
    let slotRes = []
    let offset = LayersIcon.getOffset(slot.len(), MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET)

    foreach (slotIdx, item in slot)
      slotRes.insert(0,
        LayersIcon.genDataFromLayer(
          { x = $"{offset * slotIdx}@itemWidth", w = "1@itemWidth" },
          item?.reward.layout ?? item?.layout))

    let layerCfg = LayersIcon.findLayerCfg("roulette_slot")
    local width = 1
    if (slot.len() > 1)
      width += offset * (slot.len() - 1)
    layerCfg.w <-$"{width}@itemWidth"
    layerCfg.id <-$"roulette_slot_{idx}"

    result = "".concat(result, LayersIcon.genDataFromLayer(layerCfg, "".join(slotRes, true)))
  }

  return result
}

function initItemsRoulette(trophyName, rewardsArray, imageObj, handler, afterDoneFunc = null) {
  if (!(imageObj?.isValid() ?? false))
    return false

  let placeObj = imageObj.findObject("reward_roullete")
  if (!(placeObj?.isValid() ?? false))
    return false

  resetData()

  let rouletteObj = placeObj.findObject("rewards_list")
  if (!(rouletteObj?.isValid() ?? false))
    return false

  reinitParams()

  let totalLen = to_integer_safe(placeObj?.totalLen, 1)
  let insertRewardFromEnd = to_integer_safe(placeObj?.insertRewardFromEnd, 1)
  insertRewardIdx = totalLen - insertRewardFromEnd - 1
  if (insertRewardIdx < 0 || insertRewardIdx >= totalLen) {
    assert(false, $"Insert index is wrong: {insertRewardIdx} / {totalLen}")
    return false
  }

  let trophyItem = findItemById(trophyName)
  if (!trophyItem || trophyItem.skipRoulette())
    return false

  let trophyData = generateItemsArray(trophyName)
  debugData.trophyData = trophyData

  let trophyArray = trophyData?.trophy ?? []
  if (!hasFeature("ItemsRoulette")
      || trophyArray.len() == 0
      || (trophyArray.len() == 1 && !("trophy" in trophyArray[0]))
     )
    return false

  local isGotTopPrize = false
  foreach (prize in rewardsArray)
    isGotTopPrize = isGotTopPrize || trophyItem.isHiddenTopPrize(prize)

  let processedItemsArray = gatherItemsArray(trophyData, totalLen)

  insertCurrentReward(processedItemsArray, rewardsArray)
  insertHiddenTopPrize(processedItemsArray, trophyItem, isGotTopPrize)

  let data = createItemsMarkup(processedItemsArray)
  placeObj.getScene().replaceContentFromText(rouletteObj, data, data.len(), handler)
  placeObj.show(true)

  updateTransparencyRecursive(placeObj, 0)
  placeObj.animation = "show"

  let blackoutObj = imageObj.findObject("blackout_background")
  if ((blackoutObj?.isValid() ?? false))
    blackoutObj.animation = "show"

  function afterDoneCb() {
    showTopPrize(rewardsArray, handler, rouletteObj, isGotTopPrize)
    afterDoneFunc?()
  }

  let anim = rouletteAnim.get(trophyItem.getOpeningAnimId())
  log($"ItemsRoulette: open trophy {trophyItem.id}, animaton = {anim.id}")
  anim.startAnim(rouletteObj, insertRewardIdx)

  placeObj.getScene().applyPendingChanges(false)
  let timeLeft = rouletteAnim.getTimeLeft(rouletteObj)
  let delay = timeLeft == 0 ? 0.1 : timeLeft
  mainAnimationTimerWeekref = Timer(placeObj, delay, afterDoneCb, handler).weakref()
  return true
}

function skipItemsRouletteAnimation(obj) {
  rouletteAnim.DEFAULT.skipAnim(obj)
  if (mainAnimationTimerWeekref?.ref() != null)
    mainAnimationTimerWeekref.ref().destroy()
}

return {
  initItemsRoulette
  skipItemsRouletteAnimation
}
