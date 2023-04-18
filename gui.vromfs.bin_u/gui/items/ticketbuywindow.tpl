root {
  blur {}
  blur_foreground {}

  frame {
    id:t='window_root'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    width:t='80%sh'

    <<#hasActiveTicket>>
    height:t='70%sh'
    <</hasActiveTicket>>
    <<^hasActiveTicket>>
    height:t='60%sh'
    <</hasActiveTicket>>
    max-width:t='800*@sf/@pf_outdated + 2@framePadding'
    max-height:t='@rh'
    class:t='wndNav'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }
      Button_close {}
    }

    textareaNoTab {
      text:t='<<activeTicketText>>'
      width:t='pw - 30@sf/@pf_outdated'
      margin-top:t='50@sf/@pf_outdated'
      margin-left:t='30@sf/@pf_outdated'
      position:t='absolute'
    }

    textAreaCentered {
      text:t='<<windowMainText>>'
      width:t='pw'
      <<#hasActiveTicket>>
      margin-top:t='120@sf/@pf_outdated'
      <</hasActiveTicket>>
      <<^hasActiveTicket>>
      margin-top:t='70@sf/@pf_outdated'
      <</hasActiveTicket>>
      position:t='absolute'
    }

    frameBlock {
      id:t='items_list'
      flow:t='h-flow'
      total-input-transparent:t='yes'
      behavior:t='posNavigator'
      navigatorShortcuts:t='yes'
      moveX:t='closest'
      moveY:t='linear'
      clearOnFocusLost:t='no'
      on_select:t = 'onTicketSelected'
      _on_dbl_click:t = 'onTicketDoubleClicked'
      position:t='relative'
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      itemShopList:t='yes'
      ticketsWindow:t='yes'

      <<@tickets>>
    }

    tdiv {
      <<#ticketCaptions>>
      textareaNoTab {
        id:t='<<captionId>>'
        margin-top:t='10@sf/@pf_outdated'
        text:t='<<captionText>>'
        position:t='absolute'
        max-width:t='2@itemSpacing + 1.4@itemWidth'
        text-align:t='center'
      }
      <</ticketCaptions>>
    }

    navBar {
      navMiddle {
        Button_text {
          id:t = 'btn_apply'
          class:t='battle'
          navButtonFont:t='yes'
          text:t = '#mainmenu/btnApply'
          _on_click:t = 'onBuyClicked'
          css-hier-invalidate:t='yes'
          btnName:t='A'

          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          ButtonImg{}
          textarea {
            id:t='btn_apply_text'
            input-transparent:t='yes'
            removeParagraphIndent:t='yes'
          }
        }
      }
    }
  }
}
