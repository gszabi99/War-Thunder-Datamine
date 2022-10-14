from "%rGui/globals/ui_library.nut" import *

let { inspectorToggle } = require("%darg/helpers/inspector.nut")
let { register_command } = require("console")

register_command(@() inspectorToggle(), "ui.inspector")