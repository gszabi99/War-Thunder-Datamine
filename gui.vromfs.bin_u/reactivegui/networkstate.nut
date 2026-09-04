from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

let isMultiplayer = mkWatched(persist, "isMultiplayer", false)

eventbus_subscribe("setIsMultiplayerState", @(v) isMultiplayer.set(v.isMultiplayer))

return {
  isMultiplayer
}