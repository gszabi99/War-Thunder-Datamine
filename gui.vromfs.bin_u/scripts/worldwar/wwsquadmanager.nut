from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let DataBlock  = require("DataBlock")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")

let DEFAULT_SQUAD_WW_OPERATION_INFO = { id = -1, country = "", battle = null }

function onWWLoadOperation() {
  if (!g_squad_manager.isSquadLeader())
    return

  g_squad_manager.updatePresenceSquad()
  g_squad_manager.updateCurrentWWOperation()
  g_squad_manager.setSquadData()
}

function onWWStopWorldWar() {
  if (g_squad_manager.getWwOperationId() == -1)
    return

  if (!g_squad_manager.isInSquad() || g_squad_manager.isSquadLeader())
    g_squad_manager.getSquadData().wwOperationInfo.__update(DEFAULT_SQUAD_WW_OPERATION_INFO)

  g_squad_manager.updatePresenceSquad()
  g_squad_manager.setSquadData()
}

function onSquadDataReceived(data) {
  let wwOperationInfo = g_squad_manager.getSquadData().wwOperationInfo
  local isDataChanged = false
  foreach (name, val in (data?.wwOperationInfo ?? DEFAULT_SQUAD_WW_OPERATION_INFO)) {
    if (wwOperationInfo[name] == val)
      continue

    wwOperationInfo[name] = val
    isDataChanged = true
  }

  if ((data?.wwOperationInfo.id ?? -1) > -1
    && !::g_ww_global_status_actions.getOperationById(data.wwOperationInfo.id)) {
      let requestBlk = DataBlock()
      requestBlk.operationId = data.wwOperationInfo.id
      actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk)
  }

  if (isDataChanged)
    broadcastEvent("OperationInfoUpdated")
}

addListenersWithoutEnv({
  SquadDataReceived = @(p) onSquadDataReceived(p?.data)
  WWStopWorldWar     = @(_) onWWStopWorldWar()
  WWLoadOperation    = @(_) onWWLoadOperation()
})