from "eventbus" import eventbus_subscribe
from "%sqstd/globalState.nut" import hardPersistWatched
from "%rGui/globals/ui_library.nut" import *

let widgets = hardPersistWatched("rGui.widgetsState.widgets", [])

eventbus_subscribe("updateWidgets", @(v) widgets.set(v.widgetsList ?? []))

return widgets