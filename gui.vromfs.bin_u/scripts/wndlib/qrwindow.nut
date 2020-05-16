local { generateQrBlocks } = require("std/qrCode.nut")
local { getAuthenticatedUrlConfig } = require("scripts/onlineShop/url.nut")

local mulArr = @(arr, mul) $"{arr[0] * mul}, {arr[1] * mul}"

local class qrWindow extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "gui/wndLib/qrWindow"

  headerText = ""
  baseUrl = ""
  urlWithoutTags = ""
  qrSize = null

  function getSceneTplView()
  {
    return {
      headerText = headerText
      qrCode = getQrCodeView()
      baseUrl = baseUrl
      urlWithoutTags = urlWithoutTags
      isAllowExternalLink = ::has_feature("AllowExternalLink") && !::is_vendor_tencent()
    }
  }

  function initScreen() {
    if (baseUrl == "" || urlWithoutTags == "")
      goBack()

    scene.findObject("wnd_update").setUserData(this)
    restoreFocus()
  }

  function getQrCodeView() {
    local urlConfig = getAuthenticatedUrlConfig(baseUrl)
    if (urlConfig == null)
      return null

    urlWithoutTags = urlConfig.urlWithoutTags
    local list = generateQrBlocks(urlConfig.url)
    local cellSize = ((qrSize ?? ::to_pixels("0.5@sf")).tofloat() / (list.size + 8)).tointeger()
    local size = cellSize * (list.size + 8)
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
    local data = ::handyman.renderCached("gui/commonParts/qrCode", getQrCodeView())
    guiScene.replaceContentFromText(scene.findObject("wnd_content"), data, data.len(), this)
  }

  function onUpdate(obj, dt) {
    updateQrCode()
  }
}

::gui_handlers.qrWindow <- qrWindow

return @(params) ::handlersManager.loadHandler(qrWindow, params)

