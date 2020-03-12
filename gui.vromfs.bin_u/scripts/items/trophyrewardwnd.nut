local time = require("scripts/time.nut")
local sheets = ::require("scripts/items/itemsShopSheets.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")

::gui_start_open_trophy <- function gui_start_open_trophy(configsTable = {})
{
  if (configsTable.len() == 0)
    return

  local params = {}
  foreach (paramName in [ "rewardTitle", "rewardListLocId", "isDisassemble",
    "isHidePrizeActionBtn" ])
  {
    if (!(paramName in configsTable))
      continue

    params[paramName] <- configsTable[paramName]
    configsTable.rawdelete(paramName)
  }

  local tKey = ""
  foreach(idx, configsArray in configsTable)
  {
    tKey = idx
    break
  }

  local configsArray = configsTable.rawdelete(tKey)
  configsArray.sort(::trophyReward.rewardsSortComparator)
  params.configsArray <- configsArray
  params.afterFunc <- @() ::gui_start_open_trophy(configsTable)

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardWnd, params)
}

class ::gui_handlers.trophyRewardWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyReward.blk"

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

  slotbarActions = [ "take", "weapons", "info" ]

  decorator = null
  decoratorUnit = null
  decoratorSlot = -1
  rewardTitle = null
  rewardListLocId = null
  isHidePrizeActionBtn = false

  function initScreen()
  {
    local itemId = configsArray?[0]?.itemDefId
      || configsArray?[0]?.trophyItemDefId
      || configsArray?[0]?.id
      || ""
    trophyItem = ::ItemsManager.findItemById(itemId)

    if (!trophyItem)
      return base.goBack()

    shouldShowRewardItem = trophyItem.iType == itemType.RECIPES_BUNDLE
    isBoxOpening = !shouldShowRewardItem
      && (trophyItem.iType == itemType.TROPHY
         || trophyItem.iType == itemType.CHEST
         || trophyItem.iType == itemType.CRAFT_PROCESS
         || trophyItem.iType == itemType.CRAFT_PART)

    local title = rewardTitle && rewardTitle != "" ? rewardTitle
      : isDisassemble && !shouldShowRewardItem ? ::loc("mainmenu/itemDisassembled/title")
      : isCreation() ? trophyItem.getCreationCaption()
      : trophyItem.getOpeningCaption()
    local titleObj = scene.findObject("reward_title")
    titleObj.setValue(title)
    if (daguiFonts.getStringWidthPx(title, "fontMedium", guiScene) >
      ::to_pixels("1@trophyWndWidth - 1@buttonCloseHeight"))
      titleObj.caption = "no"

    shrinkedConfigsArray = ::trophyReward.processUserlogData(configsArray)
    checkConfigsArray()
    updateRewardItem()
    updateWnd()
    startOpening()

    scene.findObject("update_timer").setUserData(this)
  }

  function startOpening()
  {
    if (::ItemsRoulette.init(trophyItem.id,
                             configsArray,
                             scene,
                             this,
                             function() {
                               openChest.call(this)
                               onOpenAnimFinish.call(this)
                             }
                          ))
      useSingleAnimation = false

    ::showBtn(useSingleAnimation? "reward_roullete" : "open_chest_animation", false, scene) //hide not used animation
    local animId = useSingleAnimation? "open_chest_animation" : "reward_roullete"
    local animObj = scene.findObject(animId)
    if (::checkObj(animObj))
    {
      animObj.animation = "show"
      if (useSingleAnimation)
      {
        ::play_gui_sound("chest_open")
        local delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
        ::Timer(animObj, 0.001 * delay, openChest, this)
        ::Timer(animObj, 1.0, onOpenAnimFinish, this) //!!FIX ME: Some times animation finish not apply css, and we miss onOpenAnimFinish
      }
    }
    else
      openChest()
  }

  function openChest()
  {
    if (opened)
      return false
    local obj = scene.findObject("rewards_list")
    ItemsRoulette.skipAnimation(obj)
    opened = true
    updateWnd()
    ::broadcastEvent("TrophyContentVisible", { trophyItem = trophyItem })
    return true
  }

  function updateWnd()
  {
    updateImage()
    updateRewardText()
    updateRewardPostscript()
    updateButtons()
  }

  function updateImage()
  {
    local imageObj = scene.findObject("reward_image")
    if (!::checkObj(imageObj))
      return

    local itemToShow = trophyItem
    if (shouldShowRewardItem && configsArray[0]?.item)
      itemToShow = ::ItemsManager.findItemById(configsArray[0].item)

    if (itemToShow == null)
      return

    local layersData = ""
    if (isBoxOpening && (opened || useSingleAnimation))
    {
      layersData = itemToShow.getOpenedBigIcon()
      if (opened && useSingleAnimation)
        layersData += getRewardImage(itemToShow.iconStyle)
    } else
      layersData = itemToShow.getBigIcon()

    guiScene.replaceContentFromText(imageObj, layersData, layersData.len(), this)
  }

  function updateRewardPostscript()
  {
    if (!opened || !useSingleAnimation)
      return

    local countNotVisibleItems = shrinkedConfigsArray.len() - ::trophyReward.maxRewardsShow

    if (countNotVisibleItems < 1)
      return

    local obj = scene.findObject("reward_postscript")
    if (!::check_obj(obj))
      return

    obj.setValue(::loc("trophy/moreRewards", {num = countNotVisibleItems}))
  }

  function updateRewardText()
  {
    if (!opened)
      return

    local obj = scene.findObject("prize_desc_div")
    if (!::checkObj(obj))
      return

    local data = ::trophyReward.getRewardsListViewData(shrinkedConfigsArray,
                   { multiAwardHeader = true
                     widthByParentParent = true
                     header = ::loc("mainmenu/you_received")
                   })

    if (unit && unit.isRented())
    {
      local totalRentTime = unit.getRentTimeleft()
      local rentText = "mainmenu/rent/rent_unit"
      if (totalRentTime > time.hoursToSeconds(rentTimeHours))
        rentText = "mainmenu/rent/rent_unit_extended"

      rentText = ::loc(rentText) + "\n"
      local timeText = ::colorize("userlogColoredText", time.hoursToString(time.secondsToHours(totalRentTime)))
      rentText += ::loc("mainmenu/rent/rentTimeSec", {time = timeText})

      scene.findObject("prize_desc_text").setValue(::colorize("activeTextColor", rentText))
    }

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function onTakeNavBar()
  {
    if (!unit)
      return

    onTake(unit)
  }

  function checkConfigsArray()
  {
    foreach(reward in configsArray)
    {
      local rewardType = ::trophyReward.getType(reward)
      haveItems = haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
      {
        unit = ::getAircraftByName(reward[rewardType]) || unit
        //Datablock adapter used only to avoid bug with duplicate timeHours in userlog.
        rentTimeHours = ::DataBlockAdapter(reward)?.timeHours || rentTimeHours
      }

      if (rewardType == "resource" || rewardType == "resourceType")
      {
        local decor = ::g_decorator.getDecoratorByResource(reward?.resource, reward?.resourceType)
        if (decor)
        {
          local decoratorType = decor.decoratorType
          local decorUnit = decoratorType == ::g_decorator_type.SKINS ?
            ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decor.id)) :
            ::get_player_cur_unit()

          if (decorUnit && decoratorType.isAvailable(decorUnit) && decor.canUse(decorUnit))
          {
            local freeSlotIdx = decoratorType.getFreeSlotIdx(decorUnit)
            local slotIdx = freeSlotIdx != -1 ? freeSlotIdx
              : (decoratorType.getAvailableSlots(decorUnit) - 1)
            decorator = decor
            decoratorUnit = decorUnit
            decoratorSlot = slotIdx

            local obj = scene.findObject("btn_use_decorator")
            if (::check_obj(obj))
              obj.setValue(::loc("decorator/use/" + decoratorType.resourceType))
          }
        }
      }
    }
  }

  function getRewardImage(trophyStyle = "")
  {
    local layersData = ""
    for (local i = 0; i < ::trophyReward.maxRewardsShow; i++)
    {
      local config = shrinkedConfigsArray?[i]
      if (config)
        layersData += ::trophyReward.getImageByConfig(config, false)
    }

    if (layersData == "")
      return ""

    local layerId = "item_place_container"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg(layerId)

    return ::LayersIcon.genDataFromLayer(layerCfg, layersData)
  }

  function onTake(unitToTake)
  {
    base.onTake(unitToTake, {
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }

  function onEventCrewTakeUnit(params)
  {
    goBack()
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    ::show_facebook_screenshot_button(scene, opened)
    local isShowRewardListBtn = opened && (configsArray.len() > 1 || haveItems)
    local btnObj = showSceneBtn("btn_rewards_list", isShowRewardListBtn)
    if (isShowRewardListBtn)
      btnObj.setValue(::loc(getRewardsListLocId()))
    showSceneBtn("open_chest_animation", !animFinished) //hack tooltip bug
    showSceneBtn("btn_ok", animFinished)
    showSceneBtn("btn_back", animFinished || trophyItem.isAllowSkipOpeningAnim())

    local prizeActionBtnId = isHidePrizeActionBtn || !animFinished ? ""
      : unit && unit.isUsable() && !::isUnitInSlotbar(unit) ? "btn_take_air"
      : rewardItem ? "btn_go_to_item"
      : decorator  ? "btn_use_decorator"
      : ""
    foreach (id in [ "btn_take_air", "btn_go_to_item", "btn_use_decorator" ])
      showSceneBtn(id, id == prizeActionBtnId)
  }

  function onViewRewards()
  {
    if (!checkSkipAnim() || !(opened && (configsArray.len() > 1 || haveItems)))
      return

    ::gui_start_open_trophy_rewards_list({ rewardsArray = shrinkedConfigsArray,
      tittleLocId = getRewardsListLocId()})
  }

  function goBack()
  {
    if (trophyItem && !checkSkipAnim())
      return

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (afterFunc)
      afterFunc()
  }

  function checkSkipAnim()
  {
    if (animFinished)
      return true

    if (!trophyItem.isAllowSkipOpeningAnim())
      return false

    local animObj = scene.findObject("open_chest_animation")
    if (::checkObj(animObj))
      animObj.animation = "hide"
    animFinished = true

    openChest()
    return false
  }

  function onOpenAnimFinish()
  {
    animFinished = true
    if (!openChest())
      updateButtons()
  }

  function updateRewardItem() //ext item will come later, so need to wait until it received to show button
  {
    if (!haveItems || isRewardItemActual)
      return false

    foreach(reward in configsArray)
      if (reward?.item)
      {
        rewardItem = ItemsManager.getInventoryItemById(reward.item)
        if (!rewardItem)
          continue

        isRewardItemActual = true
        if (!sheets.getSheetDataByItem(rewardItem))
          rewardItem = null
        return true
      }
    return false
  }

  onTimer = @(obj, dt) updateRewardItem() && updateButtons()

  function onGoToItem()
  {
    goBack()
    if (rewardItem)
      ::gui_start_items_list(-1, { curItem = rewardItem })
  }

  function onUseDecorator()
  {
    if (!decorator)
      return
    ::gui_start_decals({
        unit = decoratorUnit
        preSelectDecorator = decorator
        preSelectDecoratorSlot = decoratorSlot
      })
  }

  isCreation = @() (!shouldShowRewardItem && configsArray[0]?.item == trophyItem.id)
  getRewardsListLocId = @() rewardListLocId && rewardListLocId != "" ? rewardListLocId
    : isCreation() ? trophyItem.getItemsListLocId()
    : trophyItem.getRewardListLocId()
}
