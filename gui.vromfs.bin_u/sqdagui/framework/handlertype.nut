from "%sqDagui/daguiNativeApi.nut" import *

enum handlerType {
  ROOT    //root handler dosn't destroy on switch between base handlers. Share object where to create base handlers
  BASE    //main handler ingame. can be active only one at time.
  MODAL   //opened in modal window, auto destroys on switch base handler
  CUSTOM  //handler created in custom object. usualy has parent handler, because it not full scene handler.

  ANY
}

return { handlerType }