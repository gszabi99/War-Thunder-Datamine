frame {
  id:t='trophy_group_shop_frame'
  width:t='<<width>> + 1@trophiesGroupItemsInfoBlockWidth';
  height:t='<<height>> + 1@frameTopPadding + 1@frameFooterHeight + 1@itemSpacing'
  min-height:t='3@itemHeight + 1@frameTopPadding + 1@frameFooterHeight'
  pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)';
  position:t='absolute'
  class:t='wndNav'
  style:t='flow:horizontal;'

  frame_header {
    activeText{ id:t='group_trophy_header'; caption:t='yes' }
    Button_close { id:t = 'btn_back' }
  }

  frameBlock {
    id:t='items_list'
    width:t='<<width>> + 1@itemSpacing + 6'
    height:t='<<height>> + 1@itemSpacing + 4'
    min-height:t='3@itemHeight'
    overflow-y:t='auto'

    flow:t='h-flow'
    flow-align:t='center'

    behavior:t='posNavigator'
    navigatorShortcuts:t='yes'
    moveX:t='closest'
    moveY:t='closest'
    clearOnFocusLost:t='no'

    on_select:t='updateButtons'

    itemShopList:t='yes'
    smallItems:t='<<smallItems>>'
    <<@trophyItems>>
  }

  frameBlock {
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
