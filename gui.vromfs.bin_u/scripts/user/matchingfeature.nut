from "%scripts/dagui_library.nut" import *



let matchingGameSettings = require("%scripts/matching/matchingGameSettings.nut")
let { register_command } = require("console")

let defaults = {  
             
  hasChat = false
  hasBattleChatModeAll = false
  hasBattleChatModeTeam = false
  hasBattleChatModeSquad = true
  hasMenuGeneralChats = true
  hasMenuChatPrivate = true
  hasMenuChatSquad = true
  hasMenuChatClan = true
  hasMenuChatSystem = true
  hasMenuChatMPlobby = true
  hasMenuWWOperationChats = true
}

let toggleFeatures = Watched({
})

defaults.each(@(_, key)
  register_command(function() {
    toggleFeatures.mutate(@(v) v[key] <- !(v?[key] ?? false))
    log($"toggleMatchingFeature {key}: {toggleFeatures.get()[key]}")
  }, $"debug.toggleMatchingFeature.{key}"))

return defaults.map(@(v, k) Computed(
  @() (toggleFeatures.get()?[k] ?? false) == !(matchingGameSettings.get()?.features[k] ?? v)
))
