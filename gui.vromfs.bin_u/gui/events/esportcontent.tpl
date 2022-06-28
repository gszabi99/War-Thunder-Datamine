textareaNoTab {
  left:t='0.5pw-0.5w'
  position:t='relative'
  text:t='<<seasonDate>>'
}

HorizontalListBox {
  id:t='tabs_list'
  height:t='1@frameHeaderHeight'
  left:t='1@scrollArrowsSize'
  position:t='absolute'
  activeAccesskeys:t='RS'
  class:t='header'
  bigBoldFont:t='yes'
  on_select:t = 'onTabChange'

  include "%gui/frameHeaderTabs"
}

popupFilter {
  padding:t='0, 1@eSItemButtonHeight'
  margin-top:t='1@buttonMargin'
  margin-bottom:t='1@buttonMargin'
}

slotsScrollDiv {
  size:t='pw-2@scrollArrowsSize, 1@eSItemHeight+2@eSItemMargin'
  pos:t='0.5pw-0.5w, 0.5ph-0.5h'
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