from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { eventbus_send } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadHandler, handlersManager, isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getStringWidthPx, getFontLineHeightPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { addListenersWithoutEnv, add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let trophyRewardListByCategory = require("%scripts/items/listPopupWnd/trophyRewardListByCategory.nut")
let { register_command } = require("console")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { activeUnlocks, receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getFullUnitRoleText } = require("%scripts/unit/unitInfoRoles.nut")
let { getEntitlementConfig, getEntitlementShortName, getEntitlementAmount } = require("%scripts/onlineShop/entitlements.nut")
let { Cost } = require("%scripts/money.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { IPoint2 } = require("dagor.math")
let { setTimeout, clearTimer, defer } = require("dagor.workcycle")
let { frnd } = require("dagor.random")
let { PI, cos, sin, abs } = require("%sqstd/math.nut")
let { enableObjsByTable, activateObjsByTable } = require("%sqDagui/daguiUtil.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getTypeByResourceType } = require("%scripts/customization/types.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getPrizeText } = require("%scripts/items/prizesView.nut")
let { getBuyAndOpenChestWndStyle } = require("%scripts/items/buyAndOpenChestWndStyles.nut")
let regexp2 = require("regexp2")

const NEXT_PRIZE_ANIM_TIMER_ID = "timer_start_prize_animation"
const CHEST_OPEN_FINISHED_ANIM_TIMER_ID = "timer_finish_open_chest_animation"
const CHEST_SHOW_FINISHED_ANIM_TIMER_ID = "timer_finish_show_chest_animation"


let decolorizeRegExp = regexp2(@"\<color(/?[^>]+)>")

let sortIdxItemsByType = [
  itemType.WARPOINTS
  itemType.ORDER
  itemType.WAGER
  itemType.UNIVERSAL_SPARE
  itemType.BOOSTER
  itemType.ENTITLEMENT
  "gold"
  itemType.DECAL
  itemType.ATTACHABLE
  itemType.SKIN
  "loading_screen"
  itemType.PROFILE_ICON
  "multiAwardsOnWorthGold"
  itemType.VEHICLE
  itemType.TROPHY
]

let resourceTypes = {
  decal = itemType.DECAL
  attachable = itemType.ATTACHABLE
  skin = itemType.SKIN
}

let sortIdxPrizeByType = {
  resourceType = {getType = @(prize) resourceTypes?[prize.resourceType] ?? -1}
  warpoints = itemType.WARPOINTS
  gold = "gold"
  unit = itemType.VEHICLE
  multiAwardsOnWorthGold = "multiAwardsOnWorthGold"
  trophy = itemType.TROPHY
  unlock = {
    getType = @(prize) (prize?.unlock.indexof("loading_screen") ?? -1) >= 0
      ? "loading_screen"
      : itemType.PROFILE_ICON
  }
}

function getSortIdxByPrize(prize) {
  foreach (param, _value in prize)
    if (sortIdxPrizeByType?[param])
      return sortIdxItemsByType.indexof(
        sortIdxPrizeByType[param]?.getType(prize) ?? sortIdxPrizeByType[param]) ?? -1

  return -1
}

let additionalSortParamByType = {
  [itemType.WARPOINTS] = @(item, _count = 1) item.getWarpoints(),
  [itemType.BOOSTER] = @(item, _count = 1) item.wpRate > 0 ? item.wpRate : item.xpRate,
  [itemType.ENTITLEMENT] = function(item, _count = 1) {
    let ent = item.getEntitlement()
    let entConfig = getEntitlementConfig(ent)
    return getEntitlementAmount(entConfig)
  },
  [itemType.UNIVERSAL_SPARE] = @(_item, count = 1) count,
  warpoints = @(prize, _count = 1) prize?.warpoints ?? 0,
  gold = @(prize, _count = 1) prize?.gold ?? 0
}

function canGetTrophyPrize(prize) {
  if (prize?.unit) {
    if (prize?.mod)
      return true

    let unit = getAircraftByName(prize.unit)
    let isBought = unit?.isBought() ?? false
    return !isBought
  }

  if (prize?.resourceType) {
    let decoratorType = getTypeByResourceType(prize.resourceType)
    return !decoratorType.isPlayerHaveDecorator(prize?.resource ?? "")
  }

  if (prize?.unlock)
    return !isUnlockOpened(prize.unlock)
  return true
}

function parseTrophyContent(trophy) {
  let content = trophy.getContent()
  local allReceivedPrizes = []
  let availablePrizes = []
  let allPrizes = []

  foreach (trophyPrize in content) {
    if (trophyPrize?.availableIfAllPrizesReceived) {
      allReceivedPrizes.append(trophyPrize)
      continue
    }
    allPrizes.append(trophyPrize)
    if (canGetTrophyPrize(trophyPrize))
      availablePrizes.append(trophyPrize)
  }
  return {allReceivedPrizes, allPrizes, availablePrizes}
}

function getUnitPrizeIcon(unit) {
  if (unit == null)
    return null
  let image = getUnitTooltipImage(unit)
  return "".concat("width:t='1.5@itemWidth'; ",
    LayersIcon.getCustomSizeIconData(image, "1.5@itemWidth, 0.5w"))
}

function getUnitPrizeText(unit, params = null) {
  if (unit == null)
    return null

  let textArr = [
    {
      iconBeforeText = getUnitCountryIcon(unit)
      text = getUnitName(unit)
    }
  ]
  if (params?.isShortText)
    return textArr

  textArr.append(
    {
      text = getFullUnitRoleText(unit)
      textParams = "smallFont:t='yes'"
    }
  )
  return textArr
}

function getWarpointsText(prize) {
  return [
    {
      text = Cost(prize.warpoints).toStringWithParams({ isWpAlwaysShown = true, needIcon = false })
      iconAfterText = "#ui/gameuiskin#item_type_warpoints.svg"
    }
    {
      text = loc("charServer/chapter/warpoints")
      textParams = "smallFont:t='yes'"
    }
  ]
}

function getGoldText(prize) {
  return [
    {
      text = Cost(0, prize.gold).toStringWithParams({ isGoldAlwaysShown = true, needIcon = false })
      iconAfterText = "#ui/gameuiskin#item_type_eagles.svg"
    }
    {
      text = loc("charServer/chapter/eagles")
      textParams = "smallFont:t='yes'"
    }
  ]
}

let offerTypes = {
  trophy = {
    function getPrizeForSort(trophy, params) {
      let parsedContent = params?.parsedContent ?? parseTrophyContent(trophy)
      let {availablePrizes} = parsedContent
      return availablePrizes.len() == 1
        ? availablePrizes[0]
        : trophy.getTopPrize()
    }

    function getPrizeForIcon(trophy, params) {
      let parsedContent = params?.parsedContent ?? parseTrophyContent(trophy)
      let {allPrizes, availablePrizes} = parsedContent

      return availablePrizes.len() == 1
        ? availablePrizes[0]
        : allPrizes.len() == 1 ? allPrizes[0] : trophy
    }

    function getImage(prize, params = {}) {
      let trophy = params?.trophy ?? ::ItemsManager.findItemById(prize.item)
      if (trophy == null)
        return null

      let prizeForIcon = this.getPrizeForIcon(prize, {parsedContent = params?.parsedContent ?? parseTrophyContent(trophy)})
      if (prizeForIcon?.unit) {
        let unit = getAircraftByName(prizeForIcon.unit)
        return getUnitPrizeIcon(unit)
      }
      return "".concat( "width:t='h';", ::trophyReward.getImageByConfig(prizeForIcon, true, ""))
    }

    getPrizeTooltipId = @(prize) getTooltipType("ITEM").getTooltipId(to_integer_safe(prize.item, prize.item))
  }

  unit = {
    function getTextView(prize, params = null) {
      let unit = getAircraftByName(prize.unit)
      return getUnitPrizeText(unit, params)
    }

    function getImage(prize, _params = null) {
      let unit = getAircraftByName(prize.unit)
      return getUnitPrizeIcon(unit)
    }

    getPrizeTooltipId = @(prize) getTooltipType("UNIT").getTooltipId(prize.unit)
  }

  multiAwardsOnWorthGold = {
    function getTextView(prize, _params = null) {
      let premExpMul = prize?.result.premExpMul
      if (premExpMul == null) //Only talisman is supported so far
        return null
      let res = [ { text = loc("modification/premExpMul") } ]
      let unit = getAircraftByName(premExpMul?.unit0 ?? "")
      if (unit != null)
        res.append({
          iconBeforeText = getUnitCountryIcon(unit)
          text = getUnitName(unit)
          textParams = "smallFont:t='yes'"
        })
      return res
    }

    function getImage(prize, _params = null) {
      let premExpMul = prize?.result.premExpMul
      if (premExpMul == null) //Only talisman is supported so far
        return null
      let unit = getAircraftByName(premExpMul?.unit0 ?? "")
      if (unit == null)
        return null

      let image = getUnitTooltipImage(unit)
      return "".concat("width:t='1.5@itemWidth'; ",
        LayersIcon.getCustomSizeIconData(image, "1.5@itemWidth, 0.5w"),
        LayersIcon.getCustomSizeIconData("#ui/gameuiskin#talisman.avif", "0.5ph, 0.5ph", ["0.5pw-0.5w, ph-h"]))
    }
  }
  entitlement = {
    function getTextView(prize, _params = null) {
      let ent = getEntitlementConfig(prize.entitlement)
      if (ent == null)
        return null
      let timeText = "ttl" in ent ? loc("measureUnits/full/days", { n = ent.ttl })
        : "httl" in ent ? loc("measureUnits/full/hours", { n = ent.httl })
        : ""
      return [
        {
          text = timeText != "" ? timeText : null
        }
        {
          text = getEntitlementShortName(ent)
          textParams = "smallFont:t='yes'"
        }
      ]
    }
  }
  item = {
    function getTextView(prize, params = null) {
      local item = params?.item ?? ::ItemsManager.findItemById(prize.item)
      if (item == null)
        return null

      local count = prize?.count ?? 1
      let contentItem = item.getContentItem()
      if (contentItem) {
        count = count * (item?.metaBlk?.count ?? 1)
        item = contentItem
      }

      if (item.iType == itemType.WARPOINTS)
        return getWarpointsText({warpoints = item.getWarpoints()})

      local firstTextConfig = null
      local itemNameText = ""
      if (item.iType == itemType.BOOSTER) {
        let isWpBooster = item.wpRate > 0
        firstTextConfig = {
          text = item._formatEffectText(isWpBooster ? item.wpRate : item.xpRate, "")
          iconAfterText = isWpBooster ? "#ui/gameuiskin#item_type_warpoints.svg"
            : "#ui/gameuiskin#item_type_RP.svg"
        }
        itemNameText = item.getTypeName()
      } else {
        itemNameText = item.getName()
        firstTextConfig = count > 1 ? { text = $"x{count}" } : { text = " " }
      }

      return [
        firstTextConfig
        {
          text = itemNameText
          textParams = "smallFont:t='yes'"
        }
      ]
    }

    function getImage(prize, params = null) {
      local item = params?.item ?? ::ItemsManager.findItemById(prize.item)
      if (item == null)
        return null

      item = item.getContentItem() ?? item
      if (item.iType == itemType.VEHICLE)
        return "".concat( "width:t='1.5@itemWidth';", ::trophyReward.getImageByConfig(prize, true, ""))
      return null
    }

    getPrizeTooltipId = @(prize) getTooltipType("ITEM").getTooltipId(to_integer_safe(prize.item, prize.item))
  }
  warpoints = {
    function getTextView(prize, _params = null) {
      return getWarpointsText(prize)
    }
  },
  gold = {
    function getTextView(prize, _params = null) {
      return getGoldText(prize)
    }
  }
}


function getTrophyText(prize, params = {}) {
  let trophy = params?.trophy ?? ::ItemsManager.findItemById(prize.item)
  if (trophy == null)
    return null

  let parsedContent = params?.parsedContent ?? parseTrophyContent(trophy)
  let {allReceivedPrizes, allPrizes, availablePrizes} = parsedContent

  if (availablePrizes.len() > 1
    || (availablePrizes.len() == 0 && allReceivedPrizes.len() > 1))
    return [
      { text = " "}
      {
        text = trophy.getName()
        textParams = "smallFont:t='yes'"
      }
    ]

  if (availablePrizes.len() == 1) {
    let prizeOfferType = ::trophyReward.getType(availablePrizes[0])
    return offerTypes?[prizeOfferType]
      ? offerTypes[prizeOfferType].getTextView(availablePrizes[0]) ?? []
      : [
          {text = " "}
          {text = getPrizeText(availablePrizes[0], false, false, false), textParams = "smallFont:t='yes'"}
        ]
  }

  let allReceivedPrize = allReceivedPrizes.len() == 1 ? allReceivedPrizes[0] : null

  let recivedPrizeType = allReceivedPrize != null
    ? ::trophyReward.getType(allReceivedPrize)
    : null
  let recivedPrizeText = recivedPrizeType != null
    ? offerTypes?[recivedPrizeType].getTextView(allReceivedPrize) ?? []
    : []

  if (recivedPrizeText.len() == 0)
    return offerTypes.item.getTextView(prize)

  local prizeTexts = null
  if (allPrizes.len() == 1) {
    let trophyPrize = allPrizes[0]
    let prizeOfferType = ::trophyReward.getType(trophyPrize)

    if (offerTypes?[prizeOfferType]) {
      prizeTexts = offerTypes[prizeOfferType].getTextView(trophyPrize, {isShortText = true}) ?? []
    } else {
      let text = getPrizeText(trophyPrize, false, false, false)
      prizeTexts = [{text, textParams = "smallFont:t='yes'", isTextNeedStroke = "yes"}]
    }
  } else
    prizeTexts = offerTypes.item.getTextView(prize)

  let doublePrizeTexts = []
  foreach (val in prizeTexts)
    if (val?.text != "" && val?.text != " ") {
      val.isTextNeedStroke <- "yes"
      doublePrizeTexts.append(val)
    }

  foreach (val in recivedPrizeText)
    if (val?.text != "" && val?.text != " ")
      doublePrizeTexts.append(val)

  return doublePrizeTexts
}

offerTypes.trophy.getTextView <- getTrophyText

let debugPrizes = [
  {
    idx = 201
    roomId = 0
    enabled = true
    entitlement = "PremiumAccount1day"
    time = 1703697380
    isAerobaticSmoke = false
    itemId = 110982370
    itemDefId = 219010
    type = 30
    id = "trophyFromInventory"
    fromInventory = true
  },
  {
    idx = 201
    roomId = 0
    gold = 200
    enabled = true
    time = 1703697382
    isAerobaticSmoke = false
    itemId = 110982371
    itemDefId = 219010
    type = 30
    id = "trophyFromInventory"
    fromInventory = true
  },
  {
    idx = 200
    roomId = 0
    enabled = true
    item = "item_universal_spare"
    count = 5
    time = 1703697381
    isAerobaticSmoke = false
    itemId = 110982372
    itemDefId = 219010
    type = 30
    id = "trophyFromInventory"
    fromInventory = true
  },
  {
    idx = 201
    roomId = 0
    warpoints = 120000
    enabled = true
    time = 1703697382
    isAerobaticSmoke = false
    itemId = 110982371
    itemDefId = 219010
    type = 30
    id = "trophyFromInventory"
    fromInventory = true
  },
  {
    idx = 200
    trophyItemId = 110982379
    trophyItemDefId = 200350
    isAerobaticSmoke = false
    item = "booster_wp_100_3mp"
    id = "@external_inventory_trophy"
    time = 1703697436
    type = 30
    itemDefId = 219010
    parentTrophyRandId = 30132674
    enabled = true
    roomId = 0
  },
  {
    idx = 202
    isAerobaticSmoke = false
    trophyItemId = 110982409
    trophyItemDefId = 200352
    unit = "uk_71ft_mgb"
    count = 1
    enabled = true
    time = 1703697574
    type = 30
    itemDefId = 219010
    parentTrophyRandId = 127264475
    id = "@external_inventory_trophy"
    roomId = 0
  },
   {
    idx = 200
    time = 1703697633
    premExpMul = {
      count = 1
      ranksRange = IPoint2(1, 1)
    }
    trophyItemId = 110982416
    trophyItemDefId = 200341
    isAerobaticSmoke = false
    id = "@external_inventory_trophy"
    multiAwardsOnWorthGold = 0
    result = {
      premExpMul = {
        unit0 = "potez_633"
        mod0 = "premExpMul"
        gold0 = 190
      }
    }
    type = 30
    itemDefId = 219010
    parentTrophyRandId = 60035867
    enabled = true
    roomId = 0
  }
]

local waitingForShowChest = null

let raysForPrizesProps = {
  w = 28, h = 3, moveTime = 250, transpTime = 250, scaleTime = 125,
  timeMult = 1, startDelay = 0, count = 16, rayDelay = 2,
  startRadius = 0, stopRadius = 2, addingAngle = 0
}

let chestShowRaysProps = {
  w = 96, h = 8, moveTime = 250, transpTime = 250, scaleTime = 125,
  timeMult = 1, startDelay = 0, count = 16, rayDelay = 32,
  startRadius = 2, stopRadius = 0, addingAngle = 180
}

let chestShowRaysPropsSecond = {
  w = 96, h = 8, moveTime = 250, transpTime = 250, scaleTime = 125,
  timeMult = 1, startDelay = 16, count = 16, rayDelay = 32,
  startRadius = 2, stopRadius = 0, addingAngle = 180
}

let chestOpenRaysProps = {
  w = 96, h = 9, moveTime = 375, transpTime = 375, scaleTime = 125,
  timeMult = 1, startDelay = 250, count = 16, rayDelay = 15,
  startRadius = 0, stopRadius = 3, addingAngle = 0
}

let chestOpenRaysPropsSecond = {
  w = 96, h = 9, moveTime = 375, transpTime = 375, scaleTime = 125,
  timeMult = 1, startDelay = 290, count = 16, rayDelay = 15,
  startRadius = 0, stopRadius = 3, addingAngle = 0
}

function addRaysInScreenCoords(props, raysArray) {
  let pixelWidth = to_pixels($"{props.w}*@sf/@pf_outdated")
  let pixelHeight = to_pixels($"{props.h}*@sf/@pf_outdated")
  let swWidth = to_pixels("sw")
  let swHeight = to_pixels("sh")
  let widthInPercent = pixelWidth * 100.0 / swWidth
  let heightInPercent = pixelHeight * 100.0 / swHeight
  let timeMult = props.timeMult

  let ySizePercent = pixelWidth * 100.0 / swHeight

  let vx = 1
  let vy = 0
  local delay = props.startDelay

  for (local i = 0; i < props.count; i++) {
    let angle = frnd() * 360
    let radAngle = angle/180*PI

    let dirVector = [
      (vx * cos(radAngle) - vy * sin(radAngle)) * widthInPercent,
      (vy * cos(radAngle) + vx * sin(radAngle)) * ySizePercent
    ]

    let startX = props.startRadius != 0 ? dirVector[0] * props.startRadius : 0
    let startY = props.startRadius != 0 ? dirVector[1] * props.startRadius : 0

    let endX = props.stopRadius != 0 ? dirVector[0] * props.stopRadius : 0
    let endY = props.stopRadius != 0 ? dirVector[1] * props.stopRadius : 0

    raysArray.append(
      { startX, startY, endX, endY, angle = angle + props.addingAngle,
        wp = widthInPercent,
        trDelay = (delay + props.scaleTime)*timeMult,
        posDelay = (delay + props.scaleTime)*timeMult,
        sizeTime = props.scaleTime * timeMult,
        trTime = props.transpTime * timeMult,
        posTime = props.moveTime * timeMult,
        hp = heightInPercent,
        delay = delay * timeMult
      }
    )
    delay += props.rayDelay * timeMult
  }
}

function getPrizesView(prizes, bgDelay = 0) {
  let res = []

  let count = prizes.len()
  let chestItemWidth = min(to_pixels("0.99@rw") / count, to_pixels("1@itemWidth"))
  let margin = (to_pixels("1@rw") - count * chestItemWidth) / (2 * count)

  foreach (prize in prizes) {
    local offerType = ::trophyReward.getType(prize)
    let item = ::ItemsManager.findItemById(prize?.item)
    local sortIdx = -1
    local additionalSortParam = 0

    let params = {item}
    if (item && offerType == "item") {
      let contentItem = item.getContentItem()
      if (contentItem) {
        if (contentItem.iType == itemType.TROPHY) {
          offerType = "trophy"
          params.trophy <- contentItem
          params.parsedContent <- parseTrophyContent(contentItem)

          let trophyPrizeForSort = offerTypes.trophy.getPrizeForSort(contentItem, params) ?? prize
          sortIdx = getSortIdxByPrize(trophyPrizeForSort)

          let rewardType = ::trophyReward.getType(trophyPrizeForSort )
          additionalSortParam = additionalSortParamByType?[rewardType](trophyPrizeForSort) ?? 0
        } else {
          let itemCount = (prize?.count ?? 1) * (item?.metaBlk.count ?? 1)
          sortIdx = sortIdxItemsByType.indexof(contentItem.iType)
          additionalSortParam = additionalSortParamByType?[contentItem.iType](contentItem, itemCount) ?? 0
        }
      }
    }

    if (sortIdx == -1) {
      if (item) {
        sortIdx = sortIdxItemsByType.indexof(item.iType)
        additionalSortParam = additionalSortParamByType?[item.iType](item) ?? 0
      } else {
        sortIdx = getSortIdxByPrize(prize)
        additionalSortParam = additionalSortParamByType?[offerType](prize) ?? 0
      }
    }

    let customImageData = offerTypes?[offerType].getImage(prize, params)
    let text = offerTypes?[offerType].getTextView(prize, params)
    if (text != null)
      foreach (idx, t in text)
        t.idx <- idx.tostring()

    res.append({
      customImageData
      prizeTooltipId =  offerTypes?[offerType].getPrizeTooltipId(prize)
      layeredImage = customImageData != null ? null
       : ::trophyReward.getImageByConfig(prize, true, "")
      textBlock = text
      sortIdx
      additionalSortParam
      margin = clamp(margin, 0, to_pixels("4@blockInterval"))
      chestItemWidth
      chestItemRarityColor = (item && item?.isRare()) ? item.getRarityColor() : "#45AACC"
    })
  }

  res.sort(@(a, b) a.sortIdx <=> b.sortIdx
    || a.additionalSortParam <=> b.additionalSortParam)

  let rays = []
  addRaysInScreenCoords(raysForPrizesProps, rays)

  foreach (prize in res)
    prize["rays"] <- rays

  return { bgDelay,  prizes = res.map(@(val, idx) val.__update({idx})) }
}

function getStageViewData(stageData, currentProgress) {
  let { progress = 0, rewards = null } = stageData
  let itemId = rewards?.keys()[0]
  let item = itemId != null ? ::ItemsManager.findItemById(itemId.tointeger()) : null
  return {
    isOpened = progress <= currentProgress
    stageRequired = progress
    items = [item?.getViewData({
        enableBackground = false
        showAction = false
        showPrice = false
        contentIcon = false
        hasFocusBorder = false
        hasTimer = false
        showRarity = false
        count = rewards[itemId]
      })]
    stageTooltipId = itemId != null ? getTooltipType("ITEM").getTooltipId(itemId.tointeger()) : null
  }
}

let class BuyAndOpenChestHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/buyAndOpenChestWnd.tpl"

  chestItem = null
  styleConfig = null
  hasAlreadyOpened = false
  needOpenChestWhenReceive = false
  isInOpeningProcess = false
  userstatUnlockWatch = null
  curShowPrizeIdx = null
  isChestShowAnimInProgress = false
  isAnimationsInProgress = false
  lastRecivedPrizes = null
  useAmount = 1
  maxUseAmount = 1

  cachedChestShowAnimData = null
  cachedChestOpenAnimData = null

  function getSceneTplView() {
    return {
      chestName = this.chestItem.getName(false)
    }.__update(this.styleConfig)
  }

  function initScreen() {
    if (this.chestItem.getExpireDeltaSec() > 0) {
      this.updateTimeLeftText()
      this.scene.findObject("update_timer").setUserData(this)
    }
    this.scene.findObject("contains_items_txt").setValue(
      loc("trophy/chest_contents/all").replace(":", ""))
    this.initUsestatRewardsOnce()
    this.updateButtons()
    this.updateMaxUseAmount()
    this.updateUseAmountControls()
    this.startChestShowAmim()
  }

  function startChestShowAmim() {
    if (this.cachedChestShowAnimData == null) {
      let rays = []
      addRaysInScreenCoords(chestShowRaysProps, rays)
      addRaysInScreenCoords(chestShowRaysPropsSecond, rays)
      let timeMult = 1.0
      this.cachedChestShowAnimData = handyman.renderCached("%gui/items/chestShowAnim.tpl", {timeMult, rays})
    }

    let chestShowNest = this.scene.findObject("chest_preview")
    this.guiScene.replaceContentFromText( chestShowNest, this.cachedChestShowAnimData, this.cachedChestShowAnimData.len(), this)
    chestShowNest.findObject("show_chest_anim_icon")["background-image"] = this.chestItem.getIconName()

    this.isChestShowAnimInProgress = true
    showObjById("chest_preview", true, this.scene)
    clearTimer(CHEST_SHOW_FINISHED_ANIM_TIMER_ID)
    let cb = Callback(@() this.onShowAnimFinished(), this)
    setTimeout(2, @() cb(), CHEST_SHOW_FINISHED_ANIM_TIMER_ID)
  }

  function onShowAnimFinished() {
    this.isChestShowAnimInProgress = false
    if (this.lastRecivedPrizes != null) {
      this.showReceivedPrizes(this.lastRecivedPrizes)
      this.lastRecivedPrizes = null
    }
  }

  function initUsestatRewardsOnce() {
    let usestatUnlockId = this.chestItem?.itemDef.tags.additionalRewardUnlock
    if (usestatUnlockId == null)
      return

    this.userstatUnlockWatch = Computed(@() activeUnlocks.get()?[usestatUnlockId])
    this.scene.findObject("userstat_rewards_nest").setValue(stashBhvValueConfig([{
      watch = this.userstatUnlockWatch
      updateFunc = Callback(@(obj, unlock) this.updateUsestatRewards(obj, unlock), this)
    }]))
  }

  getActionButtonAmountText = @() this.maxUseAmount > 1 ? $" x{this.useAmount}" : ""
  getInventoryChest = @() ::ItemsManager.getInventoryItemById(this.chestItem.id)
  getCanOpenChest = @()  (this.getInventoryChest()?.amount ?? 0) > 0
  getPrizeObjByIdx = @(idx) this.scene.findObject($"prize_{idx}")

  function updateMaxUseAmount() {
    this.maxUseAmount = this.getCanOpenChest()
      ? min(this.chestItem.getAllowToUseAmount(), this.getInventoryChest().amount)
      : this.chestItem.getAllowToUseAmount()
  }

  function updateUsestatRewards(obj, unlock) {
    let { stages = null, current = 0, isCompleted = false } = unlock
    obj.show(stages != null)
    if (stages == null)
      return

    let maxProgress = stages.top()?.progress ?? 1
    let curProgress = isCompleted ? maxProgress : min(current, maxProgress)
    obj.findObject("progress_text").setValue(
      $"{loc("item/consume/additionalRewardUnlock/progressOfConsume")}{loc("ui/colon")}{curProgress}/{maxProgress}")
    obj.findObject("progress_desc").setValue(
      loc("item/consume/additionalRewardUnlock/desc", { itemName = this.chestItem.getName(false) }))
    showObjById("reward_btn", unlock?.hasReward ?? false, obj)

    let view = { rewards = stages.map(@(stage) getStageViewData(stage, curProgress))}
    let data = handyman.renderCached("%gui/items/buyAndOpenUserstatRewards.tpl", view)
    this.guiScene.replaceContentFromText(obj.findObject("rewards_list"), data, data.len(), this)
  }

  function updateBuyButtonText() {
    let buyText = $"{loc("item/buyAndConsume")}{this.getActionButtonAmountText()}"
    let cost = this.useAmount == 1
      ? this.chestItem.getCost()
      : (Cost() + this.chestItem.getCost()).multiply(this.useAmount)
    setDoubleTextToButton(this.scene, "btn_buy",
      $"{buyText} ({cost.getUncoloredText()})", $"{buyText} ({cost.getTextAccordingToBalance()})")
  }

  function updateOpenButtonText() {
    let openText = this.hasAlreadyOpened ? loc("item/consume/again") : loc("item/consume")
    let amount = this.getActionButtonAmountText()
    setDoubleTextToButton(this.scene, "btn_open", $"{openText}{amount}")
  }

  function updateActionButtonText() {
    if (this.getCanOpenChest())
      this.updateOpenButtonText()
    else
      this.updateBuyButtonText()
  }

  function updateButtons() {
    let needShowWaitImage = this.needOpenChestWhenReceive || this.isInOpeningProcess
    showObjById("wait_image", needShowWaitImage, this.scene)
    if (needShowWaitImage || this.isAnimationsInProgress) {
      showObjById("btn_buy", false, this.scene)
      showObjById("btn_open", false, this.scene)
      return
    }

    let canOpenChest = this.getCanOpenChest()
    if (!canOpenChest && this.chestItem?.isInventoryItem) {
      let chestFromShop = ::ItemsManager.findItemById(to_integer_safe(this.chestItem.id, this.chestItem.id))
      if (chestFromShop != null)
        this.chestItem = chestFromShop
    }

    showObjById("btn_buy", !canOpenChest, this.scene)
    showObjById("btn_open", canOpenChest, this.scene)
    this.updateActionButtonText()
  }

  function updateTimeLeftText() {
    let timeLeftSec = this.chestItem.getExpireDeltaSec()
    let timeExpiredObj = showObjById("time_expired_value", timeLeftSec > 0, this.scene)
    if (timeLeftSec <= 0) {
      this.goBack()
      return
    }

    let timeString = buidPartialTimeStr(timeLeftSec)
    if(getStringWidthPx(timeString, "fontMedium", this.guiScene) > to_pixels("120@sf/@pf"))
      timeExpiredObj["mediumFont"] = "no"
    timeExpiredObj.setValue(timeString)
  }

  function onTimer(_obj, _dt) {
    this.updateTimeLeftText()
  }

  function onUseAmountIncrease() {
    this.useAmount++
    this.updateUseAmountControls()
    this.updateActionButtonText()
  }

  function onUseAmountDecrease() {
    this.useAmount--
    this.updateUseAmountControls()
    this.updateActionButtonText()
  }

  function onSetMaxUseAmount() {
    this.useAmount = this.maxUseAmount
    this.updateUseAmountControls()
    this.updateActionButtonText()
  }

  function onUseAmountSliderChange(obj) {
    this.useAmount = obj.getValue()
    this.updateUseAmountControls()
    this.updateActionButtonText()
  }

  function updateUseAmountControls() {
    let isVisible = this.maxUseAmount > 1
      && !this.needOpenChestWhenReceive && !this.isInOpeningProcess && !this.isAnimationsInProgress
    showObjById("use_amount_controls", isVisible, this.scene)
    if (!isVisible)
      return

    let activeBtnsTbl = {
      use_amount_decrease_btn = this.useAmount > 1
      use_amount_increase_btn = this.useAmount < this.maxUseAmount
      use_amount_max_btn = this.useAmount < this.maxUseAmount
    }
    enableObjsByTable(this.scene, activeBtnsTbl)
    activateObjsByTable(this.scene, activeBtnsTbl)

    this.scene.findObject("use_amount_text").setValue($"{this.useAmount}")
    this.scene.findObject("use_amount_slider").setValue(this.useAmount)
    this.scene.findObject("use_amount_slider").max = this.maxUseAmount
  }

  function onBuy() {
    let itemsCost = Cost(this.chestItem.getCost().wp * this.useAmount)
    if(!checkBalanceMsgBox(itemsCost))
      return

    let cb = Callback(function(res) {
      if (!(res?.success ?? false))
        return

      this.needOpenChestWhenReceive = true
      this.updateButtons()
      this.updateUseAmountControls()
    }, this)
    this.chestItem.buy(cb, null, { amount = this.useAmount, isFromChestWnd = true })
  }

  function onOpen() {
    let inventoryChest = this.getInventoryChest()
    if (inventoryChest == null || inventoryChest.amount == 0 || !inventoryChest.canConsume()) {
      this.updateButtons()
      return
    }

    if (this.hasAlreadyOpened)
      this.startChestShowAmim()

    this.needOpenChestWhenReceive = false
    this.isInOpeningProcess = true
    showObjById("prizes_list", false, this.scene)
    inventoryChest.doMainAction(null, null, {
      shouldSkipMsgBox = true
      showCollectRewardsWaitBox = false
      reciepeExchangeAmount = this.useAmount
      isFromChestWnd = true
    })
  }

  function showChestWithBlinkAnim() {
    showObjById("chest_preview", true, this.scene)
    let chestAnimObj = showObjById("chest_background_blink_anim", true, this.scene)
    chestAnimObj.wink = "fast"
  }

  function startNextPrizeAnimation() {
    if (!this.isValid())
      return
    clearTimer(NEXT_PRIZE_ANIM_TIMER_ID)
    this.curShowPrizeIdx = (this.curShowPrizeIdx ?? -1) + 1
    let prizeObj = this.getPrizeObjByIdx(this.curShowPrizeIdx)
    if (!(prizeObj?.isValid() ?? false)) {
      this.isAnimationsInProgress = false
      showObjById("skip_anim", false, this.scene)
      this.updateButtons()
      this.updateMaxUseAmount()
      this.updateActionButtonText()
      this.updateUseAmountControls()
      return
    }

    let prizeInfoObj = prizeObj.findObject("prize_info")
    prizeInfoObj["transp-time"] = 300
    prizeInfoObj["tooltip"] = "$tooltipObj"
    showObjById("rays", true, prizeObj)
    showObjById("blue_bg", true, prizeObj)
    this.guiScene.playSound("choose")
    let cb = Callback(@() this.startNextPrizeAnimation(), this)
    setTimeout(1, @() cb(), NEXT_PRIZE_ANIM_TIMER_ID)
  }

  function startOpening() {
    this.hasAlreadyOpened = true
    clearTimer(CHEST_OPEN_FINISHED_ANIM_TIMER_ID)
    this.guiScene.playSound("chest_open")

    showObjById("chest_preview", false, this.scene)
    if (this.cachedChestOpenAnimData == null) {
      let outRays = []
      addRaysInScreenCoords(chestOpenRaysProps, outRays)
      addRaysInScreenCoords(chestOpenRaysPropsSecond, outRays)
      let timeMult = 1.0
      this.cachedChestOpenAnimData = handyman.renderCached("%gui/items/chestOpenAnim.tpl", {timeMult, outRays})
    }

    let chestOutNest = this.scene.findObject("chest_out_anim")
    this.guiScene.replaceContentFromText(chestOutNest, this.cachedChestOpenAnimData, this.cachedChestOpenAnimData.len(), this)
    chestOutNest.findObject("open_chest_anim_icon")["background-image"] = this.chestItem.getIconName()

    let cb = Callback(@() this.onOpenAnimFinish(), this)
    setTimeout(2, @() cb(), CHEST_OPEN_FINISHED_ANIM_TIMER_ID)
  }

  function onOpenAnimFinish() {
    if (!this.isValid())
      return
    if (this.curShowPrizeIdx != null) //already started
      return

    this.startNextPrizeAnimation()
  }

  function onSkipAnimations() {
    clearTimer(NEXT_PRIZE_ANIM_TIMER_ID)
    clearTimer(CHEST_OPEN_FINISHED_ANIM_TIMER_ID)
    clearTimer(CHEST_SHOW_FINISHED_ANIM_TIMER_ID)

    this.onShowAnimFinished()

    local curPrizeIdx = 0
    local curPrizeObj = this.getPrizeObjByIdx(curPrizeIdx)
    while (curPrizeObj?.isValid()) {
      let prizeInfoObj = curPrizeObj.findObject("prize_info")
      prizeInfoObj["transp-time"] = 1
      prizeInfoObj["tooltip"] = "$tooltipObj"
      showObjById("rays", true, curPrizeObj)
      showObjById("blue_bg", true, curPrizeObj)
      curPrizeIdx++
      curPrizeObj = this.getPrizeObjByIdx(curPrizeIdx)
    }
    this.curShowPrizeIdx = curPrizeIdx
    this.isAnimationsInProgress = false

    this.updateButtons()
    this.updateUseAmountControls()
    this.updateMaxUseAmount()

    showObjById("skip_anim", false, this.scene)
  }

  function showReceivedPrizes(prizes) {
    this.isInOpeningProcess = false
    this.isAnimationsInProgress = true
    showObjById("skip_anim", true, this.scene)
    if (this.isChestShowAnimInProgress) {
      this.lastRecivedPrizes = prizes
      this.updateButtons()
      return
    }

    let prizesView = getPrizesView(prizes, 300)
    this.decolorizeText(prizesView)
    let data = handyman.renderCached("%gui/items/buyAndOpenChestPrizes.tpl", prizesView)
    let prizeNest = this.scene.findObject("prizes_list")
    this.guiScene.replaceContentFromText(prizeNest, data, data.len(), this)
    let thisHandler = this
    prizeNest.show(true)
    defer(@() thisHandler?.isValid() ? thisHandler.updateStrikeText(prizeNest, prizesView.prizes) : null )
    defer(@() thisHandler?.isValid() ? thisHandler.optimizeShadowsLayer(prizeNest) : null )
    this.updateUseAmountControls()
    this.updateButtons()
    this.curShowPrizeIdx = null
    this.startOpening()
  }

  function decolorizeText(prizesView) {
    foreach (prize in prizesView.prizes)
      foreach (text in prize.textBlock)
        text.text = "".concat("<color=#FFFFFF>", decolorizeRegExp.replace("", text.text), "</color>")
  }

  function optimizeShadowsLayer(prizeNest) {
    if (!prizeNest?.isValid())
      return

    local prizeObj = prizeNest.findObject("prize_0")
    local i = 0;
    while (prizeObj != null) {
      let layer = prizeObj.findObject("bg_icon_layer")
      local shadowsCount = layer.childrenCount()
      let params = {biggestObj = null, square = 0}
      for (local n = 0; n < shadowsCount; n++)
        this.hideNotBiggestShadows(layer.getChild(n), params)

      if (params.biggestObj) {
        shadowsCount = params.biggestObj.childrenCount()
        if ((params.biggestObj?["background-image"] ?? "") != "" || shadowsCount > 1)
          for (local n = 0; n < shadowsCount; n++) {
            let child = params.biggestObj.getChild(n)
            let childSize = child.getSize()
            if (abs(childSize[0] * childSize[1] - params.square) > params.square * 0.05)
              child.show(false)
          }
      }
      i = i + 1
      prizeObj = prizeNest.findObject($"prize_{i}")
    }
  }

  function hideNotBiggestShadows(obj, params) {
    let size = obj.getSize()
    let square = size[0]*size[1]
    let currentSquare = params?.square ?? 0
    if (currentSquare < square) {
      if (params?.biggestObj)
        params.biggestObj.show(false)
      params.biggestObj = obj
      params.square = square
    } else
      obj.show(false)
  }

  function updateStrikeText(prizeNest, prizes) {
    if (!prizeNest?.isValid())
      return
    let normalFontHeight = getFontLineHeightPx("fontNormal") + 1
    let bigFontHeight = getFontLineHeightPx("fontMedium") + 1

    foreach (prize in prizes) {
      local prizeObj = null
      foreach (text in prize.textBlock)
        if (text?.isTextNeedStroke) {
          prizeObj = prizeObj ?? prizeNest.findObject($"prize_{prize.idx}")
          if (!prizeObj.isValid())
            return
          let strokeNest = prizeObj.findObject($"text_block_{text.idx}")
          let isNormalFont = (text?.textParams.indexof("smallFont") ?? 0) > -1
          let strokeStep = isNormalFont ? normalFontHeight : bigFontHeight
          let size = strokeNest.getSize()
          local posY = strokeStep / 2
          local index = 0
          while (posY < size[1] - strokeStep/3) {
            let stroke = strokeNest.findObject($"stroke_{index}")
            if (stroke == null)
              break
            stroke.pos = $"0, {posY}"
            stroke.show(true)
            posY = posY + strokeStep
            index = index + 1
          }
        }
    }
  }

  function onShowRewards() {
    trophyRewardListByCategory({ chestItem = this.chestItem })
  }

  function onReceiveRewards() {
    if (this.userstatUnlockWatch == null)
      return
    let { name = null, hasReward = false} = this.userstatUnlockWatch.get()
    if (hasReward && name != null)
      receiveRewards(name)
  }

  function onEventInventoryUpdate(_p) {
    if (this.needOpenChestWhenReceive)
      this.onOpen()
    else {
      this.updateButtons()
      this.updateUseAmountControls()
    }
  }
}

function showBuyAndOpenChestWnd(chestItem) {
  if (chestItem == null)
    return null

  let styleConfig = getBuyAndOpenChestWndStyle(chestItem)
  if (styleConfig == null)
    return null

  return loadHandler(BuyAndOpenChestHandler, {chestItem, styleConfig})
}

function showBuyAndOpenChestWndById(chestId) {
  if (chestId == null)
    return null

  return showBuyAndOpenChestWnd(::ItemsManager.findItemById(to_integer_safe(chestId, chestId)))
}

function tryOpenChestWindow() {
  if (waitingForShowChest == null)
    return

  if (!isInMenu()) {//no longer need to show the window with the chest after the battle
    waitingForShowChest = null
    return
  }
  let handler = handlersManager.findHandlerClassInScene(BuyAndOpenChestHandler)
  if (handler != null) {//already showed
    waitingForShowChest = null
    return
  }

  let inventoryChest = ::ItemsManager.getInventoryItemById(waitingForShowChest.id)
  if ((inventoryChest?.getAmount() ?? 0) == 0)
    return

  showBuyAndOpenChestWnd(waitingForShowChest)
  waitingForShowChest = null
}

function showBuyAndOpenChestWndWhenReceive(chestItem) {
  if (chestItem == null)
    return

  let styleConfig = getBuyAndOpenChestWndStyle(chestItem)
  if (styleConfig == null)
    return

  let inventoryChest = ::ItemsManager.getInventoryItemById(chestItem.id)
  if ((inventoryChest?.getAmount() ?? 0) == 0) {
    waitingForShowChest = chestItem
    return
  }

  loadHandler(BuyAndOpenChestHandler, { chestItem, styleConfig })
}

gui_handlers.BuyAndOpenChestHandler <- BuyAndOpenChestHandler

addPromoAction("show_buy_and_open_chest_window",
  @(_handler, params, _obj) showBuyAndOpenChestWndById(params?[0]))

addListenersWithoutEnv({
  InventoryUpdate = @(_) tryOpenChestWindow()
})

function openChestOrTrophy(params) {
  let {chest = null, expectedPrizes = null, receivedPrizes = null,
    rewardWndConfig = null} = params
  let chestId = chest?.id ?? params?.chestId
  let rewardsHandler = chest != null
    ? showBuyAndOpenChestWnd(chest)
    : showBuyAndOpenChestWndById(chestId)

  let prizes = receivedPrizes ?? expectedPrizes
  if (prizes == null)
    return

  if (rewardsHandler != null) {
    rewardsHandler.showReceivedPrizes(prizes)
    return
  }

  if (rewardWndConfig == null)
    return

  eventbus_send("guiStartOpenTrophy",
      rewardWndConfig.__update({ [chestId] = prizes }))
}

add_event_listener("openChestWndOrTrophy", openChestOrTrophy)
add_event_listener("showBuyAndOpenChestWndWhenReceive", showBuyAndOpenChestWndWhenReceive)

register_command(showBuyAndOpenChestWndById, "debug.showBuyAndOpenChestWnd")
register_command(function(chestId) {
    let handler = showBuyAndOpenChestWndById(chestId)
    if (handler == null)
      return
    handler.showReceivedPrizes(debugPrizes)
  },
  "debug.showBuyAndOpenChestWndWithDebugPrizes")
