from "%rGui/globals/ui_library.nut" import *
let { subscribe } = require("eventbus")

let isMultiplayer = mkWatched(persist, "isMultiplayer", false)

subscribe("setIsMultiplayerState", @(v) isMultiplayer(v.isMultiplayer))

return {
  isMultiplayer
}