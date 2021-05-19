local promoButtonsConfig = {}

local addPromoButtonConfig = ::kwarg(function addPromoButtonConfig(promoButtonId, buttonType = null, getText = null,
  collapsedIcon = null, collapsedText = null, needUpdateByTimer = false, getCustomSeenId = null,
  updateFunctionInHandler = null, updateByEvents = null)
{
  promoButtonsConfig[promoButtonId] <- {
    buttonType              //custom visual type of promo
    getText                 //function for custom text of promo
    collapsedIcon
    collapsedText
    getCustomSeenId         //function
    updateFunctionInHandler // function for update promo in promo handler
    updateByEvents          // array with events name, for handler subscribe on update of promo
    needUpdateByTimer       // bool. for update promo in handler by timer
  }
})

local getPromoButtonConfig = @(buttonId) promoButtonsConfig?[buttonId]

local getPromoHandlerUpdateConfigs = @() promoButtonsConfig.map(
  @(c) {
    updateFunctionInHandler = c?.updateFunctionInHandler
    updateByEvents = c?.updateByEvents
  })

return {
  addPromoButtonConfig
  getPromoButtonConfig
  getPromoHandlerUpdateConfigs
}