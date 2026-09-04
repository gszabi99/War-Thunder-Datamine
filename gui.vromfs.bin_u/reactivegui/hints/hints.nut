import "%rGui/hints/hintTags.nut" as hintTags
from "eventbus" import eventbus_subscribe, eventbus_send
from "%rGui/globals/ui_library.nut" import *




let hintsCache = {} 
let pendingRequests = {} 

eventbus_subscribe("hints.configResponse", function(msg) {
  pendingRequests.rawdelete(msg.key)
  let cfg = hintsCache?[msg.key]
  if (cfg != null)
    cfg.set({ rows = msg.rows })
})



eventbus_subscribe("hints.providerReady", function(_) {
  foreach (req in pendingRequests)
    eventbus_send("hints.requestConfig", req)
})

local function mkHintComponent(cfgWatched, override, addChildren) {
  let onAttach = override?.onAttach
  return function() {
    let rows = cfgWatched.get()?.rows ?? []
    let children = rows.map(@(hint) hintTags(hint.slices, override, addChildren))
      .filter(@(hint) hint != null)
    
    
    if (children.len() == 0)
      return { watch = cfgWatched, children = override?.fallback }
    return {
      watch = cfgWatched
      children = {
        flow = FLOW_VERTICAL
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children
        onAttach
      }
    }
  }
}

function getHintContent(hintString, override = {}, addChildren = []) {
  
  
  
  let skipDeviceIds = (override?.skipDeviceIds ?? {}).keys().sort()
  
  
  let cacheString = skipDeviceIds.reduce(@(res, id) $"{res};{id}", $"{hintString.len()}:{hintString}")
  if (cacheString not in hintsCache) {
    hintsCache[cacheString] <- Watched(null)
    
    let request = { key = cacheString, text = hintString, skipDeviceIds }
    pendingRequests[cacheString] <- request
    eventbus_send("hints.requestConfig", request)
  }
  return mkHintComponent(hintsCache[cacheString], override, addChildren)
}

eventbus_subscribe("controlsChanged", function(_) {
  hintsCache.clear()
  pendingRequests.clear()
})

return getHintContent
