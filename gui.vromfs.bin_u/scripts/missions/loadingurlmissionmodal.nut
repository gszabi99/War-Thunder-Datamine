from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.LoadingUrlMissionModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    if (!curMission?.urlMission)
      return this.goBack()

    urlMission = curMission.urlMission
    createButton(buttonCancelId, "#msgbox/btn_cancel" ,"onCancel")
    createButton(buttonOkId, "#msgbox/btn_ok" ,"goBack")

    this.scene.findObject("msgWaitAnimation").show(true)
    this.scene.findObject("msg_box_timer").setUserData(this)

    resetTimer()
    loadUrlMission()
    onUpdate(null, 0.0)
  }

  function createButton(btnId, text, callbackName)
  {
    let data = format("Button_text { id:t='%s'; btnName:t='AB'; text:t='%s'; on_click:t='%s' }", btnId, text, callbackName)
    let holderObj = this.scene.findObject("buttons_holder")
    if (!holderObj)
      return

    this.guiScene.appendWithBlk(holderObj, data, this)
    this.showSceneBtn(btnId, false)
  }

  function loadUrlMission()
  {
    let requestCallback = Callback(function(success, blk) {
                                          onLoadingEnded(success, blk)
                                        }, this)

    let progressCallback = Callback(function(dltotal, dlnow) {
                                          onProgress(dltotal, dlnow)
                                        }, this)

    requestId = ::download_blk(urlMission.url, 0, (@(requestCallback) function(success, blk) {
                                                                 requestCallback(success, blk)
                                                               })(requestCallback),
                                                               (@(progressCallback) function(dltotal, dlnow) {
                                                                 progressCallback(dltotal, dlnow)
                                                               })(progressCallback))
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    this.showSceneBtn(buttonCancelId, false)
  }

  function onUpdate(_obj, dt)
  {
    if (progressChanged)
    {
      progressChanged = false
      if (loadingProgress >= 0)
      {
        updateText(loc("wait/missionDownload", {name = urlMission.name, progress = loadingProgress.tostring()}))
      }
    }

    if (timer < 0)
      return

    timer -= dt
    if (timer < 0)
      this.showSceneBtn(buttonCancelId, true)
  }

  function onLoadingEnded(success, blk)
  {
    timer = -1
    requestSuccess = success
    progressChanged = false
    if (isCancel)
      return this.goBack()

    local errorText = loc("wait/ugm_download_failed")
    if (success)
    {
      ::upgrade_url_mission(blk)
      errorText = ::validate_custom_mission(blk)
      requestSuccess = ::u.isEmpty(errorText)
      success = requestSuccess
      if (!success)
        errorText = loc("wait/ugm_not_valid", {errorText = errorText})
    }

    ::g_url_missions.setLoadingCompeteState(urlMission, !success, blk)

    if (success)
      return this.goBack()

    updateText(errorText)
    this.scene.findObject("msgWaitAnimation").show(false)
    this.showSceneBtn(buttonCancelId, false)
    this.showSceneBtn(buttonOkId, true)
  }

  function updateText(text)
  {
    this.scene.findObject("msgText").setValue(text)
  }

  function onProgress(dltotal, dlnow)
  {
    loadingProgress = dltotal ? (100.0 * dlnow / dltotal).tointeger() : 0
    progressChanged = true
  }

  function onCancel()
  {
    isCancel = true
    ::abort_download(requestId)
    this.showSceneBtn(buttonCancelId, false)
  }

  function onEventSignOut()
  {
    ::abort_all_downloads()
  }

  function afterModalDestroy()
  {
    if (callback != null)
      callback(requestSuccess, curMission)
  }
}
