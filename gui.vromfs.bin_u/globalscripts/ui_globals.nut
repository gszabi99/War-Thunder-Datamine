//this file included to both ui VM
#explicit-this
#no-root-fallback
let logs = require("logs.nut")

let {loc} = require("dagor.localize")
let utf8 = require("utf8")

return {utf8, loc}.__update(logs)