root {
  blur {}
  blur_foreground {}
  type:t="big"

  frame {
    width:t='<<slotCountX>>(@slot_width+2@slotPaddingNoTable)+2@framePadding + 2@blockInterval<<#hasScrollBar>>+@scrollBarSize<</hasScrollBar>>'
    pos:t='0.5pw-0.5w, 1@titleLogoPlateHeight + 0.3(sh - 1@titleLogoPlateHeight - h)'
    position:t='absolute'

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

    frameBlock {
      id:t = 'units_list'
      size:t= 'pw, <<slotCountY>>(@slot_height+2@slotPaddingNoTable)+2@blockInterval+2@dp'
      padding:t='@blockInterval'
      position:t='relative'
      top:t='1@popupFilterHeight'
      overflow-y:t='auto'
      flow:t='h-flow'
      shortcut-on-hover:t='yes'
      behaviour:t='posNavigator'
      total-input-transparent:t='yes'
      clearOnFocusLost:t='no'
      alwaysShowBorder:t='yes'
      navigatorShortcuts:t='yes'
      showButtonsForSelectedChild:t='yes'
      on_select:t='onUnitSelect'
      on_click:t='onUnitClick'
      on_r_click:t='onUnitRightClick'
      on_activate:t='onUnitAction'
      <<@unitsList>>
    }

    popupFilter { top:t='1@frameHeaderHeight' }

    <<#navBar>>
    navBar {
      include "gui/commonParts/navBar"
    }
    <</navBar>>
  }
}
