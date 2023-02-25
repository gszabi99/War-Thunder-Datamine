//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let personalOffers = require("personalOffers")
let DataBlock = require("DataBlock")
let { parse } = require("json")
let { charSendBlk } = require("chard")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { hoursToString, secondsToHours } = require("%scripts/time.nut")

let class PersonalOfferHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/profile/personalOfferWnd.blk"

  offerName = ""
  timeExpired = -1
  costOffer = null
  offerContent = null

  function initScreen() {
    this.updateButtons()
    this.updateRewards()
    if (this.timeExpired > 0) {
      this.updateTimeLeftText()
      this.scene.findObject("update_timer").setUserData(this)
    }
  }

  function updateRewards() {
    let data = ::trophyReward.getRewardsListViewData(this.offerContent,
      { multiAwardHeader = true
        widthByParentParent = true
        header = loc("mainmenu/you_will_receive")
      })
    this.guiScene.replaceContentFromText(this.scene.findObject("offer_markup"), data, data.len(), this)
  }

  function updateButtons() {
    placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnBuy"), this.costOffer)
  }

  function updateTimeLeftText() {
    let timeLeftSec = this.timeExpired - ::get_charserver_time_sec()
    let timerObj = this.showSceneBtn("time_expired_text", timeLeftSec > 0)
    if (timeLeftSec <= 0)
      return

    timerObj.setValue(loc("specialOffer/TimeSec", {
      time = colorize("userlogColoredText", hoursToString(secondsToHours(timeLeftSec)))
    }))
  }

  function onBuyImpl() {
    let blk = DataBlock()
    blk.addStr("offer", this.offerName)
    let taskId = charSendBlk("cln_buy_personal_offer", blk)
    let cb = Callback(@() this.goBack(), this)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, cb)
  }

  function onBuy() {
    let msgText = ::warningIfGold(
      loc("onlineShop/needMoneyQuestion", {
          purchase = loc("specialOffer"),
          cost = this.costOffer.getTextAccordingToBalance()
        }),
        this.costOffer)
    this.msgBox("purchase_ask", msgText,
      [
        ["yes", function() {
          if (::check_balance_msgBox(this.costOffer))
            this.onBuyImpl()
        }],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null }
    )
  }

  function onTimer(_obj, _dt) {
    this.updateTimeLeftText()
  }
}

::gui_handlers.PersonalOfferHandler <- PersonalOfferHandler

let function checkShowPersonalOffers() {
  let count = personalOffers.count()
  for (local i = 0; i < count; ++i) {
    let personalOffer = personalOffers.get(i)
    let data  = parse(personalOffer.text)
    let { offer = "" } = data
    if (offer == "")
      continue
    let offerBlk = DataBlock()
    if (!offerBlk.loadFromText(offer, offer.len()))
      continue

    if ((offerBlk?.costGold ?? 0) == 0)
      continue

    ::handlersManager.loadHandler(PersonalOfferHandler, {
      offerName = personalOffer.key
      timeExpired = (personalOffer?.timeExpired ?? 0).tointeger()
      costOffer = ::Cost(0, offerBlk.costGold)
      offerContent = offerBlk % "i"
    })
    return
  }
}

return {
  checkShowPersonalOffers
}