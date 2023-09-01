//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { get_gui_option } = require("guiOptions")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_charserver_time_sec } = require("chard")

let testFlightData = {
  diff = ""
  unit = ""
  sessionStartSec = 0
}

let function sendStartTestFlightToBq(unitName) {
  testFlightData.unit = unitName
  testFlightData.diff = get_gui_option(::USEROPT_DIFFICULTY)
  testFlightData.sessionStartSec = get_charserver_time_sec()
  sendBqEvent("CLIENT_GAMEPLAY_1", "testdrive.start", testFlightData)
}

let function sendFinishTestFlightToBq() {
  sendBqEvent("CLIENT_GAMEPLAY_1", "testdrive.finish", testFlightData.__merge({
    sessionTimeSec = get_charserver_time_sec() - testFlightData.sessionStartSec
  }))
}

return {
  sendStartTestFlightToBq
  sendFinishTestFlightToBq
}