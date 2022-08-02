textareaNoTab {
  id:t='header_txt'
  left:t='0.5pw-0.5w'
  position:t='relative'
  bigBoldFont:t='yes'
  text-align:t='center'
  text:t='<<seasonHeader>>'
}

textareaNoTab {
  left:t='0.5pw-0.5w'
  position:t='relative'
  text:t='<<seasonDate>>'
}

popupFilter {
  top:t='1@eSItemMargin'
  position:t='relative'
}

slotsScrollDiv {
  height:t='1@eSItemHeight+2@eSItemMargin'
  top:t='2@eSItemMargin'
  position:t='relative'
  class:t='tournamentDiv'
  overflow-x:t='auto'

  slotbarTable {
    id:t='events_list'
    behavior:t='ActivateSelect'
    position:t='relative'
    navigatorShortcuts:t='yes'
    activateChoosenItemByShortcut:t='yes'

    include "%gui/events/eSportItem"
  }
}