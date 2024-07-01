from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { generateQrBlocks } = require("%sqstd/qrCode.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { requestAuthenticatedUrl, getUrlWithQrRedirect } = require("%scripts/onlineShop/url.nut")
let { eventbus_subscribe } = require("eventbus")

let mulArr = @(arr, mul) $"{arr[0] * mul}, {arr[1] * mul}"

local class qrWindow (BaseGuiHandler) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/wndLib/qrWindow.tpl"

  headerText = ""
  qrCodesData = null
  additionalInfoText = ""
  infoText = null
  qrSize = null
  buttons = null
  onEscapeCb = null
  needUrlWithQrRedirect = false
  needShowUrlLink = true

  getSceneTplView = @() {
    headerText = this.headerText
    qrCodes = this.getQrCodeView()
    buttons = this.buttons
    infoText = this.infoText ?? $"{loc("qrWindow/info")} {this.additionalInfoText}"
  }

  function initScreen() {
    if ((this.qrCodesData?.len() ?? 0) == 0) {
      this.goBack()
      return
    }
    this.updateAuthenticatedUrl()

    this.scene.findObject("wnd_update").setUserData(this)

    if (!is_mouse_last_time_used()) {
      let firstBtn = this.scene.findObject("btnLink_0")
      if (firstBtn?.isValid())
        move_mouse_on_obj(firstBtn)
    }
  }

  function getQrCodeView() {
    let qrCodes = []
    let isAllowExternalLink = hasFeature("AllowExternalLink")
    local max_size = 0
    this.qrSize = this.qrSize ?? to_pixels("0.5@sf")

    foreach (idx, qrData in this.qrCodesData) {
      let { urlWithoutTags = null, urlToOpen = null, url } = qrData
      let urlForQr = this.needUrlWithQrRedirect ? getUrlWithQrRedirect(urlToOpen ?? url) : urlToOpen ?? url
      let list = generateQrBlocks(urlForQr)
      let cellSize = (this.qrSize.tofloat() / (list.size + 8)).tointeger()
      let size = cellSize * (list.size + 8)
      if ( max_size < size ) {
        max_size = size
      }
      qrCodes.append({
        btnId = $"btnLink_{idx}"
        urlWithoutTags = urlWithoutTags
        needShowUrlLink = this.needShowUrlLink
        isAllowExternalLink
        qrText = qrData?.text
        qrSize = size
        buttonKey = idx == 0 ? "X" : null
        cellSize = cellSize
        padding = (size - list.size * cellSize)/2
        baseUrl = qrData.url
        listSize = list.size
        qrBlocks = list.list.map(@(b) {
          blockSize = mulArr(b.size, cellSize)
          blockPos = mulArr(b.pos, cellSize)
        })
      })
    }
    foreach (qrData in qrCodes) {
      qrData.qrSize = max_size
      qrData.padding = (max_size - qrData.listSize * qrData.cellSize)/2
    }
    return qrCodes
  }

  function updateAuthenticatedUrl() {
    foreach (qrData in this.qrCodesData)
      requestAuthenticatedUrl(qrData.url, "updateQrCodeUrlData")
  }

  function setUrlData(urlConfig) {
    let { baseUrl, urlToOpen, urlWithoutTags } = urlConfig
    let qrDataIdx = this.qrCodesData.findindex(@(v) v.url == baseUrl)
    if (qrDataIdx == null)
      return

    this.qrCodesData[qrDataIdx].__update({urlToOpen, urlWithoutTags})
    this.updateQrCode()
  }

  function updateQrCode() {
    let data = handyman.renderCached("%gui/commonParts/qrCodes.tpl", {qrCodes = this.getQrCodeView()})
    this.guiScene.replaceContentFromText(this.scene.findObject("wnd_content"), data, data.len(), this)
  }

  function onUpdate(_obj, _dt) {
    this.updateAuthenticatedUrl()
  }

  function goBack() {
    this.onEscapeCb?()
    base.goBack()
  }
}

gui_handlers.qrWindow <- qrWindow

eventbus_subscribe("updateQrCodeUrlData", function(urlConfig) {
  let handler = handlersManager.findHandlerClassInScene(qrWindow)
  if (handler == null)
    return

  handler.setUrlData(urlConfig)
})

return @(params) handlersManager.loadHandler(qrWindow, params)
