// Same template for active and finished orders.

timer {
  id:t='order_timer'
  timer_handler_func:t='onOrderTimerUpdate'
  timer_interval_msec:t='1000'
}

// Used in spectator mode.
<<#needPlaceInHiddenContainer>>
tdiv {
  id:t='orders_container'
  size:t='pw, ph'
  min-width:t='0.5@itemInfoWidth'
  min-height:t='0.5@itemInfoWidth'
  flow:t='vertical'
  overflow-y:t='auto'
  position:t='absolute'
  <<^isHiddenContainerVisible>>
  display:t='hide'
  <</isHiddenContainerVisible>>
<</needPlaceInHiddenContainer>>

<<^needPlaceInHiddenContainer>>
<<^isHalignRight>>
tdiv {
  id:t='hide_order_block'
  margin:t='0, 1@blockInterval'
  background-color:t='@listboxBgColor'
  collapsed:t='no'

  baseToggleButton {
    id:t='hide_order_btn'
    on_click:t='onChangeOrderVisibility'
    alwaysShow:t='yes'
    isHidden:t='yes'
    directionImg {}
  }

  textareaNoTab {
    id:t='hide_order_text'
    top:t='(ph-h)/2'
    position:t='relative'
    padding:t='0.01@scrn_tgt, 0'
    text:t='#order/colored_icon'
    display:t='hide'
    caption:t='yes'
  }
}
<</isHalignRight>>
<</needPlaceInHiddenContainer>>

tdiv {
  id:t='orders_block'
  <<^isHalignRight>>
  width:t='pw - 10/720*@scrn_tgt'
  <</isHalignRight>>
  <<#isHalignRight>>
  width:t='pw - 1@airInfoToggleButtonSize'
  <</isHalignRight>>
  flow:t='vertical'

  textareaNoTab {
    id:t='status_text'
    width:t='pw'
    color:t='@red'
    text:t=''
    overlayTextColor:t='bad'
    total-input-transparent:t='yes'
    input-transparent:t='yes'
    <<^isHalignRight>>
    padding-left:t='10/720*@scrn_tgt'
    <</isHalignRight>>
    padding-top:t='10/720*@scrn_tgt'
    smallFont:t='yes'
    <<#isHalignRight>>
    text-align:t='right'
    padding-right:t='10/720*@scrn_tgt'
    <</isHalignRight>>
    order-status-text-shade:t='yes'
  }

  table {
    id:t='status_table'
    margin-top:t='0.005*@scrn_tgt'
    <<^isHalignRight>>
    margin-right:t='0.01*@scrn_tgt'
    <</isHalignRight>>
    width:t='pw'
    total-input-transparent:t='yes'
    input-transparent:t='yes'
    class:t='normalFont'

    <<#rows>>
    tr {
      height:t='0.6@baseTrHeight'
      id:t='order_score_row_<<rowIndex>>'
      td {
        img {
          id:t='order_score_pilot_icon'
          top:t='0.5ph - 0.7h'
          position:t='relative'
          size:t='16*@scrn_tgt/720, 16*@scrn_tgt/720'
          background-image:t='#ui/gameuiskin#player_in_queue'
          display:t='hide'
        }
        textarea {
          id:t='order_score_player_name_text'
          removeParagraphIndent:t='yes'
          halign:t='left'
          text:t=''
          smallFont:t='yes'
          order-status-text-shade:t='yes'
        }
      }
      td {
        textarea {
          id:t='order_score_value_text'
          removeParagraphIndent:t='yes'
          halign:t='center'
          text:t=''
          smallFont:t='yes'
          order-status-text-shade:t='yes'
        }
      }
    }
    <</rows>>
  }

  textareaNoTab {
    id:t='status_text_bottom'
    width:t='pw'
    color:t='@red'
    text:t=''
    overlayTextColor:t='bad'
    total-input-transparent:t='yes'
    input-transparent:t='yes'
    smallFont:t='yes'
    <<#isHalignRight>>
    text-align:t='right'
    <</isHalignRight>>
    order-status-text-shade:t='yes'
  }
}

<<^needPlaceInHiddenContainer>>
<<#isHalignRight>>
tdiv {
  id:t='hide_order_block'
  margin:t='0, 1@blockInterval'
  background-color:t='@listboxBgColor'
  collapsed:t='no'
  position:t=''
  left:t='pw-w'

  textareaNoTab {
    id:t='hide_order_text'
    top:t='(ph-h)/2'
    position:t='relative'
    padding:t='0.01@scrn_tgt, 0'
    text:t='#order/colored_icon'
    display:t='hide'
    caption:t='yes'
  }

  baseToggleButton {
    id:t='hide_order_btn'
    on_click:t='onChangeOrderVisibility'
    alwaysShow:t='yes'
    isHidden:t='yes'
    type:t='right'
    directionImg {}
  }
}
<</isHalignRight>>
<</needPlaceInHiddenContainer>>

<<#needPlaceInHiddenContainer>>
} // Closes frame block.
<</needPlaceInHiddenContainer>>
