//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { generateQrBlocks } = require("%sqstd/qrCode.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getAuthenticatedUrlConfig, getUrlWithQrRedirect } = require("%scripts/onlineShop/url.nut")
let mulArr = @(arr, mul) $"{arr[0] * mul}, {arr[1] * mul}"

local class qrWindow (gui_handlers.BaseGuiHandlerWT) {
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
  qrCodes = null

  getSceneTplView = @() {
    headerText = this.headerText
    qrCodes = this.getQrCodeView()
    buttons = this.buttons
    infoText = this.infoText ?? $"{loc("qrWindow/info")} {this.additionalInfoText}"
  }

  function initScreen() {
    if ((this.qrCodes?.len() ?? 0) == 0) {
      this.goBack()
      return
    }
    this.scene.findObject("wnd_update").setUserData(this)

    if (!::is_mouse_last_time_used()) {
      let firstBtn = this.scene.findObject("btnLink_0")
      if (firstBtn?.isValid())
        move_mouse_on_obj(firstBtn)
    }
  }

  function getQrCodeView() {
    this.qrCodes = []
    let isAllowExternalLink = hasFeature("AllowExternalLink")
    local max_size = 0
    this.qrSize = this.qrSize ?? to_pixels("0.5@sf")

    foreach ( idx, qrData in this.qrCodesData ) {
      let urlConfig = getAuthenticatedUrlConfig(qrData.url)
      if (urlConfig == null || urlConfig.urlWithoutTags == "")
        continue

      let urlForQr = this.needUrlWithQrRedirect ? getUrlWithQrRedirect(urlConfig.url) : urlConfig.url
      let list = generateQrBlocks(urlForQr)
      let cellSize = (this.qrSize.tofloat() / (list.size + 8)).tointeger()
      let size = cellSize * (list.size + 8)
      if ( max_size < size ) {
        max_size = size
      }
      this.qrCodes.append({
        btnId = $"btnLink_{idx}"
        urlWithoutTags = urlConfig.urlWithoutTags
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
    foreach ( qrData in this.qrCodes ) {
      qrData.qrSize = max_size
      qrData.padding = (max_size - qrData.listSize * qrData.cellSize)/2
    }
    return this.qrCodes
  }

  function updateQrCode() {
    let data = handyman.renderCached("%gui/commonParts/qrCodes.tpl", {qrCodes = this.getQrCodeView()})
    this.guiScene.replaceContentFromText(this.scene.findObject("wnd_content"), data, data.len(), this)
  }

  function onUpdate(_obj, _dt) {
    this.updateQrCode()
  }

  function goBack() {
    this.onEscapeCb?()
    base.goBack()
  }
}

gui_handlers.qrWindow <- qrWindow

return @(params) handlersManager.loadHandler(qrWindow, params)

