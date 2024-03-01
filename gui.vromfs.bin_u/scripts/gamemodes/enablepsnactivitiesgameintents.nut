from "%scripts/dagui_library.nut" import *

let { switchGameModeByGameIntent } = require("%scripts/gameModes/psnActivities.nut")
let { eventbus_subscribe } = require("eventbus")

eventbus_subscribe("psnEventGameIntentLaunchActivity", switchGameModeByGameIntent)
eventbus_subscribe("psnEventGameIntentLaunchMultiplayerActivity", switchGameModeByGameIntent)
