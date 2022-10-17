from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { get_blk_by_path_array } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

/*
  config {
    purchaseData = (::OnlineShopModel.getPurchaseData) //required
    image = (string)  //full path to image
    imageRatioHeight = (float)
    header = (string)
    text = (string)
    checkPackage = (string)  //when entitlement bought ask player to download this package
  }
*/

::gui_handlers.ReqPurchaseWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  purchaseData = null
  checkPackage = null
  header = ""
  text = ""
  image = ""
  imageRatioHeight = 0.75 //same with blk
  btnStoreText = "#msgbox/btn_onlineShop"

  static function open(config)
  {
    if (!("purchaseData" in config) || !config.purchaseData.canBePurchased)
      return
    ::handlersManager.loadHandler(::gui_handlers.ReqPurchaseWnd, config)
  }

  function initScreen()
  {
    guiScene.setUpdatesEnabled(false, false)

    scene.findObject("award_name").setValue(header)
    scene.findObject("award_desc").setValue(text)

    validateImageData()
    let imgObj = scene.findObject("award_image")
    imgObj["background-image"] = image
    imgObj["height"] = imageRatioHeight + "w"

    guiScene.setUpdatesEnabled(true, true)
  }

  function getNavbarTplView()
  {
    return {
      middle = [
        {
          id = "btn_online_store"
          text = btnStoreText
          shortcut = "A"
          funcName = "onOnlineStore"
          isToBattle = true
          button = true
        }
      ]
    }
  }

  function validateImageData()
  {
    if (!::u.isEmpty(image))
      return

    image = "#ui/images/login_reward.jpg?P1"
    let imgBlk = get_blk_by_path_array(["entitlementsAdvert", purchaseData.sourceEntitlement],
                                           ::get_gui_regional_blk())
    if (!::u.isDataBlock(imgBlk))
      return

    let rndImg = ::u.chooseRandom(imgBlk % "image")
    if (::u.isString(rndImg))
    {
      let country = profileCountrySq.value
      image = rndImg.subst({ country = ::g_string.cutPrefix(country, "country_", country) })
    }
    if (::is_numeric(imgBlk?.imageRatio))
      imageRatioHeight = imgBlk.imageRatio
  }

  function onOnlineStore()
  {
    ::OnlineShopModel.openBrowserByPurchaseData(purchaseData)
  }

  function onEventProfileUpdated(p)
  {
    if (!::has_entitlement(purchaseData.sourceEntitlement))
      return

    if (!::u.isEmpty(checkPackage))
      ::check_package_and_ask_download(checkPackage)

    goBack()
  }

  function onFacebookPostLink() {}
  function onFacebookLoginAndPostScrnshot() {}
  function onFacebookLoginAndPostMessage() {}
  function sendInvitation() {}
  function onOk() {}
  function onUseDecorator() {}
  function onUnitActivate() {}
}