//-file:plus-string

//checked for explicitness
#no-root-fallback
#explicit-this

from "%scripts/dagui_library.nut" import *
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let sheets = require("%scripts/items/itemsShopSheets.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let { canStartPreviewScene, getDecoratorDataToUse, useDecorator } = require("%scripts/customization/contentPreview.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let { findGenByReceptUid } = require("%scripts/items/itemsClasses/itemGenerators.nut")
let { isLoadingBgUnlock, getLoadingBgIdByUnlockId } = require("%scripts/loading/loadingBgData.nut")
let preloaderOptionsModal = require("%scripts/options/handlers/preloaderOptionsModal.nut")
let { register_command } = require("console")
let { initItemsRoulette, skipItemsRouletteAnimation } = require("%scripts/items/roulette/itemsRoulette.nut")
let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")

register_command(
  function () {
    let item = ::ItemsManager.getItemsList()?[0]
    if (item == null)
      return console_print("Not found any shop item to show window")

    return ::gui_start_open_trophy({
      rewardImageRatio = 1.778
      isDisassemble = false
      rewardTitle = "workshop/craft_2022_spring/craft_tree/btn_victory"
      rewardListLocId = ""
      rewardImage = "https://static-ggc.gaijin.net/events/craft_battle_for_arachis/craft_win"
      singleAnimationGuiSound = "gui_music_win",
      [2905356] = [
        {
          item = ::ItemsManager.getItemsList()[0]
          id = ::ItemsManager.getItemsList()[0].id
          count = 1
        }
      ]
      reUseRecipeUid = null
      isHidePrizeActionBtn = false
    })
  },
  "ui.debug_trophy_reward_with_image")

let function afterCloseTrophyWnd(configsTable) {
  if(configsTable.len()>0)
    ::gui_start_open_trophy(configsTable)
  else
    ::broadcastEvent("TrophyWndClose", {})
}

::gui_start_open_trophy <- function gui_start_open_trophy(configsTable = {}) {
  if (configsTable.len() == 0)
    return

  local localConfigsTable = clone configsTable;

  let params = {}
  foreach (paramName in [ "rewardTitle", "rewardListLocId", "rewardIcon", "isDisassemble",
    "isHidePrizeActionBtn", "singleAnimationGuiSound", "rewardImage", "rewardImageRatio",
    "reUseRecipeUid" ]) {
    if (!(paramName in localConfigsTable))
      continue

    params[paramName] <- localConfigsTable[paramName]
    localConfigsTable.rawdelete(paramName)
  }

  local tKey = ""
  foreach (idx, _configsArray in localConfigsTable) {
    tKey = idx
    break
  }

  let configsArray = localConfigsTable[tKey]
  if (configsArray.len() == 0)
    return

  delete localConfigsTable[tKey]
  configsArray.sort(::trophyReward.rewardsSortComparator)

  let itemId = configsArray?[0]?.itemDefId
    ?? configsArray?[0]?.trophyItemDefId
    ?? configsArray?[0]?.displayId
    ?? configsArray?[0]?.id
    ?? ""

  let trophyItem = ::ItemsManager.findItemById(itemId)
  if (!trophyItem) {
    let configsArrayString = toString(configsArray, 2) // warning disable: -declared-never-used
    let isLoggedIn = ::g_login.isLoggedIn()              // warning disable: -declared-never-used
    let { dbgTrophiesListInternal, dbgLoadedTrophiesCount, itemsListInternal, // warning disable: -declared-never-used
      dbgLoadedItemsInternalCount, dbgUpdateInternalItemsCount // warning disable: -declared-never-used
    } = ::ItemsManager.getInternalItemsDebugInfo()  // warning disable: -declared-never-used
    let trophiesBlk = ::get_price_blk()?.trophy
    let currentItemsInternalCount = itemsListInternal.len() // warning disable: -declared-never-used
    let currentTrophiesInternalCount = dbgTrophiesListInternal.len() // warning disable: -declared-never-used
    let trophiesListInternalString = toString(dbgTrophiesListInternal)  // warning disable: -declared-never-used
    let trophiesBlkString = toString(trophiesBlk)  // warning disable: -declared-never-used
    local trophyBlkString = toString(trophiesBlk?[itemId]) // warning disable: -declared-never-used

    ::script_net_assert_once("not found trophyItem", "Trophy Reward: Not found item. Don't show reward.")
    return
  }

  params.trophyItem <- trophyItem
  params.configsArray <- configsArray
  params.afterFunc <- @() afterCloseTrophyWnd(localConfigsTable)
  ::gui_start_modal_wnd(::gui_handlers.trophyRewardWnd, params)
}

::gui_handlers.trophyRewardWnd <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/trophyReward.blk"

  configsArray = null
  afterFunc = null

  shrinkedConfigsArray = null
  trophyItem = null
  isBoxOpening = true
  shouldShowRewardItem = false
  isDisassemble = false

  haveItems = false
  rewardItem = null //reward item to show button "go to item"
  isRewardItemActual = false //reward item cn be received, but not visible.
  opened = false
  animFinished = false

  useSingleAnimation = true

  unit = null
  rentTimeHours = 0

  slotbarActions = [ "take", "sec_weapons", "weapons", "info" ]

  decorator = null
  decoratorUnit = null
  decoratorSlot = -1
  rewardTitle = null
  rewardListLocId = null
  rewardIcon = null
  isHidePrizeActionBtn = false
  singleAnimationGuiSound = null
  rewardImage = null
  rewardImageRatio = 1
  reUseRecipeUid = null
  reUseRecipe = null

  function initScreen() {
    this.configsArray = this.configsArray ?? []
    this.rewardTitle = this.rewardTitle ?? this.configsArray?[0].rewardTitle
    this.rewardListLocId = this.configsArray?[0].rewardListLocId ?? this.rewardListLocId

    if (this.rewardImage != null)
      this.scene.findObject("reward_frame").width = "@chestRewardFrameWidth"

    this.prepareParams()

    this.setTitle()
    this.checkConfigsArray()
    this.updateRewardItem()
    this.updateWnd()
    this.startOpening()

    this.scene.findObject("update_timer").setUserData(this)
  }

  function prepareParams() {
    this.shouldShowRewardItem = this.trophyItem.iType == itemType.RECIPES_BUNDLE
    this.isBoxOpening = !this.shouldShowRewardItem
      && (this.trophyItem.iType == itemType.TROPHY
         || this.trophyItem.iType == itemType.CHEST
         || this.trophyItem.iType == itemType.CRAFT_PROCESS
         || this.trophyItem.iType == itemType.CRAFT_PART)

    this.shrinkedConfigsArray = ::trophyReward.processUserlogData(this.configsArray)
    if (this.reUseRecipeUid != null)
      this.reUseRecipe = findGenByReceptUid(this.reUseRecipeUid)?.getRecipeByUid?(this.reUseRecipeUid)
  }

  function setTitle() {
    let title = this.getTitle()

    let titleObj = this.scene.findObject("reward_title")
    titleObj.setValue(title)
    if (daguiFonts.getStringWidthPx(title, "fontMedium", this.guiScene) >
      to_pixels("1@trophyWndWidth - 1@buttonCloseHeight"))
      titleObj.caption = "no"
  }

  getTitle = @() this.rewardTitle && this.rewardTitle != "" ? this.rewardTitle
    : this.isDisassemble && !this.shouldShowRewardItem ? this.trophyItem.getDissasembledCaption()
    : this.isCreation() ? this.trophyItem.getCreationCaption()
    : this.trophyItem.getOpeningCaption()

  isRouletteStarted = @() initItemsRoulette(
    this.trophyItem.id,
    this.configsArray,
    this.scene,
    this,
    function() {
      this.openChest.call(this)
      this.onOpenAnimFinish.call(this)
    }
  )

  function startOpening() {
    if (this.isRouletteStarted())
      this.useSingleAnimation = false

    ::showBtn(this.useSingleAnimation ? "reward_roullete" : "open_chest_animation", false, this.scene) //hide not used animation
    let animId = this.useSingleAnimation ? "open_chest_animation" : "reward_roullete"
    let animObj = this.scene.findObject(animId)
    if (checkObj(animObj)) {
      animObj.animation = this.rewardImage == null ? "show" : "hide"
      if (this.useSingleAnimation) {
        this.guiScene.playSound(this.singleAnimationGuiSound ?? "chest_open")
        let delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
        ::Timer(animObj, 0.001 * delay, this.openChest, this)
        ::Timer(animObj, 1.0, this.onOpenAnimFinish, this) //!!FIX ME: Some times animation finish not apply css, and we miss onOpenAnimFinish
      }
    }
    else
      this.openChest()
  }

  function openChest() {
    if (this.opened)
      return false
    let obj = this.scene.findObject("rewards_list")
    skipItemsRouletteAnimation(obj)
    this.opened = true
    this.updateWnd()
    this.notifyTrophyVisible()
    return true
  }

  notifyTrophyVisible = @() ::broadcastEvent("TrophyContentVisible", { trophyItem = this.trophyItem })

  function updateWnd() {
    this.updateImage()
    this.updateRewardText()
    this.updateRewardPostscript()
    this.updateButtons()
  }

  function getIconData() {
    local itemToShow = this.trophyItem
    if (this.shouldShowRewardItem && this.configsArray[0]?.item)
      itemToShow = ::ItemsManager.findItemById(this.configsArray[0].item)

    local layersData = ""
    if (this.isBoxOpening && (this.opened || this.useSingleAnimation)) {
      layersData = itemToShow.getOpenedBigIcon()
      if (this.opened && this.useSingleAnimation)
        layersData += this.getRewardImage(itemToShow.iconStyle)
    }
    else
      layersData = itemToShow.getBigIcon()

    return layersData
  }

  function getForceStyleImage() {
    if (!this.rewardIcon)
      return null

    let trophyStyle = $"{this.rewardIcon}{this.opened ? "_opened" : ""}"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyStyle)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg("default_unlocked")

    return ::LayersIcon.genDataFromLayer(layerCfg)
  }

  function updateTrophyImage() {
    let imageObjPlace = this.scene.findObject("reward_image_place")
    if (!checkObj(imageObjPlace))
      return

    imageObjPlace.show(true)

    let layersData = this.getForceStyleImage() ?? this.getIconData()
    this.guiScene.replaceContentFromText(imageObjPlace, layersData, layersData.len(), this)
  }

  function updateImage() {
    if (this.rewardImage == null) {
      this.updateTrophyImage()
      return
    }

    let imageObj = this.showSceneBtn("reward_image", true)
    imageObj["background-image"] = this.rewardImage
    imageObj.height = $"{1.0 / this.rewardImageRatio}pw"
  }

  function updateRewardPostscript() {
    if (!this.opened || !this.useSingleAnimation)
      return

    let countNotVisibleItems = this.shrinkedConfigsArray.len() - ::trophyReward.maxRewardsShow

    if (countNotVisibleItems < 1)
      return

    let obj = this.scene.findObject("reward_postscript")
    if (!checkObj(obj))
      return

    obj.setValue(loc("trophy/moreRewards", { num = countNotVisibleItems }))
  }

  function updateRewardText() {
    if (!this.opened)
      return

    let obj = this.scene.findObject("prize_desc_div")
    if (!checkObj(obj))
      return

    let data = ::trophyReward.getRewardsListViewData(this.shrinkedConfigsArray,
                   { multiAwardHeader = true
                     widthByParentParent = true
                     header = loc("mainmenu/you_received")
                   })

    if (this.unit && this.unit.isRented()) {
      let descTextArray = []
      let totalRentTime = this.unit.getRentTimeleft()
      local rentText = "mainmenu/rent/rent_unit"
      if (totalRentTime > time.hoursToSeconds(this.rentTimeHours))
        rentText = "mainmenu/rent/rent_unit_extended"

      descTextArray.append(colorize("activeTextColor", loc(rentText)))
      let timeText = colorize("userlogColoredText", time.hoursToString(time.secondsToHours(totalRentTime)))
      descTextArray.append(colorize("activeTextColor", loc("mainmenu/rent/rentTimeSec", { time = timeText })))
      let descText = "\n".join(descTextArray, true)
      if (descText != "")
        this.scene.findObject("prize_desc_text").setValue(descText)
    }

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function onTakeNavBar() {
    if (!this.unit)
      return

    this.onTake(this.unit)
  }

  function checkConfigsArray() {
    foreach (reward in this.configsArray) {
      let rewardType = ::trophyReward.getType(reward)
      this.haveItems = this.haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit") {
        this.unit = ::getAircraftByName(reward[rewardType]) || this.unit
        //Datablock adapter used only to avoid bug with duplicate timeHours in userlog.
        this.rentTimeHours = DataBlockAdapter(reward)?.timeHours || this.rentTimeHours
        continue
      }

      if (rewardType == "resource" || rewardType == "resourceType")
        this.updateResourceData(reward?.resource, reward?.resourceType)
    }
  }

  function updateResourceData(resource, resourceType) {
    let decorData = getDecoratorDataToUse(resource, resourceType)
    if (decorData.decorator == null) {
      this.decorator = getDecoratorByResource(resource, resourceType)
      return
    }

    this.decorator = decorData.decorator
    this.decoratorUnit = decorData.decoratorUnit
    this.decoratorSlot = decorData.decoratorSlot
    let obj = this.scene.findObject("btn_use_decorator")
    if (obj?.isValid())
      obj.setValue(loc($"decorator/use/{this.decorator.decoratorType.resourceType}"))
  }

  function getRewardImage(trophyStyle = "") {
    local layersData = ""
    for (local i = 0; i < ::trophyReward.maxRewardsShow; i++) {
      let config = this.shrinkedConfigsArray?[i]
      if (config)
        layersData += ::trophyReward.getImageByConfig(config, false)
    }

    if (layersData == "")
      return ""

    let layerId = "item_place_container"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg(layerId)

    return ::LayersIcon.genDataFromLayer(layerCfg, layersData)
  }

  function onTake(unitToTake) {
    base.onTake(unitToTake, {
      cellClass = "slotbarClone"
      isNewUnit = true
      afterSuccessFunc = Callback(@() this.goBack(), this)
    })
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    let isShowRewardListBtn = this.opened && (this.configsArray.len() > 1 || this.haveItems)
    local btnObj = this.showSceneBtn("btn_rewards_list", isShowRewardListBtn)
    if (isShowRewardListBtn)
      btnObj.setValue(loc(this.getRewardsListLocId()))
    this.showSceneBtn("open_chest_animation", !this.animFinished) //hack tooltip bug
    this.showSceneBtn("btn_ok", this.animFinished)
    this.showSceneBtn("btn_back", this.animFinished || (this.trophyItem?.isAllowSkipOpeningAnim() ?? false))

    let prizeActionBtnId = this.isHidePrizeActionBtn || !this.animFinished ? ""
      : this.unit && this.unit.isUsable() && !::isUnitInSlotbar(this.unit) ? "btn_take_air"
      : this.rewardItem?.canRunCustomMission() ? "btn_run_custom_mission"
      : this.canGoToItem() ? "btn_go_to_item"
      : this.decoratorUnit && canStartPreviewScene(false) ? "btn_use_decorator"
      : this.decorator?.canPreview() && canStartPreviewScene(false) ? "btn_preview_decorator"
      : isLoadingBgUnlock(this.trophyItem?.getUnlockId()) ? "btn_preloader_settings"
      : ""

    let btnIds = [
      "btn_take_air",
      "btn_go_to_item",
      "btn_use_decorator",
      "btn_preloader_settings",
      "btn_run_custom_mission",
      "btn_preview_decorator"
    ]

    foreach (id in btnIds)
      this.showSceneBtn(id, id == prizeActionBtnId)

    if (prizeActionBtnId == "btn_run_custom_mission")
      this.scene.findObject(prizeActionBtnId).setValue(this.rewardItem?.getCustomMissionButtonText())

    let canReUseItem = this.animFinished && this.reUseRecipe != null
    btnObj = this.showSceneBtn("btn_re_use_item", canReUseItem)
    if (canReUseItem) {
      btnObj.inactiveColor = this.reUseRecipe.isUsable ? "no" : "yes"
      btnObj.setValue(loc(this.trophyItem.getLocIdsList().reUseItemLocId))
    }
  }

  function onViewRewards() {
    if (!this.checkSkipAnim() || !(this.opened && (this.configsArray.len() > 1 || this.haveItems)))
      return

    ::gui_start_open_trophy_rewards_list({ rewardsArray = this.shrinkedConfigsArray,
      titleLocId = this.getRewardsListLocId() })
  }

  function goBack() {
    if (this.trophyItem && !this.checkSkipAnim())
      return

    base.goBack()
  }

  function afterModalDestroy() {
    if (this.afterFunc)
      this.afterFunc()
  }

  function checkSkipAnim() {
    if (this.animFinished)
      return true

    if (!this.trophyItem?.isAllowSkipOpeningAnim())
      return false

    let animObj = this.scene.findObject("open_chest_animation")
    if (checkObj(animObj))
      animObj.animation = "hide"
    this.animFinished = true

    this.openChest()
    return false
  }

  function onOpenAnimFinish() {
    this.animFinished = true
    if (!this.openChest())
      this.updateButtons()
  }

  function updateRewardItem() { //ext item will come later, so need to wait until it received to show button
    if (!this.haveItems || this.isRewardItemActual)
      return false

    foreach (reward in this.configsArray)
      if (reward?.item) {
        this.rewardItem = ::ItemsManager.getInventoryItemById(reward.item)
        if (!this.rewardItem)
          continue

        this.isRewardItemActual = true
        return true
      }
    return false
  }

  onTimer = @(_obj, _dt) this.updateRewardItem() && this.updateButtons()

  function onGoToItem() {
    this.goBack()
    if (this.canGoToItem())
      ::gui_start_items_list(-1, { curItem = this.rewardItem })
  }

  onPreviewDecorator = @() canStartPreviewScene(true) && this.decorator.doPreview()
  onUseDecorator = @() useDecorator(this.decorator, this.decoratorUnit, this.decoratorSlot)
  onPreloaderSettings = @() preloaderOptionsModal(getLoadingBgIdByUnlockId(this.trophyItem.getUnlockId()))
  onRunCustomMission = @() this.rewardItem?.runCustomMission()

  function onReUseItem() {
    if (this.reUseRecipe == null)
      return
    this.goBack()
    this.guiScene.performDelayed(this, @() ExchangeRecipes.tryUse([this.reUseRecipe], this.trophyItem, {
      shouldSkipMsgBox = this.reUseRecipe.isUsable
      isHidePrizeActionBtn  = this.isHidePrizeActionBtn
    }))
  }

  canGoToItem = @() !!(this.rewardItem && sheets.getSheetDataByItem(this.rewardItem))

  isCreation = @() (!this.shouldShowRewardItem && this.configsArray[0]?.item == this.trophyItem.id)
  getRewardsListLocId = @() this.rewardListLocId && this.rewardListLocId != "" ? this.rewardListLocId
    : this.isCreation() ? this.trophyItem.getItemsListLocId()
    : this.trophyItem.getRewardListLocId()
}
