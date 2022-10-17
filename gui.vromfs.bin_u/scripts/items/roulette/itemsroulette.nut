from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let u = require("%sqStdLibs/helpers/u.nut")
let { GUI } = require("%scripts/utils/configs.nut")

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

let ItemGenerators = require("%scripts/items/itemsClasses/itemGenerators.nut")
let rouletteAnim = require("%scripts/items/roulette/rouletteAnim.nut")

let ROULETTE_PARAMS_DEFAULTS = {
  rouletteObj = null
  ownerHandler = null

  trophyItem = null
  insertRewardIdx = 0
  isGotTopPrize = false
  topPrizeLayout = null

  mainAnimationTimer = null
}

let ROULETTE_DEBUG_PARAMS_DEFAULTS = {
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

let function getRandomItem(trophyData) {
  local res = null
  local rndChance = ::math.frnd() * trophyData.trophy.reduce(@(res, v) res + v.dropChance, 0.0)

  foreach (item in trophyData.trophy) {
    res = item
    rndChance -= item.dropChance
    if (rndChance < 0)
      break
  }

  res.dropChance -= res.dropChance * res.multDiff
  return res
}

let function getRandomItems(trophyData) {
  let self = callee()
  return array(trophyData.count, null)
    .map(@(_) getRandomItem(trophyData))
    .reduce(@(acc, v) acc.extend(v?.trophy ? self(v) : [v]), [])
}

::ItemsRoulette <- ROULETTE_PARAMS_DEFAULTS.__merge({debugData = ROULETTE_DEBUG_PARAMS_DEFAULTS})

::ItemsRoulette.resetData <- function resetData()
{
  this.__update(ROULETTE_PARAMS_DEFAULTS)
  this.debugData.__update(ROULETTE_DEBUG_PARAMS_DEFAULTS)
}

::ItemsRoulette.reinitParams <- function reinitParams()
{
  let params = ["items_roulette_multiplier_slots",
                  "items_roulette_min_trophy_drop_mult"]

  local loadParams = false
  foreach(param in params)
  {
    if (getTblValue(param, ::ItemsRoulette, null) == null)
    {
      loadParams = true
      break
    }
  }

  if (!loadParams)
    return

  let blk = GUI.get()
  foreach(param in params)
  {
    let val = blk?[param] ?? 1.0
    ::ItemsRoulette[param] <- val
    ::ItemsRoulette.debugData[param] <- val
  }
}

::ItemsRoulette.logDebugData <- function logDebugData()
{
  log("ItemsRoulette: Print debug data of previously finished roulette")
  debugTableData(::ItemsRoulette.debugData, {recursionLevel = 10})
}

::ItemsRoulette.init <- function init(trophyName, rewardsArray, imageObj, handler, afterDoneFunc = null)
{
  if (!checkObj(imageObj))
    return false

  let placeObj = imageObj.findObject("reward_roullete")
  if (!checkObj(placeObj))
    return false

  resetData()

  rouletteObj = placeObj.findObject("rewards_list")
  if (!checkObj(rouletteObj))
    return false

  reinitParams()

  ownerHandler = handler

  let totalLen = ::to_integer_safe(placeObj?.totalLen, 1)
  let insertRewardFromEnd = ::to_integer_safe(placeObj?.insertRewardFromEnd, 1)
  insertRewardIdx = totalLen - insertRewardFromEnd - 1
  if (insertRewardIdx < 0 || insertRewardIdx >= totalLen)
  {
    assert(false, "Insert index is wrong: " + insertRewardIdx + " / " + totalLen)
    return false
  }

  trophyItem = ::ItemsManager.findItemById(trophyName)
  if (!trophyItem || trophyItem.skipRoulette())
    return false

  let trophyData = ::ItemsRoulette.generateItemsArray(trophyName)
  ::ItemsRoulette.debugData.trophyData = trophyData

  let trophyArray = trophyData?.trophy ?? []
  if (!hasFeature("ItemsRoulette")
      || trophyArray.len() == 0
      || (trophyArray.len() == 1 && !("trophy" in trophyArray[0]))
     )
    return false

  topPrizeLayout = null
  isGotTopPrize = false
  foreach (prize in rewardsArray)
    isGotTopPrize = isGotTopPrize || trophyItem.isHiddenTopPrize(prize)

  let processedItemsArray = ::ItemsRoulette.gatherItemsArray(trophyData, totalLen)

  ::ItemsRoulette.insertCurrentReward(processedItemsArray, rewardsArray)
  ::ItemsRoulette.insertHiddenTopPrize(processedItemsArray)

  let data = createItemsMarkup(processedItemsArray)
  placeObj.getScene().replaceContentFromText(rouletteObj, data, data.len(), handler)
  placeObj.show(true)

  ::updateTransparencyRecursive(placeObj, 0)
  placeObj.animation = "show"

  let blackoutObj = imageObj.findObject("blackout_background")
  if (checkObj(blackoutObj))
    blackoutObj.animation = "show"

  let afterDoneCb = function() {
    ::ItemsRoulette.showTopPrize(rewardsArray)
    afterDoneFunc()
  }

  let anim = rouletteAnim.get(trophyItem.getOpeningAnimId())
  log("ItemsRoulette: open trophy " + trophyItem.id + ", animaton = " + anim.id)
  anim.startAnim(rouletteObj, insertRewardIdx)

  placeObj.getScene().applyPendingChanges(false)
  let delay = rouletteAnim.getTimeLeft(rouletteObj) || 0.1
  mainAnimationTimer = ::Timer(placeObj, delay, afterDoneCb, handler).weakref()
  return true
}

::ItemsRoulette.skipAnimation <- function skipAnimation(obj)
{
  rouletteAnim.DEFAULT.skipAnim(obj)
  if (mainAnimationTimer)
    mainAnimationTimer.destroy()
}

::ItemsRoulette.generateItemsArray <- function generateItemsArray(trophyName)
{
  let trophy = ::ItemsManager.findItemById(trophyName) || ItemGenerators.get(trophyName)
  if (!trophy)
  {
    log("ItemsRoulette: Cannot find trophy by name " + trophyName)
    return {}
  }

  if (trophy?.iType != itemType.TROPHY && trophy?.iType != itemType.CHEST && !trophy?.genType)
  {
    log("ItemsRoulette: Founded item is not a trophy")
    log(trophy.tostring())
    return {}
  }

  let itemsArray = []
  let commonParams = {
    dropChance = 0.0
    multDiff = 0.0
  }

  let debug = {trophy = trophyName}
  let content = trophy.getContentNoRecursion()
  //!!FIX ME: do not use _getContentFixedAmount outside of prizes list. it very specific for prizes stacks description
  let countContent = ::PrizesView._getContentFixedAmount(content)
  let shouldOnlyImage = countContent > 1
  foreach(block in content)
  {
    if (block?.trophy)
    {
      let table = clone commonParams
      let trophyData = ::ItemsRoulette.generateItemsArray(block.trophy)
      table.trophy <- trophyData.trophy
      table.trophyId <- block.trophy
      table.count <- getTblValue("count", block, 1)
      table.rewardsCount <- 0
      table.trophiesCount <- 0
      itemsArray.append(table)
    }
    else
    {
      debug[::ItemsRoulette.getUniqueTableKey(block)] <- 0
      let table = clone commonParams
      table.reward <- block
      table.layout <- ::ItemsRoulette.getRewardLayout(block, shouldOnlyImage)
      itemsArray.append(table)
    }
  }

  ::ItemsRoulette.debugData.result.append(debug)
  return {
    trophy = itemsArray,
    count = 1
  }
}

::ItemsRoulette.getUniqueTableKey <- function getUniqueTableKey(rewardBlock)
{
  if (!rewardBlock)
  {
    ::ItemsRoulette.logDebugData()
    assert(false, "Bad block for unique key")
    return ""
  }

  let tKey = ::trophyReward.getType(rewardBlock)
  let tVal = rewardBlock?[tKey] ?? ""
  return tKey + "_" + tVal
}

::ItemsRoulette.getTopItem <- function getTopItem(trophyBlock)
{
  if ("reward" in trophyBlock)
    return trophyBlock

  return u.isArray(trophyBlock) ? getTopItem(trophyBlock[0])
         : "trophy" in trophyBlock ? getTopItem(trophyBlock.trophy)
         : null
}

::ItemsRoulette.gatherItemsArray <- function gatherItemsArray(trophyData, mainLength)
{
  ::ItemsRoulette.debugData.mainLength = mainLength

  local topItem = ::ItemsRoulette.getTopItem(trophyData.trophy)
  topItem = topItem? clone topItem : null

  let shouldSearchTopReward = topItem?.hasTopRewardAsFirstItem ?? false
  let topRewardKey = ::ItemsRoulette.getUniqueTableKey(topItem?.reward)

  ::ItemsRoulette.fillDropChances(trophyData.trophy)

  local topRewardFound = false
  let resultArray = []
  for (local i = 0; i < mainLength; i++)
  {
    let tablesArray = ::ItemsRoulette.getItemsStack(trophyData)
    foreach(table in tablesArray)
    {
      if (shouldSearchTopReward)
        topRewardFound = topRewardFound || topRewardKey == getTblValue("tKey", table)
    }

    ::ItemsRoulette.debugData.step.append(tablesArray)
    resultArray.append(tablesArray)
  }

  if (shouldSearchTopReward && !topRewardFound)
  {
    local insertIdx = insertRewardIdx + 1 // Interting teaser item next to reward.
    if (insertIdx >= mainLength)
      insertIdx = 0
    log("ItemsRoulette: Top reward by key " + topRewardKey + " not founded." +
         "Insert manually into " + insertIdx + ".")

    let slot = resultArray[insertIdx]
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

::ItemsRoulette.fillDropChances <- function fillDropChances(trophyBlock)
{
  local trophyBlockTrophiesItemsCount = 0

  let isSingleReward = "reward" in trophyBlock
  let isTrophy = "trophy" in trophyBlock

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
      let dropChance = itemsArray[idx].reward?.dropChance.tofloat() ?? 1.0
      ::ItemsRoulette.debugData.beginChances.append({[::ItemsRoulette.getUniqueTableKey(itemsArray[idx].reward)] = dropChance})
      itemsArray[idx].dropChance = dropChance
      itemsArray[idx].multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(false, dropChance)

      if (isSingleReward || !isTrophy)
        continue

      trophyBlock.rewardsCount++
      let dbgTrophyId = "trophy_" + trophyBlock.trophyId
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

  let dbgTrophyNewId = "trophy_" + trophyBlock.trophyId

  let trophyBlockItemsCount = trophyBlock.rewardsCount + trophyBlock.trophiesCount
  let slots = trophyBlockItemsCount * ::ItemsRoulette.items_roulette_multiplier_slots - trophyBlock.rewardsCount
  ::ItemsRoulette.debugData.trophySlots[dbgTrophyNewId] <- slots

  let drop = trophyBlockTrophiesItemsCount > 0? (slots * trophyBlockItemsCount / trophyBlockTrophiesItemsCount) : 0

  let dropTrophy = max(drop, trophyBlockItemsCount * ::ItemsRoulette.items_roulette_min_trophy_drop_mult)

  trophyBlock.dropChance = dropTrophy / getTblValue("count", trophyBlock, 1)
  trophyBlock.multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(true, trophyBlock.dropChance)
  ::ItemsRoulette.debugData.beginChances.append({[dbgTrophyNewId] = trophyBlock.dropChance})

  ::ItemsRoulette.debugData.trophyDrop[dbgTrophyNewId] <- {
    slots = slots
    itemsLen = trophyBlockItemsCount
    trophiesItemsLength = trophyBlockTrophiesItemsCount
    defaultDrop = trophyBlockItemsCount * ::ItemsRoulette.items_roulette_min_trophy_drop_mult
    dropTrophy = dropTrophy
    count = getTblValue("count", trophyBlock, 1)
    dropChance = trophyBlock.dropChance
  }
}

::ItemsRoulette.getItemsStack <- function getItemsStack(trophyData)
{
  let rndItemsArray = getRandomItems(trophyData)

  foreach(item in rndItemsArray)
  {
    let tKey = ::ItemsRoulette.getUniqueTableKey(item?.reward)
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

::ItemsRoulette.getCurrentReward <- function getCurrentReward(rewardsArray)
{
  let res = []
  let shouldOnlyImage = rewardsArray.len() > 1
  foreach(idx, reward in rewardsArray)
  {
    rewardsArray[idx].layout <- ::ItemsRoulette.getRewardLayout(reward, shouldOnlyImage)
    res.append(reward)
  }
  return res
}

::ItemsRoulette.insertCurrentReward <- function insertCurrentReward(readyItemsArray, rewardsArray)
{
  readyItemsArray[insertRewardIdx] = getCurrentReward(rewardsArray)
}

::ItemsRoulette.getHiddenTopPrizeReward <- function getHiddenTopPrizeReward(params)
{
  let showType = params?.show_type ?? "vehicle"
  let layerCfg = clone ::LayersIcon.findLayerCfg("item_place_single")
  layerCfg.img <- $"#ui/gameuiskin#item_{showType}.png"
  let image = ::LayersIcon.genDataFromLayer(layerCfg)
  let layout = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)

  return {
    id = trophyItem.id
    item = null
    layout = layout
  }
}

::ItemsRoulette.insertHiddenTopPrize <- function insertHiddenTopPrize(readyItemsArray)
{
  let hiddenTopPrizeParams = trophyItem.getHiddenTopPrizeParams()
  if (!hiddenTopPrizeParams)
    return

  let showFreq = (hiddenTopPrizeParams?.showFreq ?? "0").tointeger() / 100.0
  let shouldShowTeaser = ::math.frnd() >= 1.0 - showFreq
  if (!isGotTopPrize && !shouldShowTeaser)
    return

  if (isGotTopPrize)
    topPrizeLayout = ::g_string.implode(::u.map(readyItemsArray[insertRewardIdx], @(p) p.layout))

  local insertIdx = 0
  if (isGotTopPrize)
    insertIdx = insertRewardIdx
  else
  {
    let idxMax = insertRewardIdx
    let idxMin = max(insertRewardIdx /5*4, 0)
    insertIdx = idxMin + ((idxMax - idxMin) * ::math.frnd()).tointeger()
    if (insertIdx == insertRewardIdx)
      insertIdx++
  }

  let slot = readyItemsArray[insertIdx]
  if (!slot.len())
    slot.append({})
  slot[0] = { reward = ::ItemsRoulette.getHiddenTopPrizeReward(hiddenTopPrizeParams) }
}

::ItemsRoulette.showTopPrize <- function showTopPrize(rewardsArray)
{
  if (!topPrizeLayout)
    return
  if (topPrizeLayout == "" && isGotTopPrize)
    topPrizeLayout = ::g_string.implode(::u.map(getCurrentReward(rewardsArray), @(p) p.layout))

  if (topPrizeLayout == "")
    return

  let obj = checkObj(rouletteObj) && rouletteObj.findObject("roulette_slot_" + insertRewardIdx)
  if (!checkObj(obj))
    return
  let guiScene = rouletteObj.getScene()
  guiScene.replaceContentFromText(obj, topPrizeLayout, topPrizeLayout.len(), ownerHandler)
}

::ItemsRoulette.createItemsMarkup <- function createItemsMarkup(completeArray)
{
  local result = ""
  foreach(idx, slot in completeArray)
  {
    let slotRes = []
    let offset = ::LayersIcon.getOffset(slot.len(), MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET)

    foreach(slotIdx, item in slot)
      slotRes.insert(0,
        ::LayersIcon.genDataFromLayer(
          { x = (offset * slotIdx) + "@itemWidth", w = "1@itemWidth" },
          item?.reward?.layout ?? item?.layout))

    let layerCfg = ::LayersIcon.findLayerCfg("roulette_slot")
    local width = 1
    if (slot.len() > 1)
      width += offset * (slot.len() - 1)
    layerCfg.w <- width + "@itemWidth"
    layerCfg.id <- "roulette_slot_" + idx

    result += ::LayersIcon.genDataFromLayer(layerCfg, ::g_string.implode(slotRes))
  }

  return result
}

::ItemsRoulette.getRewardLayout <- function getRewardLayout(block, shouldOnlyImage = false)
{
  let config = block?.reward.reward ?? block
  let rType = ::trophyReward.getType(config)
  if (::trophyReward.isRewardItem(rType))
    return ::trophyReward.getImageByConfig(config, shouldOnlyImage, "roulette_item_place")

  let image = ::trophyReward.getImageByConfig(config, shouldOnlyImage, "item_place_single")
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)
}

::ItemsRoulette.getChanceMultiplier <- function getChanceMultiplier(isTrophy, dropChance)
{
  local chanceMult = 0.5
  if (isTrophy)
    chanceMult = ::pow(0.5, 1.0/dropChance)
  return chanceMult
}
