from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

let menuChatHandler = Watched(null)

let lastChatSceneShow = Watched(null)
eventbus_subscribe("on_sign_out", @(_p) lastChatSceneShow.set(false))

let chatActiveSceneParam = Watched(null) 
let openChatHandlerScene = @(scene, obj = null, onlyShow = null) chatActiveSceneParam.set({ scene, obj, onlyShow, show = true })
let hideChatHandlerScene = @() chatActiveSceneParam.mutate(@(v) v.__update({ show = false, onlyShow = null }))

let chatPrevScenes = [] 
let addChatScene = @(sceneData) chatPrevScenes.append(sceneData) 
let clearChatScenes = @() chatPrevScenes.clear()

return {
  menuChatHandler

  lastChatSceneShow
  chatActiveSceneParam
  openChatHandlerScene
  hideChatHandlerScene

  chatPrevScenes
  addChatScene
  clearChatScenes
}