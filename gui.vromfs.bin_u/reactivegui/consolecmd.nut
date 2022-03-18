let { inspectorToggle } = require("%darg/components/inspector.nut")
let { register_command } = require("console")

register_command(@() inspectorToggle(), "ui.inspector")