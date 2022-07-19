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
  margin-top:t='1@buttonMargin'
  margin-bottom:t='1@buttonMargin'
}

slotsScrollDiv {
  size:t='pw-2@scrollArrowsSize, 1@eSItemHeight+2@eSItemMargin'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h+1@eSItemButtonHeight'
  position:t='absolute'
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