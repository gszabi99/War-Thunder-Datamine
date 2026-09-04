from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { switchGameModeByGameIntent } = require("%scripts/gameModes/psnActivities.nut")

eventbus_subscribe("psnEventGameIntentLaunchActivity", switchGameModeByGameIntent)
eventbus_subscribe("psnEventGameIntentLaunchMultiplayerActivity", switchGameModeByGameIntent)
