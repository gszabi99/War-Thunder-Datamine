from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

return {
  NOT_IN_ROOM = "NOT_IN_ROOM"
  WAIT_FOR_QUEUE_ROOM = "WAIT_FOR_QUEUE_ROOM"
  CREATING_ROOM = "CREATING_ROOM"
  JOINING_ROOM = "JOINING_ROOM"
  IN_ROOM = "IN_ROOM"
  IN_LOBBY = "IN_LOBBY"
  IN_LOBBY_HIDDEN = "IN_LOBBY_HIDDEN" //in loby, but hidden by joining wnd. Used when lobby after queue before session
  UPLOAD_CONTENT = "UPLOAD_CONTENT"
  START_SESSION = "START_SESSION"
  JOINING_SESSION = "JOINING_SESSION"
  IN_SESSION = "IN_SESSION"
  IN_DEBRIEFING = "IN_DEBRIEFING"
}
