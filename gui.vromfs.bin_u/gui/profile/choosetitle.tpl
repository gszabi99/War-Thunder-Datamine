rootUnderPopupMenu {
  blur {}
  blur_foreground {}
  on_click:t='goBack'
  on_r_click:t='goBack'
}

frame {
  id:t='main_frame'
  position:t='root'
  class:t='wndNav'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  flow:t='vertical'
  menu_align:t='bottom'

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
    navigatorShortcuts:t='active'
    showSelect:t='yes'
    on_select:t='onTitleSelect'
    on_activate:t='onActivateTitleList'
    value:t='<<value>>'

    <<#titles>>
    Button_text {
      id:t='<<name>>'
      width:t='<<titleWidth>>'
      visualStyle:t='noFrame'
      talign:t='left'
      text:t='<<text>>'
      on_click:t='onChooseTitle'
      <<#isSelected>>style:t='color:@userlogColoredText;'<</isSelected>>

      <<#unseenIcon>>
      unseenIcon {
        pos:t='pw -w - 1@buttonTextPadding, 50%ph-50%h'
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
    width:t='2@buttonWidth + 3@buttonMargin'
    text:t='#title/no_titles'
  }
  <</hasTitles>>

  navBar {
    navLeft {
      <<#hasTitlesListButton>>
      Button_text {
        text:t='#title/all_titles'
        on_click:t='onFullTitlesList'
        btnName:t='X'
        ButtonImg {}
      }
      <</hasTitlesListButton>>

      <<#hasTitles>>
      Button_text {
        id:t='' //empty title
        text:t='#title/clear_title'
        on_click:t='onChooseTitle'
        btnName:t='Y'
        ButtonImg {}
      }
      <</hasTitles>>
    }

    navRight {
      <<#hasApplyButton>>
      Button_text {
        text:t='#mainmenu/btnApply'
        on_click:t='onApply'
        btnName:t='A'
        ButtonImg {}
      }
      <</hasApplyButton>>
    }
  }

  popup_menu_arrow {}
}