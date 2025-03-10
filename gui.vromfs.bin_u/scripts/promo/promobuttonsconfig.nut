from "%scripts/dagui_library.nut" import *

let promoButtonsConfig = {}

let addPromoButtonConfig = kwarg(function addPromoButtonConfig(promoButtonId, buttonType = null, getText = null,
  collapsedIcon = null, collapsedText = null, needUpdateByTimer = false, getCustomSeenId = null,
  updateFunctionInHandler = null, updateByEvents = null, image = null, aspect_ratio = null) {
  promoButtonsConfig[promoButtonId] <- {
    buttonType              
    getText                 
    collapsedIcon
    collapsedText
    image
    aspect_ratio
    getCustomSeenId         
    updateFunctionInHandler 
    updateByEvents          
    needUpdateByTimer       
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