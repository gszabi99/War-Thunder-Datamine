//this file included to both ui VM
let realRoot = ::getroottable()
realRoot.regexp2 <- require("regexp2")

let { dlog, wlog, console_print } = require("std/log.nut")(/*TODO: toString need to be here*/)

realRoot.loc <- require("dagor.localize").loc
realRoot.utf8 <- require("utf8")

realRoot.wdlog <- @(watched, prefix = "") wlog(watched, prefix, dlog) //disable: -dlog-warn
realRoot.console_print <- console_print

realRoot.dlog <- dlog