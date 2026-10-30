import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/missions/missionsUtils.nut" import hasUnitInFullMissionBlk
from "%appGlobals/ranks_common_shared.nut" import validate_custom_mission
from "string" import format
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import abort_all_downloads, abort_download, download_blk
from "%scripts/dagui_library.nut" import *

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")

let unitTypes = require("%scripts/unit/unitTypesList.nut")

const DOWNLOAD_EVENT = "urlMissionDownload"
let downloadListeners = {}

eventbus_subscribe(DOWNLOAD_EVENT, function(evt) {
  let onEvent = evt?.done ? downloadListeners.$rawdelete(evt.reqId) : downloadListeners?[evt.reqId]
  onEvent?(evt)
})

function upgradeUrlMission(fullMissionBlk) {
  let misBlk = fullMissionBlk?.mission_settings.mission
  if (!fullMissionBlk || !misBlk)
    return

  if (misBlk?.useKillStreaks && !misBlk?.allowedKillStreaks)
    misBlk.useKillStreaks = false

  foreach (unitType in unitTypes.types)
    if (unitType.isAvailable() && !(unitType.missionSettingsAvailabilityFlag in misBlk))
      misBlk[unitType.missionSettingsAvailabilityFlag] = hasUnitInFullMissionBlk(fullMissionBlk, unitType)
}

register_gui_handler("LoadingUrlMissionModal", class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/msgBox.blk"
  timeToShowCancel = 3
  timer = -1

  buttonCancelId = "btn_cancel"
  buttonOkId = "btn_ok"

  curMission = null
  urlMission = null
  callback = null

  isCancel = false
  requestId = null
  requestSuccess = false
  loadingProgress = 0
  progressChanged = true

  function initScreen() {
    if (!this.curMission?.urlMission)
      return this.goBack()

    this.urlMission = this.curMission.urlMission
    this.createButton(this.buttonCancelId, "#msgbox/btn_cancel", "onCancel")
    this.createButton(this.buttonOkId, "#msgbox/btn_ok", "goBack")

    this.scene.findObject("msgWaitAnimation").show(true)
    this.scene.findObject("msg_box_timer").setUserData(this)

    this.resetTimer()
    this.loadUrlMission()
    this.onUpdate(null, 0.0)
  }

  function createButton(btnId, text, callbackName) {
    let data = format("Button_text { id:t='%s'; btnName:t='AB'; text:t='%s'; on_click:t='%s' }", btnId, text, callbackName)
    let holderObj = this.scene.findObject("buttons_holder")
    if (!holderObj)
      return

    this.guiScene.appendWithBlk(holderObj, data, this)
    showObjById(btnId, false, this.scene)
  }

  function loadUrlMission() {
    this.requestId = download_blk(this.urlMission.url, 0, DOWNLOAD_EVENT)
    downloadListeners[this.requestId] <- Callback(this.onDownloadEvent, this)
  }

  function onDownloadEvent(evt) {
    if (evt?.done)
      this.onLoadingEnded(evt.success, evt?.blk)
    else
      this.onProgress(evt.dltotal, evt.dlnow)
  }

  function resetTimer() {
    this.timer = this.timeToShowCancel
    showObjById(this.buttonCancelId, false, this.scene)
  }

  function onUpdate(_obj, dt) {
    if (this.progressChanged) {
      this.progressChanged = false
      if (this.loadingProgress >= 0) {
        this.updateText(loc("wait/missionDownload", { name = this.urlMission.name, progress = this.loadingProgress.tostring() }))
      }
    }

    if (this.timer < 0)
      return

    this.timer -= dt
    if (this.timer < 0)
      showObjById(this.buttonCancelId, true, this.scene)
  }

  function onLoadingEnded(success, blk) {
    this.timer = -1
    this.requestSuccess = success
    this.progressChanged = false
    if (this.isCancel)
      return this.goBack()

    local errorText = loc("wait/ugm_download_failed")
    if (success) {
      upgradeUrlMission(blk)
      errorText = validate_custom_mission(blk)
      this.requestSuccess = u.isEmpty(errorText)
      success = this.requestSuccess
      if (!success)
        errorText = loc("wait/ugm_not_valid", { errorText = errorText })
    }

    g_url_missions.setLoadingCompeteState(this.urlMission, !success, blk)

    if (success)
      return this.goBack()

    this.updateText(errorText)
    this.scene.findObject("msgWaitAnimation").show(false)
    showObjById(this.buttonCancelId, false, this.scene)
    showObjById(this.buttonOkId, true, this.scene)
  }

  function updateText(text) {
    this.scene.findObject("msgText").setValue(text)
  }

  function onProgress(dltotal, dlnow) {
    this.loadingProgress = dltotal ? (100.0 * dlnow / dltotal).tointeger() : 0
    this.progressChanged = true
  }

  function onCancel() {
    this.isCancel = true
    abort_download(this.requestId)
    showObjById(this.buttonCancelId, false, this.scene)
  }

  function onEventSignOut() {
    abort_all_downloads()
  }

  function afterModalDestroy() {
    if (this.callback != null)
      this.callback(this.requestSuccess, this.curMission)
  }
})
