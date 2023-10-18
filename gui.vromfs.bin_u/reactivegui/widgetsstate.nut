from "%rGui/globals/ui_library.nut" import *
let { subscribe } = require("eventbus")

let widgets = mkWatched(persist, "widgets", [])

subscribe("updateWidgets", @(v) widgets(v.widgetsList ?? []))

return widgets