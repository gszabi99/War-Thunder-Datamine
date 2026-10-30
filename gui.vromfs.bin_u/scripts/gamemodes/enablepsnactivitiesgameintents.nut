from "%scripts/gameModes/psnActivities.nut" import switchGameModeByGameIntent
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

eventbus_subscribe("psnEventGameIntentLaunchActivity", switchGameModeByGameIntent)
eventbus_subscribe("psnEventGameIntentLaunchMultiplayerActivity", switchGameModeByGameIntent)
