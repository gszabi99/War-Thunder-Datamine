//this file included to both ui VM
let { dlog, wlog, console_print } = require("%sqstd/log.nut")(/*TODO: toString need to be here*/)

let realRoot = ::getroottable()
realRoot.loc <- require("dagor.localize").loc
realRoot.utf8 <- require("utf8")

realRoot.wdlog <- @(watched, prefix = "", transform = null) wlog(watched, prefix, transform, dlog) //disable: -dlog-warn
realRoot.console_print <- console_print

realRoot.dlog <- dlog