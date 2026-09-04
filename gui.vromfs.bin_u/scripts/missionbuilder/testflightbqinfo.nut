from "guiOptions" import get_gui_option
from "chard" import get_charserver_time_sec
from "%scripts/dagui_library.nut" import *

let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { USEROPT_DIFFICULTY } = require("%scripts/options/optionsExtNames.nut")

let testFlightData = {
  diff = ""
  unit = ""
  sessionStartSec = 0
}

function sendStartTestFlightToBq(unitName) {
  testFlightData.unit = unitName
  testFlightData.diff = get_gui_option(USEROPT_DIFFICULTY)
  testFlightData.sessionStartSec = get_charserver_time_sec()
  sendBqEvent("CLIENT_GAMEPLAY_1", "testdrive.start", testFlightData)
}

function sendFinishTestFlightToBq() {
  sendBqEvent("CLIENT_GAMEPLAY_1", "testdrive.finish", testFlightData.__merge({
    sessionTimeSec = get_charserver_time_sec() - testFlightData.sessionStartSec
  }))
}

return {
  sendStartTestFlightToBq
  sendFinishTestFlightToBq
}