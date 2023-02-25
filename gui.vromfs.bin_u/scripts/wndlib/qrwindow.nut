//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { generateQrBlocks } = require("%sqstd/qrCode.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getAuthenticatedUrlConfig, getUrlWithQrRedirect } = require("%scripts/onlineShop/url.nut")

let mulArr = @(arr, mul) $"{arr[0] * mul}, {arr[1] * mul}"

local class qrWindow extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/wndLib/qrWindow.tpl"

  headerText = ""
  baseUrl = ""
  urlWithoutTags = ""
  additionalInfoText = ""
  infoText = null

  qrSize = null
  buttons = null
  onEscapeCb = null

  needUrlWithQrRedirect = false
  needShowUrlLink = true

  getSceneTplView = @() {
    headerText = this.headerText
    qrCode = this.getQrCodeView()
    baseUrl = this.baseUrl
    urlWithoutTags = this.urlWithoutTags
    buttons = this.buttons
    needShowUrlLink = this.needShowUrlLink
    isAllowExternalLink = hasFeature("AllowExternalLink") && !::is_vendor_tencent()
    infoText = this.infoText ?? $"{loc("qrWindow/info")} {this.additionalInfoText}"
  }

  function initScreen() {
    if (this.baseUrl == "" || this.urlWithoutTags == "")
      this.goBack()

    this.scene.findObject("wnd_update").setUserData(this)
  }

  function getQrCodeView() {
    let urlConfig = getAuthenticatedUrlConfig(this.baseUrl)
    if (urlConfig == null)
      return null

    this.urlWithoutTags = urlConfig.urlWithoutTags
    let urlForQr = this.needUrlWithQrRedirect ? getUrlWithQrRedirect(urlConfig.url) : urlConfig.url
    let list = generateQrBlocks(urlForQr)
    let cellSize = ((this.qrSize ?? to_pixels("0.5@sf")).tofloat() / (list.size + 8)).tointeger()
    let size = cellSize * (list.size + 8)
    return {
      qrSize = size
      cellSize = cellSize
      qrBlocks = list.list.map(@(b) {
        blockSize = mulArr(b.size, cellSize)
        blockPos = mulArr(b.pos, cellSize)
      })
    }
  }

  function updateQrCode() {
    let data = ::handyman.renderCached("%gui/commonParts/qrCode.tpl", this.getQrCodeView())
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

::gui_handlers.qrWindow <- qrWindow

return @(params) ::handlersManager.loadHandler(qrWindow, params)

