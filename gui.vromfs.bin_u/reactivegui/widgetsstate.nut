from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

let widgets = mkWatched(persist, "widgets", [])

eventbus_subscribe("updateWidgets", @(v) widgets(v.widgetsList ?? []))

return widgets