local enums = ::require("sqStdlibs/helpers/enums.nut")
local { buttonsList } = require("scripts/mainmenu/topMenuButtons.nut")

// Priority for separation on buttons.
enum topMenuLeftSideMergeIndex {
  MENU
  PVP
  COMMUNITY
}

::g_top_menu_left_side_sections <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

/*
Columns are each array in buttons array.
Params - can be whole section ('help', 'pve') or single button.
*/
enums.addTypesByGlobalName("g_top_menu_left_side_sections", [
  {
    name = "menu"
    btnName = "start"
    getText =  @(totalSections = 0) (totalSections == 1 || ::show_console_buttons) ? "#topmenu/menu" : null
    mergeIndex = topMenuLeftSideMergeIndex.MENU
    getImage = @(totalSections = 0) (totalSections == 1 || ::show_console_buttons) ? null : "#ui/gameuiskin#menu.svg"
    buttons = [
      [
        "pvp"
      ],
      [
        buttonsList.OPTIONS
        buttonsList.CONTROLS
        "community"
        buttonsList.EXIT
        buttonsList.DEBUG_UNLOCK
      ]
    ]
  },
  {
    name = "pvp"
    getText = function(totalSections = 0) { return "#topmenu/battle" }
    mergeIndex = topMenuLeftSideMergeIndex.PVP
    buttons = [
      [
        buttonsList.SKIRMISH
        buttonsList.WORLDWAR
        buttonsList.LINE_SEPARATOR
        buttonsList.USER_MISSION
        buttonsList.TUTORIAL
        buttonsList.SINGLE_MISSION
        buttonsList.DYNAMIC
        buttonsList.CAMPAIGN
        buttonsList.PERSONAL_UNLOCKS
        buttonsList.BENCHMARK
      ]
    ]
  },
  {
    name = "community"
    getText = function(totalSections = 0) { return "#topmenu/community" }
    mergeIndex = topMenuLeftSideMergeIndex.COMMUNITY
    buttons = [
      [
        buttonsList.LEADERBOARDS
        buttonsList.CLANS
        buttonsList.REPLAY
        buttonsList.VIRAL_AQUISITION
        buttonsList.TSS
        buttonsList.STREAMS_AND_REPLAYS
      ]
    ]
  }
])

::g_top_menu_right_side_sections <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

enums.addTypesByGlobalName("g_top_menu_right_side_sections", [
  {
    name = "shop"
    visualStyle = "noFrameGold"
    hoverMenuPos = "pw-w-"
    getText = function(totalSections = 0) { return ::is_low_width_screen()? null : "#mainmenu/btnOnlineShop" }
    getImage = function(totalSections = 0) { return "#ui/gameuiskin#store_icon.svg" }
    getWinkImage = function () { return "#ui/gameuiskin#hovermenu_shop_button_glow" }
    haveTmDiscount = true
    isWide = true
    forceHoverWidth = "1@mainMenuButtonWideWidth + 0.02@sf"
    buttons = [
      [
        buttonsList.EAGLES
        buttonsList.LINE_SEPARATOR
        buttonsList.PREMIUM
        buttonsList.WARPOINTS
        buttonsList.INVENTORY
        buttonsList.ITEMS_SHOP
        buttonsList.WORKSHOP
        buttonsList.WARBONDS_SHOP
        buttonsList.ONLINE_SHOP
        buttonsList.XBOX_ONLINE_SHOP
        buttonsList.PS4_ONLINE_SHOP
        buttonsList.DEBUG_PS4_SHOP_DATA
        buttonsList.MARKETPLACE
      ]
    ]
  },
  {
    name = "help"
    hoverMenuPos = "pw-w-"
    getImage = function(totalSections = 0) { return "#ui/gameuiskin#btn_help.svg" }
    buttons = [
      [
        buttonsList.WINDOW_HELP
        buttonsList.ENCYCLOPEDIA
        buttonsList.CHANGE_LOG
        buttonsList.CREDITS
        buttonsList.EULA
        buttonsList.LINE_SEPARATOR
        buttonsList.WIKI
        buttonsList.FAQ
        buttonsList.SUPPORT
      ]
    ]
  }
])