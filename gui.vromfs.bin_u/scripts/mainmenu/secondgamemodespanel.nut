from "%scripts/dagui_library.nut" import *
from "string" import format
from "dagor.workcycle" import setTimeout, clearTimer
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%scripts/squads/squadState.nut" import isSquadMember, isSquadLeader, getSquadData

from "%scripts/battleRating.nut" import recentBR
from "%scripts/events/secondGameModesUtils.nut" import mainGameModes, secondGameModes, hasSecondGameModes
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentEvent

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

const UPDATE_SECOND_MODES_DELAY_ID = "update_second_modes_delay"
const UPDATE_SECOND_MODES_DELAY = 0.2

const UPDATE_SECOND_MODES_FOR_SQUAD_DELAY = 0.1
const UPDATE_SECOND_MODES_FOR_SQUAD_ID = "update_second_modes_for_squad"

local isInUpdate = false

function notifySecondGameModesStateChanges() {
  clearTimer(UPDATE_SECOND_MODES_FOR_SQUAD_ID)
  if (isSquadLeader())
    broadcastEvent("SecondGameModesChanged")
}

function deferNotifySecondGameModesStateChanges(event = null) {
  if (!isSquadLeader())
    return
  event = event ?? getCurrentEvent()
  if (event == null)
    return
  clearTimer(UPDATE_SECOND_MODES_FOR_SQUAD_ID)
  setTimeout(UPDATE_SECOND_MODES_FOR_SQUAD_DELAY, notifySecondGameModesStateChanges, UPDATE_SECOND_MODES_FOR_SQUAD_ID)
}

function setSecondGameModeActive(modeId, isActive, event = null) {
  if (isInUpdate)
    return

  let gameModeData = secondGameModes.findvalue(@(mode) mode.modeId == modeId)
  if (gameModeData?.setActiveWithEvent != null)
    gameModeData.setActiveWithEvent(isActive, event)
  else if (gameModeData)
    gameModeData.setActive(isActive)

  deferNotifySecondGameModesStateChanges(event)
}

function updateSecondGameModes(nest, event, handler) {
  isInUpdate = true
  let detailsNest = nest.findObject("second_game_modes_details")
  let statusesNest = nest.findObject("second_game_modes_status")
  let isMemberOfSquad = isSquadMember()
  let squadLeaderModes = isMemberOfSquad ? getSquadData()?.subGameModes : null

  let hasMainModes = mainGameModes.findvalue(@(mode) mode.isPresent(event)) != null
  foreach (modeData in secondGameModes) {
    let detailsObj = detailsNest.findObject(modeData.modeId)
    let statusObj = statusesNest.findObject(modeData.modeId)
    let isModePresent = modeData.isPresent(event)
    detailsObj.show(isModePresent)
    if (modeData?.isHeader) {
      detailsObj["margin-top"] = hasMainModes ? "2@blockInterval" : "0"
      continue
    }
    if (statusObj?.isValid())
      statusObj.show(isModePresent)
    if (!isModePresent)
      continue

    let detailsTextObj = detailsObj.findObject("details")
    let detailsText = modeData?.getDetails ? modeData.getDetails(event) : null
    detailsTextObj.show(detailsText != null)
    if (detailsText)
      detailsTextObj.setValue(detailsText)

    let isModeSelected = isMemberOfSquad ? (squadLeaderModes?[modeData.modeId].isSelected ?? true) : modeData.isSelected(event)
    let isModeAvalible = isMemberOfSquad ? squadLeaderModes?[modeData.modeId]?.isAvalible : (modeData?.isAvalible(event) ?? true)
    if (!isMemberOfSquad) {
      let switchBox = detailsObj.findObject("switch_box")
      switchBox.setValue(isModeSelected)
      switchBox.enable(isModeAvalible)
      detailsObj.findObject("switch_box_holder").tooltip = modeData?.getTooltipText(event)
    }

    if (!statusObj?.isValid())
      continue

    let battleRating = isMemberOfSquad ? (squadLeaderModes?[modeData.modeId].br ?? 0)
      : modeData?.getBattleRating != null
        ? modeData.getBattleRating(event)
        : recentBR.get()
    let isModeActive = isMemberOfSquad ? isModeSelected : (battleRating != 0 && (modeData?.isActive(event) ?? true))

    let statusTextObj = statusObj.findObject("text")
    statusTextObj.setValue(!isModeAvalible || battleRating == 0 ? loc("leaderboards/notAvailable")
      : isModeActive ? " ".concat(loc("mainmenu/brText"), format("%.1f", battleRating))
      : loc("options/disabled/short")
    )
  }
  handler.updateTopNoticesBlockPos?()
  isInUpdate = false
}

function fillSecondModes(nest, handler) {
  let modesData = handyman.renderCached("%gui/secondGameModes.tpl", {
    secondModes = secondGameModes
    secondStatusModes = secondGameModes.filter(@(mode) !(mode?.isMainMode ?? false) && !(mode?.isHeader ?? false))
  })
  nest.getScene().replaceContentFromText(nest, modesData, modesData.len(), handler)
}

function implUpdateSecondGameModesPanel(event, panelObj, handler) {
  if (!handler?.isValid() || !panelObj.isValid())
    return

  if (event == null) {
    panelObj.isEmpty = "yes"
    handler.updateTopNoticesBlockPos?()
    return
  }

  panelObj.isInSquad = isSquadMember() ? "yes" : "no"

  if (panelObj.childrenCount() == 0)
    fillSecondModes(panelObj, handler)

  let isPanelEmpty = !hasSecondGameModes(event)
  panelObj.isEmpty = isPanelEmpty ? "yes" : "no"
  if (isPanelEmpty)
    handler.updateTopNoticesBlockPos?()
  else
    updateSecondGameModes(panelObj, event, handler)
}

function updateSecondGameModesPanel(event, panelObj, handler, forceUpdate = false) {
  if (isInUpdate)
    return

  clearTimer(UPDATE_SECOND_MODES_DELAY_ID)
  if (forceUpdate) {
    implUpdateSecondGameModesPanel(event, panelObj, handler)
    return
  }

  setTimeout(UPDATE_SECOND_MODES_DELAY, @() implUpdateSecondGameModesPanel(event, panelObj, handler), UPDATE_SECOND_MODES_DELAY_ID)
}

function onEventSquadStatusChanged(data) {
  if (!data?.isLeaderChanged)
    return
  deferNotifySecondGameModesStateChanges()
}

addListenersWithoutEnv({
  SquadMemberAdded = @(_p) deferNotifySecondGameModesStateChanges()
  SquadDataUpdated = @(_p) deferNotifySecondGameModesStateChanges()
  SquadStatusChanged = @(data) onEventSquadStatusChanged(data)
})

return {
  updateSecondGameModesPanel
  setSecondGameModeActive
  deferNotifySecondGameModesStateChanges
}