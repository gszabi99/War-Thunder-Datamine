local transition = require("style/hudTransition.nut")
local chat = require("hudChat.nut")
local battleLog = require("hudBattleLog.nut")
local tabs = require("components/tabs.nut")
local hudState = require("hudState.nut")
local hudChatState = require("hudChatState.nut")
local { isMultiplayer } = require("networkState.nut")
local { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")


local tabsList = [
  { id = "Chat", text = ::loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = ::loc("options/_Bttl"), content = battleLog }
]


local currentTab = Watched(null)

currentTab.subscribe(function (new_val) {
  hudChatState.inputChatVisible(new_val.id == "Chat")
})
currentTab.update(tabsList[0])

local selectChatTab = function (enable) {
  if (enable) {
    currentTab.update(tabsList[0])
  }
}

local logsHeader = @(){
  size = [flex(), SIZE_TO_CONTENT]
  watch = [
    currentTab
    hudState.cursorVisible
  ]
  opacity = hudState.cursorVisible.value ? 1.0 : 0.0
  children = [
    tabs({
      tabs = tabsList
      currentTab = currentTab.value.id
      onChange = function(tab) {
        currentTab.update(tab)
      }
    })
  ]

  onAttach = function (elem) {
    hudChatState.inputEnabled.subscribe(selectChatTab)
  }
  onDetach = function (elem) {
    hudChatState.inputEnabled.unsubscribe(selectChatTab)
  }
  transitions = [transition()]
}

local isChatVisible = ::Computed(@() isChatPlaceVisible.value && isMultiplayer.value)

return @() {
  size = [min(sw(30), sh(53)), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = [ currentTab, isChatVisible]
  children = isChatVisible.value
    ? [
        logsHeader
        currentTab.value.content
      ]
    : []
}
