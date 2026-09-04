from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

let widgets = mkWatched(persist, "widgets", [])

eventbus_subscribe("updateWidgets", @(v) widgets.set(v.widgetsList ?? []))

return widgets