//checked for plus_string
from "%scripts/dagui_library.nut" import *

::mission_rules.EnduringConfrontation <- class extends ::mission_rules.Base {
  function isStayOnRespScreen() {
    return false
  }
}