from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_game_settings_blk } = require("blkGetters")
let { request } = require("%scripts/inventory/inventoryClient.nut")
let { roundToDigits, floor } = require("%sqstd/math.nut")
let { isArray } = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let { calcTrophiesDropChance } = require("chard")

let chestPrizeChanceCache = {}
let trophyPrizeChanceCache = {}
let requestsCallbacks = {}

function getPrizeChanceConfig(prize) {
  let res = {
    chanceIcon = null
    chanceTooltip = ""
  }

  let weight = prize?.weight ?? "none"
  if (weight == "none")
    return res

  res.chanceIcon = get_game_settings_blk()?.visualizationTrophyWeights[weight].icon
  let chanceName = loc($"item/chance/{weight}")
  res.chanceTooltip = $"{loc("item/chance")}{loc("ui/colon")}{chanceName}"
  return res
}

function getPrizeChanceLegendMarkup() {
  let chancesBlk = get_game_settings_blk()?.visualizationTrophyWeights
  if (chancesBlk == null)
    return ""

  let chances = []
  for (local i = 0; i < chancesBlk.blockCount(); i++) {
    let chanceBlk = chancesBlk.getBlock(i)
    chances.append({
      chanceName = loc($"item/chance/{chanceBlk.getBlockName()}")
      chanceIcon = chanceBlk?.icon
    })
  }
  if (chances.len() == 0)
    return ""

  return handyman.renderCached("%gui/items/prizeChanceLegend.tpl", { chances = chances })
}

function chancesRequestCallBack(generatorId, result) {
  if (result?.response == null) {
    requestsCallbacks.$rawdelete(generatorId)
    return
  }

  let chances = result.response?[generatorId.tostring()]
  let requestCallBacks = requestsCallbacks?[generatorId]
  if (chances) {
    chestPrizeChanceCache[generatorId] <- chances
    if (requestCallBacks != null)
      foreach (callBack in requestCallBacks.callBacks)
        if (callBack != null)
          callBack(chances, generatorId)
  }
  if (requestCallBacks != null)
    requestsCallbacks.$rawdelete(generatorId)
}

function sendGetChancesRequest(generatorId, callBack = null) {
  let requestCallBacks = requestsCallbacks?[generatorId]
  if (requestCallBacks) {
    requestCallBacks.callBacks.append(callBack)
    return
  }

  requestsCallbacks[generatorId] <- {callBacks = [callBack]}
  let requestParams = {itemdefs = generatorId}
  request("GetItemDefChances", requestParams, null, @(result) chancesRequestCallBack(generatorId, result))
}

function getChestChancesData(generatorId, callBack = null) {
  if (chestPrizeChanceCache?[generatorId] != null)
    return chestPrizeChanceCache[generatorId]
  sendGetChancesRequest(generatorId, callBack)
  return null
}

let isTrophyChancesCalculated = @(id, prevOpencount) trophyPrizeChanceCache?[id][id] && trophyPrizeChanceCache?[id].prevOpencount == prevOpencount

function getTrophyChancesData(id, params) {
  if (isTrophyChancesCalculated(id, params.prevOpencount))
    return trophyPrizeChanceCache[id][id]

  let blk = DataBlock()
  calcTrophiesDropChance(blk, [id])
  trophyPrizeChanceCache[id] <- blk
  trophyPrizeChanceCache[id].prevOpencount <- params.prevOpencount

  return trophyPrizeChanceCache[id][id]
}

function grabChanceObjects(objectsByCategory, nest, chancesData) {
  foreach (chanceData in chancesData) {
    if (isArray(chanceData.drop)) {
      grabChanceObjects(objectsByCategory, nest, chanceData.drop)
      continue
    }
    let chanceTextObj = chanceData?.prob
      ? nest.findObject($"chance_{chanceData.drop}")
      : nest.findObject($"chance_{chanceData.from}_{chanceData.drop}")

    if (chanceTextObj == null)
      continue
    let categoryId = chanceTextObj.categoryId
    if (objectsByCategory?[categoryId] == null)
      objectsByCategory[categoryId] <- {hasFraction = false, objects = []}

    let categoryData = objectsByCategory[categoryId]
    let chance = roundToDigits((chanceData?.prob ?? 1)* 100, 2)
    let isFractionChance = (chance - floor(chance)) > 0
    if (!categoryData.hasFraction && isFractionChance)
      categoryData.hasFraction = true

    categoryData.objects.append({obj = chanceTextObj, chance = chance, isFractionChance})
  }
}

function fillChestChances(nest, chancesData) {
  let data = {}
  grabChanceObjects(data, nest, chancesData)

  foreach (_idx, categoryData in data) {
    foreach (object in categoryData.objects) {
      let chanceText = (!object.isFractionChance && categoryData.hasFraction)
        ? $"{object.chance}.0%"
        : $"{object.chance}%"
      object.obj.setValue(chanceText)
      object.obj.show(true)
    }
  }
}

return {
  getChestChancesData
  getTrophyChancesData
  isTrophyChancesCalculated
  fillChestChances
  getPrizeChanceConfig = getPrizeChanceConfig
  getPrizeChanceLegendMarkup = getPrizeChanceLegendMarkup
}