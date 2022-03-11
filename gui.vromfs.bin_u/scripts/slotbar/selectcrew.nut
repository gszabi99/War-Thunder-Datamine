let slotbarWidget = require("scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let tutorAction = require("scripts/tutorials/tutorialActions.nut")
let { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
let { getSafearea } = require("scripts/options/safeAreaMenu.nut")

::gui_start_selecting_crew <- function gui_start_selecting_crew(config)
{
  if (::CrewTakeUnitProcess.safeInterrupt())
    ::handlersManager.destroyPrevHandlerAndLoadNew(::gui_handlers.SelectCrew, config)
}

let function getObjPosInSafeArea(obj) {
  let pos = obj.getPosRC()
  let size = obj.getSize()
  let safeArea = getSafearea()
  let screen = [::screen_width(), ::screen_height()]
  local border = safeArea.map(@(value, idx) (screen[idx] * (1.0 - value) / 2).tointeger())
  return pos.map(@(val, idx) ::clamp(val, border[idx], screen[idx] - border[idx] - size[idx]))
}

::gui_handlers.SelectCrew <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/shop/shopTakeAircraft.blk"

  unit = null
  unitObj = null
  cellClass = "slotbarClone"
  getEdiffFunc = null
  afterCloseFunc = null
  afterSuccessFunc = null

  useTutorial = false

  restrictCancel = false

  country = ""
  messageText = ""

  takeCrewIdInCountry = -1
  isNewUnit = false

  isSelectByGroups = false

  function initScreen()
  {
    if (!unit || !unit.isUsable() || isUnitInSlotbar() || !::checkObj(unitObj))
    {
      goBack()
      return
    }

    country = ::getUnitCountry(unit)
    checkAvailableCrew()

    guiScene.setUpdatesEnabled(false, false)

    let tdObj = unitObj.getParent()
    let tdPos = getObjPosInSafeArea(tdObj)

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    let tdClone = tdObj.getClone(scene, this)
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = cellClass
    tdClone.position = "root"
    ::fill_unit_item_timers(tdClone.findObject(unit.name), unit)

    if (!::has_feature("GlobalShowBattleRating") && ::has_feature("SlotbarShowBattleRating"))
    {
      let rankObj = tdClone.findObject("rank_text")
      if (::checkObj(rankObj))
      {
        let unitRankText = ::get_unit_rank_text(unit, null, true, getCurrentEdiff())
        rankObj.setValue(unitRankText)
      }
    }

    let bDiv = tdClone.findObject("air_item_bottom_buttons")
    if (::checkObj(bDiv))
      guiScene.destroyElement(bDiv)

    let markerObj = tdClone.findObject("unlockMarker")
    if (markerObj?.isValid())
      guiScene.destroyElement(markerObj)

    let crew = ::get_crews_list_by_country(country)?[takeCrewIdInCountry]
    createSlotbar(
      {
        crewId = crew?.id
        shouldSelectCrewRecruit =  takeCrewIdInCountry > 0 && !crew
        singleCountry = country
        hasActions = false
        showNewSlot = true
        showEmptySlot = true,
        needActionsWithEmptyCrews = false
        unitForSpecType = unit,
        alwaysShowBorder = true
        hasExtraInfoBlock = true
        slotbarBehavior = "posNavigator"
        needFullSlotBlock = true

        applySlotSelectionOverride = @(_, __) onChangeUnit()
        onSlotDblClick = ::Callback(onApplyCrew, this)
        onSlotActivate = ::Callback(onApplyCrew, this)
      },
      "take-aircraft-slotbar")

    onChangeUnit()

    let legendObj = fillLegendData()

    ::move_mouse_on_child_by_value(slotbarWeak && slotbarWeak.getCurrentAirsTable())

    let textObj = scene.findObject("take-aircraft-text")
    textObj.setValue(messageText)

    guiScene.setUpdatesEnabled(true, true)

    updateObjectsPositions(tdClone, legendObj, textObj)
    checkUseTutorial()
  }

  createSlotbarHandler = @(params) isSelectByGroups
    ? slotbarWidget.create(params)
    : ::gui_handlers.SlotbarWidget.create(params)

  function updateObjectsPositions(tdClone, legendObj, headerObj)
  {
    let rootSize = guiScene.getRoot().getSize()
    let sh = rootSize[1]
    let bh = ::g_dagui_utils.toPixels(guiScene, "@bh")
    let interval = ::g_dagui_utils.toPixels(guiScene, "@itemsIntervalBig")

    //count position by visual card obj. real td is higher and wider than a card.
    let visTdObj = tdClone.childrenCount() ? tdClone.getChild(0) : tdClone
    let tdPos = visTdObj.getPosRC()
    let tdSize = visTdObj.getSize()

    //top and bottom of already positioned items
    local top = tdPos[1]
    local bottom = tdPos[1] + tdSize[1]

    //place slotbar
    let sbObj = scene.findObject("slotbar_with_buttons")
    let sbSize = sbObj.getSize()
    let isSlotbarOnTop = bottom + interval + sbSize[1] > sh - bh
    local sbPosY = 0
    if (isSlotbarOnTop)
    {
      sbPosY = top - interval - sbSize[1]
      top = sbPosY
    } else
    {
      sbPosY = bottom + interval
      bottom = sbPosY + sbSize[1]
    }
    sbObj.top = sbPosY

    //place legend
    if (::checkObj(legendObj))
    {
      let legendSize = legendObj.getSize()

      //try to put legend near unit td, but below slotbar when possible
      local isNearTd = false
      local bottomNoTd = bottom
      if (tdPos[1] + tdSize[1] == bottom)
      {
        bottomNoTd = tdPos[1] - interval
        isNearTd = true
      }

      let isLegendBottom = bottomNoTd + interval + legendSize[1] <= sh - bh
      local legendPosY = 0
      if (isLegendBottom)
      {
        legendPosY = bottomNoTd + interval
        bottom = ::max(legendPosY + legendSize[1], bottom)
      } else
      {
        isNearTd = tdPos[1] == top
        let topNoTd = isNearTd ? tdPos[1] + tdSize[1] + interval : top
        legendPosY = topNoTd - interval - legendSize[1]
        top = ::min(legendPosY, top)
      }

      legendObj.top = legendPosY

      if (isNearTd) //else centered.
      {
        let sw = rootSize[0]
        let bw = ::g_dagui_utils.toPixels(guiScene, "@bw")
        local legendPosX = tdPos[0] + tdSize[0] + interval
        if (legendPosX + legendSize[0] > sw - bw)
          legendPosX = tdPos[0] - interval - legendSize[0]
        legendObj.left = legendPosX
      }
    }

    //place headerMessage
    let headerPosY = top - interval - headerObj.getSize()[1]
    headerObj.top = headerPosY
  }

  function checkAvailableCrew()
  {
    if (takeCrewIdInCountry >= 0)
      return

    takeCrewIdInCountry = ::g_crew.getBestTrainedCrewIdxForUnit(unit, true)
    if (takeCrewIdInCountry >= 0)
      return

    takeCrewIdInCountry = ::get_first_empty_crew_slot()
    if (takeCrewIdInCountry >= 0)
      return

    let costTable = ::get_crew_slot_cost(country)
    if (!costTable)
      return

    let cost = ::Cost(costTable.cost, costTable.costGold)
    if (cost.gold > 0)
      return

    takeCrewIdInCountry = cost <= ::get_gui_balance()? ::get_crew_count(country) : takeCrewIdInCountry
  }

  function getCurrentEdiff()
  {
    return ::u.isFunction(getEdiffFunc) ? getEdiffFunc() : ::get_current_ediff()
  }

  function getTakeAirCost()
  {
    return isSelectByGroups
      ? ::Cost()
      : ::CrewTakeUnitProcess.getProcessCost(
          getCurCrew(),
          unit
        )
  }

  function onChangeUnit()
  {
    takeCrewIdInCountry = getCurCrew()?.idInCountry ?? ::get_crew_count(country)
    updateButtons()
  }

  function updateButtons()
  {
    placePriceTextToButton(scene, "btn_set_air", ::loc("mainmenu/btnTakeAircraft"), getTakeAirCost())
  }

  function onEventOnlineShopPurchaseSuccessful(p)
  {
    updateButtons()
  }

  function checkUseTutorial()
  {
    if (useTutorial)
      startTutorial()
  }

  function startTutorial()
  {
    let playerBalance = ::Cost()
    let playerInfo = ::get_profile_info()
    playerBalance.wp = playerInfo.balance
    playerBalance.gold = playerInfo.gold

    restrictCancel = getTakeAirCost() < playerBalance
    showSceneBtn("btn_set_cancel", !restrictCancel)

    guiScene.applyPendingChanges(false)
    let steps = [
      {
        obj = getSlotbar() && getSlotbar().getBoxOfUnits()
        text = ::loc("help/takeAircraft", {unitName = ::getUnitName(unit)})
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = "btn_set_air"
        text = ::loc("help/pressOnReady")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }
    ]

    ::gui_modal_tutor(steps, this)
  }

  function onApply()
  {
    onApplyCrew(getCurCrew())
  }

  function onApplyCrew(crew)
  {
    let onFinishCb = ::Callback(onTakeProcessFinish, this)
    if (isSelectByGroups)
      slotbarPresets.setUnit({
        crew = crew
        unit = unit
        onFinishCb = onFinishCb
      })
    else
      ::CrewTakeUnitProcess(crew, unit, onFinishCb)
  }

  function onTakeProcessFinish(isSuccess)
  {
    if (!isSuccess)
      return

    if (isNewUnit)
    {
      ::add_big_query_record("choosed_crew_for_new_unit",
        ::save_to_json({ unit = unit.name
          crew = getCurCrew()?.id }))
    }
    if (afterSuccessFunc)
      afterSuccessFunc()
    goBack()
  }

  function onEventSetInQueue(params)
  {
    let reqMoneyMsg = scene.findObject("need_money")
    if (::checkObj(reqMoneyMsg))
      guiScene.destroyObject(reqMoneyMsg)

    let noMoneyMsg = scene.findObject("no_money")
    if (::checkObj(noMoneyMsg))
      guiScene.destroyObject(noMoneyMsg)

    goBack()
  }

  function onTakeCancel()
  {
    if (restrictCancel)
      return

    goBack()
  }

  function addLegendData(result, specType)
  {
    foreach(data in result)
      if (specType == data.specType)
        return

    result.append({
      id = specType.specName,
      specType = specType,
      imagePath = specType.trainedIcon,
      locId = ::loc("crew/trained") + ::loc("ui/colon") + specType.getName()
    })
  }

  function fillLegendData()
  {
    if (!::has_feature("CrewInfo"))
      return null

    let legendData = []
    foreach (idx, crew in ::get_crews_list_by_country(country))
    {
      let specType = ::g_crew_spec_type.getTypeByCode(::g_crew_spec_type.getTrainedSpecCode(crew, unit))
      addLegendData(legendData, specType)
    }

    if (::u.isEmpty(legendData))
      return null

    legendData.sort(function(a, b) {
      if (a.specType.code != b.specType.code)
        return a.specType.code > b.specType.code? 1 : -1
      return 0
    })

    let view = {
      header = ::loc("mainmenu/legend") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::getUnitName(unit, false))
      haveLegend = legendData.len() > 0
      legendData = legendData
    }

    let obj = scene.findObject("qualification_legend")
    if (!::checkObj(obj))
      return null

    let blk = ::handyman.renderCached("%gui/slotbar/legend_block", view)
    guiScene.replaceContentFromText(obj, blk, blk.len(), this)

    return obj
  }

  function onDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onUnitMainFunc(obj) {}
  function onUnitMainFuncBtnUnHover() {}
  onUnitMarkerClick = @() null

  function isUnitInSlotbar()
  {
    return !isSelectByGroups && ::isUnitInSlotbar(unit)
  }
}
