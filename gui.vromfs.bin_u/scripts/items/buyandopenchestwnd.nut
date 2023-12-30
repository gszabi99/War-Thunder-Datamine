//checked for plus_string
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
let { ITEM } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { getFullUnitRoleText, getUnitTooltipImage, getUnitClassColor } = require("%scripts/unit/unitInfoTexts.nut")
let { getEntitlementConfig, getEntitlementShortName } = require("%scripts/onlineShop/entitlements.nut")
let { Cost } = require("%scripts/money.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { IPoint2 } = require("dagor.math")
let { setTimeout, clearTimer } = require("dagor.workcycle")

const NEXT_PRIZE_ANIM_TIMER_ID = "timer_start_prize_animation"
const CHEST_OPEN_FINISHED_ANIM_TIMER_ID = "timer_finish_open_chest_animation"

let buyAndOpenChestWndStyles = {
  newYear23 = {
    headerBackgroundImage = "!ui/images/chests_wnd/golden_new_year_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/golden_new_year_header"
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
      let item = ::ItemsManager.findItemById(prize.item)
      if (item == null)
        return null
      local firstTextConfig = { text = colorize("@activeTextColor", $"x{prize?.count ?? 1}") }
      if (item.iType == itemType.BOOSTER) {
        let isWpBooster = item.wpRate > 0
        firstTextConfig = {
          text = item._formatEffectText(isWpBooster ? item.wpRate : item.xpRate, "")
          iconAfterText = isWpBooster ? "#ui/gameuiskin#item_type_warpoints.svg"
            : "#ui/gameuiskin#item_type_RP.svg"
        }
      }
      return [
        firstTextConfig
        {
          text = colorize("@activeTextColor", item.getTypeName())
          textParams = "smallFont:t='yes'"
        }
      ]
    }
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


function getPrizesView(prizes) {
  let res = []
  foreach (prize in prizes) {
    let offerType = ::trophyReward.getType(prize)
    let customImageData = offerTypes?[offerType].getImage(prize)
    res.append({
      customImageData
      layeredImage = customImageData != null ? null
       : ::trophyReward.getImageByConfig(prize, true, "")
      textBlock = offerTypes?[offerType].getTextView(prize)
      sortIdx = sortIdxPrizesByType?[offerType] ?? 0
      additionalSortParam = prize?[offerType] ?? ""
    })
  }
  res.sort(@(a, b) a.sortIdx <=> b.sortIdx
    || a.additionalSortParam <=> b.additionalSortParam)
  return { prizes = res.map(@(val, idx) val.__update({idx})) }
}

let function getStageViewData(stageData, currentProgress) {
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
    stageTooltipId = itemId != null ? ITEM.getTooltipId(itemId.tointeger()) : null
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

  function getSceneTplView() {
    return {
      headerBackgroundImage = this.styleConfig.headerBackgroundImage
      chestNameBackgroundImage = this.styleConfig.chestNameBackgroundImage
      chestName = this.chestItem.getName(false)
      chestIcon = this.chestItem.getIcon()
    }
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

  function updateButtons() {
    let needShowWaitImage = this.needOpenChestWhenReceive || this.isInOpeningProcess
    showObjById("wait_image", needShowWaitImage, this.scene)
    if (needShowWaitImage) {
      showObjById("btn_buy", false, this.scene)
      showObjById("btn_open", false, this.scene)
      return
    }

    let inventoryChest = ::ItemsManager.getInventoryItemById(this.chestItem.id)
    let canOpenChest = inventoryChest != null && inventoryChest.amount > 0
    showObjById("btn_buy", !canOpenChest, this.scene)
    showObjById("btn_open", canOpenChest, this.scene)
    if (!canOpenChest) {
      let buyText = loc("item/buyAndConsume")
      let cost = this.chestItem.getCost()
      setDoubleTextToButton(this.scene, "btn_buy",
        $"{buyText} ({cost.getUncoloredText()})", $"{buyText} ({cost.getTextAccordingToBalance()})")
    }
    else
      setDoubleTextToButton(this.scene, "btn_open",
        this.hasAlreadyOpened ? loc("item/consume/again") : loc("item/consume"))
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

  function onBuy() {
    let cb = Callback(function(res) {
      if (!(res?.success ?? false))
        return

      this.needOpenChestWhenReceive = true
      this.updateButtons()
    }, this)
    this.chestItem.buy(cb, null, { amount = 1 })
  }

  function onOpen() {
    let inventoryChest = ::ItemsManager.getInventoryItemById(this.chestItem.id)
    if (inventoryChest == null || inventoryChest.amount == 0 || !inventoryChest.canConsume()) {
      this.updateButtons()
      return
    }

    this.hasAlreadyOpened = true
    this.needOpenChestWhenReceive = false
    this.isInOpeningProcess = true
    this.showChestWithBlinkAnim()
    showObjById("prizes_list", false, this.scene)
    inventoryChest.doMainAction(null, null, { shouldSkipMsgBox = true, showCollectRewardsWaitBox = false })
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
    let prizeObj = this.scene.findObject($"prize_{this.curShowPrizeIdx}")
    if (!(prizeObj?.isValid() ?? false)) {
      this.isInOpeningProcess = false
      this.updateButtons()
      return
    }
    prizeObj.findObject("prize_background")["transp-time"] = 150
    prizeObj.findObject("prize_info")["transp-time"] = 800
    this.guiScene.playSound("choose")
    let cb = Callback(@() this.startNextPrizeAnimation(), this)
    setTimeout(0.8, @() cb(), NEXT_PRIZE_ANIM_TIMER_ID)
  }

  function startOpening() {
    clearTimer(CHEST_OPEN_FINISHED_ANIM_TIMER_ID)
    let animObj = this.scene.findObject("open_chest_animation")
    animObj.animation = "show"
    this.guiScene.playSound("chest_open")
    let cb = Callback(@() this.onOpenAnimFinish(), this)
    setTimeout(1.0, @() cb(), CHEST_OPEN_FINISHED_ANIM_TIMER_ID)
  }

  function onOpenAnimFinish() {
    if (!this.isValid())
      return
    if (this.curShowPrizeIdx != null) //already started
      return
    showObjById("chest_preview", false, this.scene)
    let animObj = this.scene.findObject("open_chest_animation")
    animObj.animation = "hide"
    this.startNextPrizeAnimation()
  }

  function showReceivedPrizes(prizes) {
    this.isInOpeningProcess = true
    this.showChestWithBlinkAnim()
    let data = handyman.renderCached("%gui/items/buyAndOpenChestPrizes.tpl", getPrizesView(prizes))
    this.guiScene.replaceContentFromText(this.scene.findObject("prizes_list"), data, data.len(), this)
    showObjById("prizes_list", true, this.scene)
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
    else
      this.updateButtons()
  }
}

let getBuyAndOpenChestWndStyle = @(item) buyAndOpenChestWndStyles?[item?.itemDef.tags.openingWndStyle ?? ""]

function showBuyAndOpenChestWnd(chestItem) {
  if (chestItem == null)
    return null

  let styleConfig = getBuyAndOpenChestWndStyle(chestItem)
  if (styleConfig == null)
    return null

  return loadHandler(BuyAndOpenChestHandler, { chestItem, styleConfig })
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
}