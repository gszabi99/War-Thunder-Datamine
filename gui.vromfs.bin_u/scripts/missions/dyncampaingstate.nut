from "%scripts/dagui_library.nut" import *
let { dynamicInit } = require("dynamicMission")
let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")

const DYN_CAMPAIGN_PROGRESS_MSG_ID = "dynamic_init_msg"

let isInRequestDynamicInit = hardPersistWatched("isInRequestDynamicInit", false)

function showWaitAnimation(isVisible) {
  if (isVisible)
    progressMsg.create(DYN_CAMPAIGN_PROGRESS_MSG_ID, { text = loc("loading") })
  else
    progressMsg.destroy(DYN_CAMPAIGN_PROGRESS_MSG_ID)
}

isInRequestDynamicInit.subscribe(showWaitAnimation)

function dynamicInitAsync(settings, map) {
  isInRequestDynamicInit.set(true)
  dynamicInit(settings, map)
}

eventbus_subscribe("dynamicCampaignInited", function(_) {
  isInRequestDynamicInit.set(false)
  broadcastEvent("DynamicCampaignInited")
})

let isFirstGeneration = persist("isFirstGeneration", @() { value = true})

return {
  dynamicInitAsync
  isFirstGeneration
}
