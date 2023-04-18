frame {
  id:t='trophy_group_shop_frame'
  width:t='<<width>> + 1@trophiesGroupItemsInfoBlockWidth';
  height:t='<<height>> + 1@frameTopPadding + 1@frameFooterHeight + 1@itemSpacing'
  min-height:t='3@itemHeight + 1@frameTopPadding + 1@frameFooterHeight'
  class:t='wndNav'
  style:t='flow:horizontal;'
  isCenteredUnderLogo:t='yes'

  frame_header {
    activeText{ id:t='group_trophy_header'; caption:t='yes' }
    Button_close { id:t = 'btn_back' }
  }

  tdiv {
    id:t='items_list'
    width:t='<<width>> + 1@itemSpacing + 6'
    height:t='<<height>> + 1@itemSpacing + 4'
    min-height:t='3@itemHeight'
    overflow-y:t='auto'

    flow:t='h-flow'
    flow-align:t='center'

    total-input-transparent:t='yes'

    behavior:t='posNavigator'
    navigatorShortcuts:t='noSelect'
    moveX:t='closest'
    moveY:t='closest'
    clearOnFocusLost:t='yes'

    on_select:t='updateButtons'
    _on_hover:t='onItemsListFocusChange'
    _on_unhover:t='onItemsListFocusChange'

    itemShopList:t='yes'
    smallItems:t='<<smallItems>>'
    <<@trophyItems>>
  }

  chapterSeparator {}

  tdiv {
    id:t='item_info'
    width:t='fw';
    height:t='<<height>> + 1@itemSpacing'
    min-height:t='3@itemHeight'
    pos:t='1@blockInterval, 0'
    position:t='relative'
    overflow-y:t='auto'
    scrollbarShortcuts:t='yes'

    div {
      id:t='item_info_desc_place'
      width:t='pw'
      padding:t='0.01@scrn_tgt'
      flow:t='vertical'
    }
  }

  navBar {
    navRight {
      id:t='item_actions_bar'

      textarea {
        id:t='warning_text'
        position:t='relative'
        text:t='#msgbox/item_bought'
        padding-right:t='10@sf/@pf_outdated'
        overlayTextColor:t='warning'
      }
      Button_text {
        id:t = 'btn_main_action'
        btnName:t='A'
        _on_click:t = 'onSelectedItemAction'
        hideText:t='yes'
        css-hier-invalidate:t='yes'
        skip-navigation:t='yes'
        showButtonImageOnConsole:t='no'
        display:t='hide'
        visualStyle:t='purchase'
        buttonWink{}
        buttonGlance{}
        ButtonImg {}
        textarea {
          id:t='btn_main_action_text'
          class:t='buttonText'
        }
      }
    }
  }
}
