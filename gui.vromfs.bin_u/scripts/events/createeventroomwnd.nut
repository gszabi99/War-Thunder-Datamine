from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { OPTIONS_MODE_MP_DOMINATION } = require("%scripts/options/optionsExtNames.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { EventRoomCreationContext } = require("%scripts/events/eventRoomCreationContext.nut")

gui_handlers.CreateEventRoomWnd <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneNavBlkName = null
  wndOptionsMode = OPTIONS_MODE_MP_DOMINATION
  wndGameMode = GM_DOMINATION

  mGameMode = null

  applyAtClose = false
  roomCreationContext = null

  slotbarActions = ["aircraft", "crew", "sec_weapons", "weapons", "showroom",




  "repair"]

  prevRanges = ""

  function initScreen() {
    if (!this.mGameMode)
      return this.goBack()

    this.initSizes()
    this.scene.findObject("header_name").setValue(loc("mainmenu/btnCreateSession"))

    this.roomCreationContext = EventRoomCreationContext(this.mGameMode, Callback(this.reinitSlotbar, this))
    this.options = this.roomCreationContext.getOptionsList()
    this.optionsConfig = this.roomCreationContext.getOptionsConfig()

    base.initScreen()
    this.updateMissionsBtn()

    this.createSlotbar({
      roomCreationContext = this.roomCreationContext
      afterSlotbarSelect = this.updateApplyButton
      afterFullUpdate = this.updateApplyButton
    })
    this.updateApplyButton()
    this.prevRanges = this.rangesToString(this.optionsConfig.brRanges)
  }

  function onEventEventsDataUpdated(_params) {
    let customMgm = getQueueClass("Event").getCustomMgm(this.mGameMode.name)
    if (customMgm == null)
      return

    let newRanges = this.rangesToString(customMgm.matchmaking.mmRanges)
    if (this.prevRanges != newRanges) {
      this.mGameMode = customMgm
      this.roomCreationContext = EventRoomCreationContext(this.mGameMode, Callback(this.reinitSlotbar, this))
      this.options = this.roomCreationContext.getOptionsList()
      this.optionsConfig = this.roomCreationContext.getOptionsConfig()
      this.prevRanges = newRanges
      this.loadOptions(this.options, this.currentContainerName)
    }
  }

  function rangesToString(ranges) {
    local res = []
    foreach (_idx, range in ranges)
      res.append("-".concat(range[0], range[1]))
    return ";".join(res)
  }

  function initSizes() {
    let frameObj = this.scene.findObject("wnd_frame")
    frameObj.width = "1.3@sf"
    frameObj.height = "8@baseTrHeight + 1@frameTopPadding + 1@frameFooterHeightLarge"
  }

  function getNavbarTplView() {
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

  function updateMissionsBtn() {
    local misBtnText = ""
    let total = this.roomCreationContext.fullMissionsList.len()
    if (total > 1) {
      let chosenAmount = this.roomCreationContext.chosenMissionsList.len()
      if (this.roomCreationContext.isAllMissionsSelected())
        misBtnText = loc("misList/allMissionsSelected")
      else if (chosenAmount == 1) {
        let selMission = this.roomCreationContext.chosenMissionsList[0]
        misBtnText = loc("misList/oneMissionSelected",
          { mission = this.roomCreationContext.misListType.getMissionNameText(selMission) })
      }
      else
        misBtnText = loc("misList/severalMissionsSelected", { amount = chosenAmount })
    }
    let misBtn = showObjById("btn_missions", misBtnText.len() > 0, this.scene)
    misBtn.setValue(misBtnText)
  }

  function updateApplyButton() {
    let reasonData = this.roomCreationContext.getCantCreateReasonData()

    let joinButtonObj = this.scene.findObject("btn_apply")
    joinButtonObj.inactiveColor = reasonData.activeJoinButton ? "no" : "yes"

    let reasonTextObj = showObjById("cant_create_reason", reasonData.reasonText.len() > 0, this.scene)
    reasonTextObj.setValue(reasonData.reasonText)
  }

  function onMissions() {
    if (!this.roomCreationContext.fullMissionsList.len())
      return

    gui_handlers.ChooseMissionsListWnd.open({
      missionsList = this.roomCreationContext.fullMissionsList
      selMissions = this.roomCreationContext.chosenMissionsList
      onApplyListCb = Callback(function(selList) {
        this.roomCreationContext.setChosenMissions(selList)
        this.updateMissionsBtn()
      }, this)
    })
  }

  function getCurrentEdiff() {
    let ediff = events.getEDiffByEvent(this.mGameMode)
    return ediff != -1 ? ediff : getCurrentGameModeEdiff()
  }

  function onEventCountryChanged(_p) {
    this.updateApplyButton()
  }

  function applyFunc() {
    this.roomCreationContext.createRoom()
  }
}