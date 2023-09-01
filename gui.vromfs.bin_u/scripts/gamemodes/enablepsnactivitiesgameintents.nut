//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { switchGameModeByGameIntent } = require("%scripts/gameModes/psnActivities.nut")
let { subscribe } = require("eventbus")

subscribe("psnEventGameIntentLaunchActivity", switchGameModeByGameIntent)
subscribe("psnEventGameIntentLaunchMultiplayerActivity", switchGameModeByGameIntent)
