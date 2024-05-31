root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    <<#wndHeight>>
    size:t='1200*@sf/@pf, <<wndHeight>>'
    <</wndHeight>>
    <<^wndHeight>>
    size:t='1200*@sf/@pf, 1@maxWindowHeight'
    <</wndHeight>>
    max-height:t='@rh'
    class:t='wnd'

    frame_header {
      activeText {
        text:t='<<titleText>>'
        caption:t='yes'
      }
      Button_close {}
    }

    tdiv{
      id:t = 'contentBody'
      width:t='pw'
      padding:t='1@framePadding, 0'
      <<@optionsContainer>>
    }

    textareaNoTab {
      margin-top:t='1@framePadding'
      padding:t='1@framePadding, 0'
      width:t='pw'
      text:t='<<descText>>'
    }

    <<#hasUnlocksList>>
    listbox {
      id:t='unlocks_list'
      flow:t = 'vertical'
      size:t = 'pw, fh'
      overflow:t='auto'

      itemInterval:t='@unlocksListboxItemInterval'
      navigatorShortcuts:t='yes'
      scrollbarShortcuts:t='yes'
      on_dbl_click:t='unlockToFavoritesByActivateItem'
    }
    <</hasUnlocksList>>
  }
}
