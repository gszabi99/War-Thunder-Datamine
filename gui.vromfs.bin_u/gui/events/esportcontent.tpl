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

tdiv {
  position:t='relative'
  flow:t='horizontal'
  padding:t='0, 1@eSItemButtonHeight'

  Button_text {
    position:t='relative'
    visualStyle:t='tournament'
    text:t='#tournaments/my'
    on_click:t = 'onMyTournaments'
    class:t='image'
    enable:t='no'
    btnName:t='R3'
    img {
      background-image:t='#ui/gameuiskin#tournament_my.svg'
    }
    ButtonImg {}
  }

  popupFilter {
    margin-top:t="1@buttonMargin"
    margin-bottom:t="1@buttonMargin"
  }
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