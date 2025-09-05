from "%rGui/globals/ui_library.nut" import *

let { inspectorToggle } = require("%darg/helpers/inspector.nut")
let forceRealTimeRenderIcon = require("%globalScripts/iconRender/forceRealTimeRenderIcon.nut")
let { register_command } = require("console")

register_command(@() inspectorToggle(), "ui.inspector")
register_command(@(val) forceRealTimeRenderIcon.set(val),
  "debug.setDebugRenderIcon",
  "[null] = turn off, [''] = turn on for all icons, [<template name>] = turn on for specific template in scene"
)