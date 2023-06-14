//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.LoadingUrlMissionModal <- class extends ::gui_handlers.BaseGuiHandlerWT {
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
    this.showSceneBtn(btnId, false)
  }

  function loadUrlMission() {
    let requestCallback = Callback(function(success, blk) {
                                          this.onLoadingEnded(success, blk)
                                        }, this)

    let progressCallback = Callback(function(dltotal, dlnow) {
                                          this.onProgress(dltotal, dlnow)
                                        }, this)

    this.requestId = ::download_blk(this.urlMission.url, 0,
      @(success, blk) requestCallback(success, blk),
      @(dltotal, dlnow) progressCallback(dltotal, dlnow))
  }

  function resetTimer() {
    this.timer = this.timeToShowCancel
    this.showSceneBtn(this.buttonCancelId, false)
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
      this.showSceneBtn(this.buttonCancelId, true)
  }

  function onLoadingEnded(success, blk) {
    this.timer = -1
    this.requestSuccess = success
    this.progressChanged = false
    if (this.isCancel)
      return this.goBack()

    local errorText = loc("wait/ugm_download_failed")
    if (success) {
      ::upgrade_url_mission(blk)
      errorText = ::validate_custom_mission(blk)
      this.requestSuccess = u.isEmpty(errorText)
      success = this.requestSuccess
      if (!success)
        errorText = loc("wait/ugm_not_valid", { errorText = errorText })
    }

    ::g_url_missions.setLoadingCompeteState(this.urlMission, !success, blk)

    if (success)
      return this.goBack()

    this.updateText(errorText)
    this.scene.findObject("msgWaitAnimation").show(false)
    this.showSceneBtn(this.buttonCancelId, false)
    this.showSceneBtn(this.buttonOkId, true)
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
    ::abort_download(this.requestId)
    this.showSceneBtn(this.buttonCancelId, false)
  }

  function onEventSignOut() {
    ::abort_all_downloads()
  }

  function afterModalDestroy() {
    if (this.callback != null)
      this.callback(this.requestSuccess, this.curMission)
  }
}
