from "%rGui/globals/ui_library.nut" import *
let { subscribe } = require("eventbus")

let widgets = persist("widgets", @() Watched([]))

subscribe("updateWidgets", @(v) widgets(v.widgetsList ?? []))

return widgets