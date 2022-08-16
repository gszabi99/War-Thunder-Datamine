root {
  blur {}
  blur_foreground {}
  type:t='big'

  frame {
    width:t='<<slotCountX>>(@slot_width+2@slotPaddingNoTable)+2@blockInterval<<#hasScrollBar>>+@scrollBarSize<</hasScrollBar>>+2@framePadding'
    max-height:t='1@maxWindowHeightNoSrh'
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
      top_right_holder {
        hasRightIndent:t='yes'
        CheckBox {
          id:t='skip_info'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          text:t='#options/doNotAskMeAgain'
          on_change_value:t='onSkipInfo'
          btnName:t='Y'
          CheckBoxImg{}
          ButtonImg{}
        }
      }
      <<#needCloseBtn>>
      Button_close {}
      <</needCloseBtn>>
    }

    textAreaCentered {
      width:t='pw'
      position:t='relative'
      padding-bottom:t='1@blockInterval'
      text:t='<<flushExpText>>'
      overlayTextColor:t='active'
    }

    img {
      size:t='pw, 400.0/800pw'
      background-image:t='#ui/images/reward10.jpg?P1'
      background-position:t="0, 40, 0, 260"
      background-repeat:t='part'
      background-color:t='@white'

      rankUpList {
        id:t='flush_exp_unit_nest'
        pos:t='0.5pw - 0.5w, 0'
        position:t='absolute'
        holdTooltipChildren:t='yes'
        on_activate:t='onUnitActivate'
        on_click:t='onUnitActivate'
        on_r_click:t='onUnitActivate'
        <<@flushExpUnit>>
      }
    }

    frameBlock {
      id:t = 'units_list'
      width:t='pw'
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
      on_select:t='onUnitSelect'
      on_click:t='onUnitClick'
      on_r_click:t='onUnitRightClick'
      on_activate:t='onUnitAction'

      on_pushed:t='::gcb.delayedTooltipListPush'
      on_hold_start:t='::gcb.delayedTooltipListHoldStart'
      on_hold_stop:t='::gcb.delayedTooltipListHoldStop'

      <<@unitsList>>
    }

    <<#navBar>>
    navBar {
      include "%gui/commonParts/navBar"
    }
    <</navBar>>
  }
}
