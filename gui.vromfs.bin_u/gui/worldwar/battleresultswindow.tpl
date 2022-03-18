frame {
  size:t='1.4@sf, 1@maxWindowHeight'
  max-width:t='1@rw'
  class:t='wnd'
  isCenteredUnderLogo:t='yes'

  frame_header {
    activeText {
      id:t='wnd_title'
      text:t='<<getBattleTitle>>'
      caption:t='yes'
    }

    Button_close {}
  }

  tdiv {
    size:t='pw, fh - 1@navBarBattleButtonHeight'

    include "%gui/worldWar/battleResults"
  }

  navBar{
    navLeft{
      <<#hasReplay>>
      Button_text {
        text:t = '#mainmenu/btnViewServerReplay'
        btnName:t='Y'
        tooltip:t='<<getReplayBtnTooltip>>'
        _on_click:t='onViewServerReplay'
        ButtonImg {}
      }
      <</hasReplay>>
      activeText {
        style:t='color:@fadedTextColor'
        height:t='1@buttonHeight'
        margin:t='1@buttonMargin'
        text:t='<<getBattleDescText>>'
      }
    }
    navRight{
      Button_text {
        text:t = '#mainmenu/btnClose'
        btnName:t='B'
        _on_click:t='goBack'
        ButtonImg {}
      }
    }
  }
}
