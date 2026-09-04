import "%globalScripts/iconRender/forceRealTimeRenderIcon.nut" as forceRealTimeRenderIcon
from "%darg/helpers/inspector.nut" import inspectorToggle
from "console" import register_command
from "%rGui/globals/ui_library.nut" import *

register_command(@() inspectorToggle(), "ui.inspector")
register_command(@(val) forceRealTimeRenderIcon.set(val),
  "debug.setDebugRenderIcon",
  "[null] = turn off, [''] = turn on for all icons, [<template name>] = turn on for specific template in scene"
)