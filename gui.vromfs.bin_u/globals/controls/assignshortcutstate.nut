from "frp" import Computed
from "%appGlobals/dargScreenModel.nut" import mkUiWatched



let assignShortcut = mkUiWatched("assignShortcut", @() null)


let isWaitingInput = Computed(@() assignShortcut.get()?.step == "input")

return freeze({
  assignShortcut
  isWaitingInput
})
