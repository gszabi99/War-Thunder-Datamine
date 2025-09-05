from "%scripts/dagui_natives.nut" import has_entitlement
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { getBlkByPathArray } = require("%sqstd/datablock.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { get_gui_regional_blk } = require("blkGetters")
let { openBrowserByPurchaseData } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkPackageAndAskDownload } = require("%scripts/clientState/contentPacks.nut")












gui_handlers.ReqPurchaseWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  purchaseData = null
  checkPackage = null
  header = ""
  text = ""
  image = ""
  imageRatioHeight = 0.75 
  btnStoreText = "#msgbox/btn_onlineShop"

  static function open(config) {
    if (!("purchaseData" in config) || !config.purchaseData.canBePurchased)
      return
    handlersManager.loadHandler(gui_handlers.ReqPurchaseWnd, config)
  }

  function initScreen() {
    this.guiScene.setUpdatesEnabled(false, false)

    this.scene.findObject("award_name").setValue(this.header)
    this.scene.findObject("award_desc").setValue(this.text)

    this.validateImageData()
    let imgObj = this.scene.findObject("award_image")
    imgObj["background-image"] = this.image
    imgObj["height"] = $"{this.imageRatioHeight}w"

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function getNavbarTplView() {
    return {
      middle = [
        {
          id = "btn_online_store"
          text = this.btnStoreText
          shortcut = "A"
          funcName = "onOnlineStore"
          isToBattle = true
          button = true
        }
      ]
    }
  }

  function validateImageData() {
    if (!u.isEmpty(this.image))
      return

    this.image = "#ui/images/login_reward?P1"
    let imgBlk = getBlkByPathArray(["entitlementsAdvert", this.purchaseData.sourceEntitlement],
                                           get_gui_regional_blk())
    if (!u.isDataBlock(imgBlk))
      return

    let rndImg = u.chooseRandom(imgBlk % "image")
    if (u.isString(rndImg)) {
      let country = profileCountrySq.get()
      this.image = rndImg.subst({ country = cutPrefix(country, "country_", country) })
    }
    if (is_numeric(imgBlk?.imageRatio))
      this.imageRatioHeight = imgBlk.imageRatio
  }

  function onOnlineStore() {
    openBrowserByPurchaseData(this.purchaseData)
  }

  function onEventProfileUpdated(_p) {
    if (!has_entitlement(this.purchaseData.sourceEntitlement))
      return

    if (!u.isEmpty(this.checkPackage))
      checkPackageAndAskDownload(this.checkPackage)

    this.goBack()
  }

  function sendInvitation() {}
  function onOk() {}
  function onUseDecorator() {}
  function onUnitActivate() {}
}