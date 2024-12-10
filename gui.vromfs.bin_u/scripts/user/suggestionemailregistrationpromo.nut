from "%scripts/dagui_library.nut" import *
let { getPromoVisibilityById } = require("%scripts/promo/promo.nut")
let { launchEmailRegistration, canEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { steam_is_running } = require("steam")

addPromoAction("email_registration", @(_handler, _params, _obj) launchEmailRegistration())

let promoButtonId = "email_registration_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "imageButton"
  getText = @() loc("promo/btnXBOXAccount_linked")
  image = isPlatformSony ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_psn_promo?P1"
    : isPlatformXboxOne ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_xbox_promo?P1"
    : steam_is_running() ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_steam_promo?P1"
    : ""
  aspect_ratio = 2.07
  updateFunctionInHandler = function() {
    let isVisible = this.isShowAllCheckBoxEnabled()
      || (canEmailRegistration() && getPromoVisibilityById(promoButtonId))
    showObjById(promoButtonId, isVisible, this.scene)
  }
})