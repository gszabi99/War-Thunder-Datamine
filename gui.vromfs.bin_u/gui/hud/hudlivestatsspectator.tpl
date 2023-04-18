tdiv {
  id:t='hud_live_stats'
  pos:t='pw/2-w/2, ph/2-h/2'
  position:t='relative'
  width:t='pw'
  padding:t='1@sIco'
  flow:t='vertical'

  <<#title>>
  textareaNoTab {
    id:t='title'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    style:t='color:@white; font:@fontHudMedium'
    text:t='<<title>>'
  }
  <</title>>

  table {
    id:t='mpstats'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    padding:t='0, 0.5@sIco'
    baseRow:t='rows16'

    tr {
      <<#player>>
      td {
        id:t='plate_<<id>>'
        tooltip:t='<<tooltip>>'
        display:t='hide'
        <<#fontIcon>>
        fontIcon32 {
          style:t='pos:0, 50%ph-50%h;'
          margin:t='0.5@sIco, 0'
          fonticon { text:t='<<fontIcon>>' }
        }
        <</fontIcon>>
        text {
          id:t='txt_<<id>>'
          pos:t='0, ph/2-h/2'
          position:t='relative'
          overlayTextColor:t='active'
          text:t=''
        }
      }
      <</player>>

      <<#lifetime>>
      td {
        id:t='lifetime'
        tooltip:t='#debriefing/sessionTime'
        fontIcon32 {
          style:t='pos:0, 50%ph-50%h;'
          margin:t='0.5@sIco, 0'
          fonticon { style:t='color:#80808080' text:t='#icon/hourglass' }
        }
        text {
          id:t='txt_lifetime'
          pos:t='0, ph/2-h/2'
          position:t='relative'
          overlayTextColor:t='active'
          text:t=''
        }
      }
      <</lifetime>>
    }
  }

  timer {
    id:t='update_timer'
    timer_handler_func:t='update'
    timer_interval_msec:t='250'
  }
}
