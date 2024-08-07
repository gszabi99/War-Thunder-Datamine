from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadHandler, handlersManager, isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let trophyRewardListByCategory = require("%scripts/items/listPopupWnd/trophyRewardListByCategory.nut")
let { register_command } = require("console")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { activeUnlocks, receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { getFullUnitRoleText, getUnitTooltipImage, getUnitClassColor } = require("%scripts/unit/unitInfoTexts.nut")
let { getEntitlementConfig, getEntitlementShortName } = require("%scripts/onlineShop/entitlements.nut")
let { Cost } = require("%scripts/money.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { IPoint2 } = require("dagor.math")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { frnd } = require("dagor.random")
let { PI, cos, sin } = require("%sqstd/math.nut")
let { enableObjsByTable, activateObjsByTable } = require("%sqDagui/daguiUtil.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")

const NEXT_PRIZE_ANIM_TIMER_ID = "timer_start_prize_animation"
const CHEST_OPEN_FINISHED_ANIM_TIMER_ID = "timer_finish_open_chest_animation"
const CHEST_SHOW_FINISHED_ANIM_TIMER_ID = "timer_finish_show_chest_animation"

let buyAndOpenChestWndStyles = {
  newYear23 = {
    headerBackgroundImage = "!ui/images/chests_wnd/golden_new_year_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/golden_new_year_header"
    headerBackgroundImageHeight = "512.0/2420w"
    headerBackgroundImageMaxHeight = "0.43ph"
    bgCornersShadowSize = "3((sw - 1@swOrRwInVr) $max (sw - 2420.0*0.43sh/512)), sh"
    timeExpiredTextParams = "pos:t='0.75pw, 0.4ph-0.5h'"
  }
  silverCommon = {
    headerBackgroundImage = "!ui/images/chests_wnd/silver_common_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/silver_common_header"
    headerBackgroundImageHeight = "720.0/1920w"
    headerBackgroundImageMaxHeight = "0.70ph"
    bgCornersShadowSize = "3((sw - 1@swOrRwInVr) $max (sw - 1920.0*0.70sh/720)), sh"
    timeExpiredTextParams="pos:t='0.65pw, 0.41ph-0.5h'; overlayTextColor:t='active'"
    chestNameTextParams="font-ht:t='40@sf/@pf'"
  }
  silverSummer = {
    headerBackgroundImage = "!ui/images/chests_wnd/silver_summer_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/silver_summer_header"
    headerBackgroundImageHeight = "720.0/1920w"
    headerBackgroundImageMaxHeight = "0.70ph"
    bgCornersShadowSize = "3((sw - 1@swOrRwInVr) $max (sw - 1920.0*0.70sh/720)), sh"
    timeExpiredTextParams="pos:t='0.75pw, 0.41ph-0.5h'; overlayTextColor:t='active'"
    chestNameTextParams="font-ht:t='40@sf/@pf'"
  }
}

enum sortIdxPrizesByType {
  warpoints
  entitlement
  item
  gold
  multiAwardsOnWorthGold
  unit
}

local waitingForShowChest = null

let offerTypes = {
  unit = {
    function getTextView(prize) {
      let unit = getAircraftByName(prize.unit)
      if (unit == null)
        return null
      return [
        {
          iconBeforeText = getUnitCountryIcon(unit)
          text = colorize("@activeTextColor", getUnitName(unit))
        }
        {
          text = colorize(getUnitClassColor(unit), getFullUnitRoleText(unit))
          textParams = "smallFont:t='yes'"
        }
      ]
    }
    function getImage(prize) {
      let unit = getAircraftByName(prize.unit)
      if (unit == null)
        return null

      let image = getUnitTooltipImage(unit)
      return "".concat("width:t='1.5@itemWidth'; ",
        LayersIcon.getCustomSizeIconData(image, "1.5@itemWidth, 0.5w"))
    }

    getPrizeTooltipId = @(prize) getTooltipType("UNIT").getTooltipId(prize.unit)
  }
  multiAwardsOnWorthGold = {
    function getTextView(prize) {
      let premExpMul = prize?.result.premExpMul
      if (premExpMul == null) //Only talisman is supported so far
        return null
      let res = [ { text = colorize("@activeTextColor", loc("modification/premExpMul")) } ]
      let unit = getAircraftByName(premExpMul?.unit0 ?? "")
      if (unit != null)
        res.append({
          iconBeforeText = getUnitCountryIcon(unit)
          text = colorize(getUnitClassColor(unit), getUnitName(unit))
          textParams = "smallFont:t='yes'"
        })
      return res
    }

    function getImage(prize) {
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
    function getTextView(prize) {
      let ent = getEntitlementConfig(prize.entitlement)
      if (ent == null)
        return null
      let timeText = "ttl" in ent ? loc("measureUnits/full/days", { n = ent.ttl })
        : "httl" in ent ? loc("measureUnits/full/hours", { n = ent.httl })
        : ""
      return [
        {
          text = timeText != "" ? colorize("@activeTextColor", timeText) : null
        }
        {
          text = colorize("@userlogColoredText", getEntitlementShortName(ent))
          textParams = "smallFont:t='yes'"
        }
      ]
    }
  }
  item = {
    function getTextView(prize) {
      local item = ::ItemsManager.findItemById(prize.item)
      if (item == null)
        return null

      local count = prize?.count ?? 1
      let contentItem = item.getContentItem()
      if (contentItem) {
        count = count * (item?.metaBlk?.count ?? 1)
        item = contentItem
      }

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
        firstTextConfig = count > 1 ? { text = colorize("@activeTextColor", $"x{count}") } : { text = " " }
      }

      return [
        firstTextConfig
        {
          text = colorize("@activeTextColor", itemNameText)
          textParams = "smallFont:t='yes'"
        }
      ]
    }

    getPrizeTooltipId = @(prize) getTooltipType("ITEM").getTooltipId(to_integer_safe(prize.item, prize.item))
  }
  warpoints = {
    function getTextView(prize) {
      return [
        {
          text = colorize("@activeTextColor",
            Cost(prize.warpoints).toStringWithParams({ isWpAlwaysShown = true, needIcon = false }))
          iconAfterText = "#ui/gameuiskin#item_type_warpoints.svg"
        }
        {
          text = colorize("@activeTextColor", loc("charServer/chapter/warpoints"))
          textParams = "smallFont:t='yes'"
        }
      ]
    }
  },
  gold = {
    function getTextView(prize) {
      return [
        {
          text = colorize("@activeTextColor",
            Cost(0, prize.gold).toStringWithParams({ isGoldAlwaysShown = true, needIcon = false }))
          iconAfterText = "#ui/gameuiskin#item_type_eagles.svg"
        }
        {
          text = colorize("@userlogColoredText", loc("charServer/chapter/eagles"))
          textParams = "smallFont:t='yes'"
        }
      ]
    }
  },
}

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
    let offerType = ::trophyReward.getType(prize)
    let customImageData = offerTypes?[offerType].getImage(prize)
    let item = ::ItemsManager.findItemById(prize?.item)
    res.append({
      customImageData
      prizeTooltipId =  offerTypes?[offerType].getPrizeTooltipId(prize)
      layeredImage = customImageData != null ? null
       : ::trophyReward.getImageByConfig(prize, true, "")
      textBlock = offerTypes?[offerType].getTextView(prize)
      sortIdx = sortIdxPrizesByType?[offerType] ?? 0
      additionalSortParam = prize?[offerType] ?? ""
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

    prizeObj.findObject("prize_info")["transp-time"] = 300
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
      curPrizeObj.findObject("prize_info")["transp-time"] = 1
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

    let data = handyman.renderCached("%gui/items/buyAndOpenChestPrizes.tpl", getPrizesView(prizes, 300))
    this.guiScene.replaceContentFromText(this.scene.findObject("prizes_list"), data, data.len(), this)
    showObjById("prizes_list", true, this.scene)
    this.updateUseAmountControls()
    this.updateButtons()
    this.curShowPrizeIdx = null
    this.startOpening()
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

let getBuyAndOpenChestWndStyle = @(item) buyAndOpenChestWndStyles?[item?.itemDef.tags.openingWndStyle ?? ""]

function showBuyAndOpenChestWnd(chestItem) {
  if (chestItem == null)
    return null

  let styleConfig = getBuyAndOpenChestWndStyle(chestItem)
  if (styleConfig == null)
    return null

  return loadHandler(BuyAndOpenChestHandler, { chestItem, styleConfig})
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

register_command(showBuyAndOpenChestWndById, "debug.showBuyAndOpenChestWnd")
register_command(function(chestId) {
    let handler = showBuyAndOpenChestWndById(chestId)
    if (handler == null)
      return
    handler.showReceivedPrizes(debugPrizes)
  },
  "debug.showBuyAndOpenChestWndWithDebugPrizes")

return {
  showBuyAndOpenChestWnd
  showBuyAndOpenChestWndById
  showBuyAndOpenChestWndWhenReceive
  getBuyAndOpenChestWndStyle
}