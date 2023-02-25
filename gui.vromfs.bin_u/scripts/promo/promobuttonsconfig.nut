//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let promoButtonsConfig = {}

let addPromoButtonConfig = kwarg(function addPromoButtonConfig(promoButtonId, buttonType = null, getText = null,
  collapsedIcon = null, collapsedText = null, needUpdateByTimer = false, getCustomSeenId = null,
  updateFunctionInHandler = null, updateByEvents = null, image = null, aspect_ratio = null) {
  promoButtonsConfig[promoButtonId] <- {
    buttonType              //custom visual type of promo
    getText                 //function for custom text of promo
    collapsedIcon
    collapsedText
    image
    aspect_ratio
    getCustomSeenId         //function
    updateFunctionInHandler // function for update promo in promo handler
    updateByEvents          // array with events name, for handler subscribe on update of promo
    needUpdateByTimer       // bool. for update promo in handler by timer
  }
})

let getPromoButtonConfig = @(buttonId) promoButtonsConfig?[buttonId]

let getPromoHandlerUpdateConfigs = @() promoButtonsConfig.map(
  @(c) {
    updateFunctionInHandler = c?.updateFunctionInHandler
    updateByEvents = c?.updateByEvents
  })

return {
  addPromoButtonConfig
  getPromoButtonConfig
  getPromoHandlerUpdateConfigs
}