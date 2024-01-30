rootUnderPopupMenu {
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
}

popup_menu {
  id:t='frame_obj'
  width:t='@sliderWidth + 2@buttonHeight + 4@blockInterval'
  min-width:t='<<columns>>*(@itemWidth + @itemSpacing) + @itemSpacing + 2@framePadding'
  position:t='root'
  pos:t='<<position>>'
  menu_align:t='<<align>>'
  total-input-transparent:t='yes'
  flow:t='vertical'
  hasNavBar:t='yes'

  Button_close { _on_click:t='goBack'; smallIcon:t='yes' }

  textAreaCentered {
    id:t='header_text'
    width:t='pw'
    overlayTextColor:t='active'
    text:t='<<header>>'
  }

  div {
    id:t='items_list'
    width:t='<<columns>>*(@itemWidth + @itemSpacing) + @itemSpacing'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    itemShopList:t='yes'
    clearOnFocusLost:t='no'
    flow:t='h-flow'
    behavior:t='posNavigator'
    navigatorShortcuts:t='yes'
    moveX:t='linear'
    moveY:t='closest'
    value:t='0'
    move-only-hover:t='yes'
    on_select:t = 'onItemSelect'

    <<@items>>
  }

  navBar{
    class:t='relative'
    type:t='spareWnd'

    navRight{
      tdiv {
        flow:t='vertical'
        position:t='relative'
        padding-bottom:t='@blockInterval'

        CheckBox {
          id:t='noConfirmActivation'
          position:t='relative'
          padding-right:t='40@sf/@pf'
          margin-bottom:t='@blockInterval'
          right:t='@blockInterval'
          type:t='rightSideCb'
          inactiveColor:t='no'
          text:t='#skipInBattleSpareActivateConfirm'
          on_change_value:t='onNoConfirmActivationChange'
          CheckBoxImg{}
        }

        Button_text {
          id:t='buttonActivate'
          position:t='relative'
          right:t='@blockInterval'
          text:t='#msgbox/btn_use'
          on_click:t='onActivate'
          btnName:t='X'
          ButtonImg{}
        }
      }
    }
  }

  <<#hasPopupMenuArrow>>
  popup_menu_arrow{}
  <</hasPopupMenuArrow>>
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}