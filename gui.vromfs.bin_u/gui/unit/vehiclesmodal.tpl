root {
  blur {}
  blur_foreground {}
  type:t="big"

  frame {
    isCenteredUnderLogo:t='yes'
    <<#navBar>>
    class:t='wndNav'
    <</navBar>>
    <<^navBar>>
    class:t='wnd'
    <</navBar>>

    frame_header {
      textareaNoTab {
        id:t='header_text'
        caption:t='yes'
        text:t='<<wndTitle>>'
      }
      <<#needCloseBtn>>
      Button_close {}
      <</needCloseBtn>>
    }

    tdiv {
      position:t='relative'
      width:t='pw'
      popupFilter {
        margin-bottom:t="1@buttonMargin"
      }
      <<#hasSearchBox>>
      tdiv {
        position:t='absolute'
        flow:t='horizontal'
        left:t='p.p.w - w - 15@sf/@pf'

        EditBox {
          id:t = 'search_edit_box'
          width:t='400@sf/@pf'
          noMargin:t='yes'
          edit-hint:t='#contacts/search_placeholder'
          max-len:t='60'
          text:t=''
          on_change_value:t='onSearchEditBoxChangeValue'
          on_cancel_edit:t='onSearchEditBoxCancelEdit'
        }

        Button_text {
          id:t='search_btn_close'
          position:t='relative'
          class:t='image'
          showConsoleImage:t='no'
          noMargin:t='yes'
          tooltip:t='#options/clearIt'
          hotkeyLoc:t='key/Esc'
          on_click:t='onSearchCancelClick'
          img {
            background-image:t='#ui/gameuiskin#btn_close.svg'
          }
        }
      }
      <</hasSearchBox>>
    }

    frameBlock {
      id:t = 'units_list'
      width:t='<<slotCountX>>(@slot_width+2@slotPaddingNoTable)+2@blockInterval<<#hasScrollBar>>+@scrollBarSize<</hasScrollBar>>'
      height:t='<<slotCountY>>(@slot_height+2@slotPaddingNoTable)+2@blockInterval+2@dp'
      padding:t='@blockInterval'
      position:t='relative'
      overflow-y:t='auto'
      flow:t='h-flow'
      behaviour:t='posNavigator'
      total-input-transparent:t='yes'
      alwaysShowBorder:t='yes'
      navigatorShortcuts:t='SpaceA'
      showButtonsForSelectedChild:t='yes'
      <<^isOnlyClick>>
        on_select:t='onUnitSelect'
        on_r_click:t='onUnitRightClick'
      <</isOnlyClick>>
      on_click:t='onUnitClick'
      on_activate:t='onUnitAction'

      on_pushed:t='::gcb.delayedTooltipListPush'
      on_hold_start:t='::gcb.delayedTooltipListHoldStart'
      on_hold_stop:t='::gcb.delayedTooltipListHoldStop'

      <<@unitsList>>
    }

    <<#navBar>>
    navBar {
      include "%gui/commonParts/navBar.tpl"
    }
    <</navBar>>
  }
}
