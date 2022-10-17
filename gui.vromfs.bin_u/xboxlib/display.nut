from "frp" import Watched
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_DISPLAY] ")
let { forbid_dim, allow_dim, is_dim_allowed } = require("xbox.display")

let isDimAllowed = Watched(is_dim_allowed())


isDimAllowed.subscribe(function(v) {
  let func = v ? allow_dim : forbid_dim
  func()
  logX($"Display dim allowed: {v}")
})


return {
  isDimAllowed
}