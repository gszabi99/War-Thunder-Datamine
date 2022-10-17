::gui_handlers.CreateEventRoomWnd <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneNavBlkName = null
  wndOptionsMode = ::OPTIONS_MODE_MP_DOMINATION
  wndGameMode = ::GM_DOMINATION

  mGameMode = null

  applyAtClose = false
  roomCreationContext = null

  slotbarActions = ["aircraft", "crew", "sec_weapons", "weapons", "showroom", "repair"]

  function initScreen()
  {
    if (!mGameMode)
      return goBack()

    initSizes()
    scene.findObject("header_name").setValue(::loc("mainmenu/btnCreateSession"))

    roomCreationContext = ::EventRoomCreationContext(mGameMode, ::Callback(reinitSlotbar, this))
    options = roomCreationContext.getOptionsList()
    optionsConfig = roomCreationContext.getOptionsConfig()

    base.initScreen()
    updateMissionsBtn()

    createSlotbar({
      roomCreationContext = roomCreationContext
      afterSlotbarSelect = updateApplyButton
      afterFullUpdate = updateApplyButton
    })
    updateApplyButton()
  }

  function initSizes()
  {
    let frameObj = scene.findObject("wnd_frame")
    frameObj.width = "1.3@sf"
    frameObj.height = "8@baseTrHeight + 1@frameTopPadding + 1@frameFooterHeightLarge"
  }

  function getNavbarTplView()
  {
    return {
      left = [
        {
          id = "btn_missions"
          text = "#mainmenu/btnMissions"
          shortcut = "Y"
          funcName = "onMissions"
          visualStyle = "secondary"
          button = true
        }
      ]
      right = [
        {
          id = "cant_create_reason"
          textField = true
        }
        {
          id = "btn_apply"
          text = "#mainmenu/btnCreateSession"
          shortcut = "A"
          funcName = "onApply"
          isToBattle = true
          button = true
        }
      ]
    }
  }

  function updateMissionsBtn()
  {
    local misBtnText = ""
    let total = roomCreationContext.fullMissionsList.len()
    if (total > 1)
    {
      let chosenAmount = roomCreationContext.chosenMissionsList.len()
      if (roomCreationContext.isAllMissionsSelected())
        misBtnText = ::loc("misList/allMissionsSelected")
      else if (chosenAmount == 1)
      {
        let selMission = roomCreationContext.chosenMissionsList[0]
        misBtnText = ::loc("misList/oneMissionSelected",
          { mission = roomCreationContext.misListType.getMissionNameText(selMission) })
      }
      else
        misBtnText = ::loc("misList/severalMissionsSelected", { amount = chosenAmount })
    }
    let misBtn = this.showSceneBtn("btn_missions", misBtnText.len() > 0)
    misBtn.setValue(misBtnText)
  }

  function updateApplyButton()
  {
    let reasonData = roomCreationContext.getCantCreateReasonData()

    let joinButtonObj = scene.findObject("btn_apply")
    joinButtonObj.inactiveColor = reasonData.activeJoinButton ? "no" : "yes"

    let reasonTextObj = this.showSceneBtn("cant_create_reason", reasonData.reasonText.len() > 0)
    reasonTextObj.setValue(reasonData.reasonText)
  }

  function onMissions()
  {
    if (!roomCreationContext.fullMissionsList.len())
      return

    ::gui_handlers.ChooseMissionsListWnd.open({
      missionsList = roomCreationContext.fullMissionsList
      selMissions = roomCreationContext.chosenMissionsList
      onApplyListCb = ::Callback(function(selList)
      {
        roomCreationContext.setChosenMissions(selList)
        updateMissionsBtn()
      }, this)
    })
  }

  function getCurrentEdiff()
  {
    let ediff = ::events.getEDiffByEvent(mGameMode)
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventCountryChanged(p)
  {
    updateApplyButton()
  }

  function applyFunc()
  {
    roomCreationContext.createRoom()
  }
}