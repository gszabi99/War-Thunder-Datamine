from "scriptRespondent" import registerRespondent
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent

registerRespondent("onBlksDataStorageLoaded", @() broadcastEvent("BlksDataStorageLoaded"))
