from "%rGui/globals/ui_library.nut" import *
let { subscribe } = require("eventbus")

let isMultiplayer = persist("isMultiplayer", @() Watched(false))

subscribe("setIsMultiplayerState", @(v) isMultiplayer(v.isMultiplayer))

return {
  isMultiplayer
}