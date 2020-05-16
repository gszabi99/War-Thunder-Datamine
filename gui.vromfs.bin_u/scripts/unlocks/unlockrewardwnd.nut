class ::gui_handlers.UnlockRewardWnd extends ::gui_handlers.trophyRewardWnd
{
  wndType = handlerType.MODAL

  unlockConfig = null
  unlockConditions = null
  unlockData = null

  chestDefaultImg = "every_day_award_trophy_big"
  itemContainerLayer = "trophy_reward_place"

  prepareParams = @() null
  getTitle = @() ::get_unlock_type_text(unlockData.type, unlockData.id)
  isRouletteStarted = @() false

  function openChest() {
    if (opened)
      return false

    opened = true
    updateWnd()
    return true
  }

  function checkConfigsArray() {
    local unlockType = ::g_unlock_view.getUnlockType(unlockData)
    if (unlockType == ::UNLOCKABLE_AIRCRAFT)
      unit = ::getAircraftByName(unlockData.id)
    else if (unlockType == ::UNLOCKABLE_DECAL
      || unlockType == ::UNLOCKABLE_SKIN
      || unlockType == ::UNLOCKABLE_ATTACHABLE)
      {
        local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
        decorator = ::g_decorator.getDecorator(unlockData.id, decoratorType)

        if (!decorator)
          return

        local decorUnit = decoratorType == ::g_decorator_type.SKINS ?
          ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decorator.id)) :
          ::get_player_cur_unit()

        if (decorUnit && decoratorType.isAvailable(decorUnit) && decorator.canUse(decorUnit))
        {
          local freeSlotIdx = decoratorType.getFreeSlotIdx(decorUnit)
          local slotIdx = freeSlotIdx != -1 ? freeSlotIdx
            : (decoratorType.getAvailableSlots(decorUnit) - 1)

          decoratorUnit = decorUnit
          decoratorSlot = slotIdx

          local obj = scene.findObject("btn_use_decorator")
          if (::check_obj(obj))
            obj.setValue(::loc("decorator/use/" + decoratorType.resourceType))
        }
      }
  }

  function getIconData() {
    if (!opened)
      return ""

    local imgConfig = ::g_unlock_view.getUnlockImageConfig(unlockData)

    return "{0}{1}".subst(
      ::LayersIcon.getIconData($"{chestDefaultImg}_opened"),
      ::LayersIcon.genDataFromLayer(
        ::LayersIcon.findLayerCfg(itemContainerLayer),
        ::LayersIcon.getIconData(imgConfig.style, imgConfig.image, imgConfig.ratio, null, imgConfig.params)
      )
    )
  }

  function updateRewardText() {
    if (!opened)
      return

    local obj = scene.findObject("prize_desc_div")
    if (!::checkObj(obj))
      return

    local data = ::g_unlock_view.getViewItem(unlockData, {
      header = ::loc("mainmenu/you_received")
      multiAwardHeader = true
      widthByParentParent = true
    })

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  checkSkipAnim = @() false
  notifyTrophyVisible = @() null
  updateRewardPostscript = @() null
  updateRewardItem = @() null
}

return {
  showUnlock = function(unlockId) {
    local config = ::g_unlocks.getUnlockById(unlockId)
    if (!config)
    {
      ::dagor.logerr($"Unlock Reward: Could not find unlock config {unlockId}")
      return
    }

    local unlockConditions = ::build_conditions_config(config)
    ::handlersManager.loadHandler(::gui_handlers.UnlockRewardWnd, {
      unlockConfig = config,
      unlockConditions = unlockConditions
      unlockData = ::build_log_unlock_data(unlockConditions)
    })
  }
}