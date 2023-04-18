rootUnderPopupMenu {
  blur {}
  blur_foreground {}
  on_click:t='goBack'
  on_r_click:t='goBack'
}

frame {
  class:t='wndNav'
  max-height:t='@maxWindowHeight'
  min-width:t='0.8@sf'
  min-height:t='0.3@sf'
  isCenteredUnderLogo:t='yes'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  flow:t='vertical'

  frame_header{
    activeText{
      text:t='#title/empty_title'
      caption:t='yes'
    }
    Button_close{}
  }

  <<#hasTitles>>
  div {
    id:t='titles_list'
    width:t='<<titleColumns>> * <<titleWidth>> + (<<titleColumns>> + 1) * @buttonMargin + 1@scrollBarSize'
    flow:t='h-flow'
    flow-align:t='left'
    max-height:t= '1@rh - 2@frameHeaderHeight'
    overflow-y:t="auto"

    behavior:t='posNavigator'
    navigatorShortcuts:t='yes'
    total-input-transparent:t='yes'
    showSelect:t='yes'
    on_select:t='onTitleSelect'
    on_activate:t='onTitleActivate'
    on_click:t='onTitleClick'
    value:t='<<value>>'

    <<#titles>>
    titleItem {
      id:t='<<name>>'
      width:t='<<titleWidth>>'
      text:t='<<text>>'
      <<#isCurrent>>isCurrent:t='yes'<</isCurrent>>
      <<#isLocked>>isLocked:t='yes'<</isLocked>>

      <<#unseenIcon>>
      hasUnseenIcon:t='yes'
      unseenIcon {
        pos:t='0, 50%ph-50%h'
        position:t='absolute'
        value:t='<<unseenIcon>>'
      }
      <</unseenIcon>>

      <<#tooltipId>>
      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<tooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }
      <</tooltipId>>
    }
    <</titles>>
  }
  <</hasTitles>>

  <<^hasTitles>>
  textAreaCentered {
    position:t='absolute'
    pos:t='50%(pw-w), 50%(ph-h)'
    width:t='2@buttonWidth + 3@buttonMargin'
    text:t='#title/no_titles'
  }
  <</hasTitles>>

  navBar {
    navLeft {
      <<#hasTitles>>
      Button_text {
        text:t='#title/clear_title'
        on_click:t='onTitleClear'
        btnName:t='Y'
        ButtonImg {}
      }
      <</hasTitles>>
    }

    navRight {
      Button_text {
        id:t='btn_fav'
        text:t='#preloaderSettings/trackProgress'
        btnName:t='A'
        on_click:t='onToggleFav'
        ButtonImg {}
      }
      Button_text {
        id:t='btn_apply'
        text:t='#mainmenu/btnApply'
        on_click:t='onApply'
        btnName:t='A'
        ButtonImg {}
      }
    }
  }
}