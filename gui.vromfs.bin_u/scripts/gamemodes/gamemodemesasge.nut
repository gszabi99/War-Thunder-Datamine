from "%scripts/dagui_library.nut" import *

function showNotAvailableMsgBox() {
  showInfoMsgBox(loc("msgbox/notAvailbleYet"), "not_available", true)
}

return {
  showNotAvailableMsgBox
}