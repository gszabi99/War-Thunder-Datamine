import "%sqStdLibs/helpers/u.nut" as u
from "%sqstd/datablock.nut" import getBlkByPathArray
from "%sqstd/string.nut" import cutPrefix
from "blkGetters" import get_gui_regional_blk
from "%scripts/dagui_natives.nut" import has_entitlement
from "%scripts/dagui_library.nut" import *

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { openBrowserByPurchaseData } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkPackageAndAskDownload } = require("%scripts/clientState/contentPacks.nut")












let ReqPurchaseWnd = class (BaseGuiHandlerWT) {
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
    handlersManager.loadHandler(get_gui_handler("ReqPurchaseWnd"), config)
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
      checkPackageAndAskDownload([this.checkPackage])

    this.goBack()
  }

  function sendInvitation() {}
  function onOk() {}
  function onUseDecorator() {}
  function onUnitActivate() {}
}
register_gui_handler("ReqPurchaseWnd", ReqPurchaseWnd)

return { ReqPurchaseWnd }
