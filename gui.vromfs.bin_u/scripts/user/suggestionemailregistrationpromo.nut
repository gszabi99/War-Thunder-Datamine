from "%scripts/promo/promo.nut" import getPromoVisibilityById
from "%scripts/user/suggestionEmailRegistration.nut" import launchEmailRegistration, canEmailRegistration
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%sqstd/platform.nut" import isSony, isXbox
from "steam" import steam_is_running
from "%scripts/dagui_library.nut" import *

addPromoAction("email_registration", @(_handler, _params, _obj) launchEmailRegistration())

const promoButtonId = "email_registration_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "imageButton"
  getText = @() loc("promo/btnXBOXAccount_linked")
  image = isSony ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_psn_promo?P1"
    : isXbox ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_xbox_promo?P1"
    : steam_is_running() ? "https://staticfiles.warthunder.com/upload/image/Promo/2022_03_steam_promo?P1"
    : ""
  aspect_ratio = 2.07
  updateFunctionInHandler = function() {
    let isVisible = this.isShowAllCheckBoxEnabled()
      || (canEmailRegistration() && getPromoVisibilityById(promoButtonId))
    showObjById(promoButtonId, isVisible, this.scene)
  }
})