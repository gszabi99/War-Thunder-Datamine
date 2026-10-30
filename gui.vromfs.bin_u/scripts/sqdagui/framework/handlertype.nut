from "%scripts/sqDagui/daguiNativeApi.nut" import *

enum handlerType {
  ROOT    
  BASE    
  MODAL   
  CUSTOM  

  ANY
}

return freeze({ handlerType })