from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

let isMultiplayer = mkWatched(persist, "isMultiplayer", false)

eventbus_subscribe("setIsMultiplayerState", @(v) isMultiplayer(v.isMultiplayer))

return {
  isMultiplayer
}