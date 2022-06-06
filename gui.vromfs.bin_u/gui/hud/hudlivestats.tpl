tdiv {
  id:t='hud_live_stats'
  pos:t='pw/2-w/2, ph/2-h/2'
  position:t='relative'
  width:t='pw'
  padding:t='12/720@shHud'
  flow:t='vertical'

  re-type:t='9rect'
  background-color:t='#000000'
  background-position:t='0, 3, 0, 4'
  background-repeat:t='expand'
  background-image:t='#ui/gameuiskin#expandable_item_sym_selected.png'

  <<#title>>
  textareaNoTab {
    id:t='title'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    padding-bottom:t='4/720@shHud'
    <<#isHeader>>
    style:t='font:@fontHudMedium'
    <</isHeader>>
    overlayTextColor:t='active'
    text:t='<<title>>'
  }
  <</title>>

  tdiv {
    id:t='hero_streaks'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    padding-bottom:t='4/720@shHud'
    width:t='sw -2@bwHud -32/720@shHud'
    flow-align:t='center'
    flow:t='h-flow'
  }

  tdiv {
    id:t='live_stats_mpstats'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    width:t='sw -2@bwHud -32/720@shHud'
    flow-align:t='center'
    flow:t='h-flow'

    <<#player>>
    tdiv {
      id:t='plate_<<id>>'
      tooltip:t='<<tooltip>>'
      padding:t='8/720@shHud, 0'
      flow:t='vertical'
      display:t='hide'

      tdiv {
        width:t='120/720@shHud'
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        flow:t='vertical'

        ribbonPlate {
          size:t='120/720@shHud, 48/720@shHud'
          position:t='relative'

          re-type:t='9rect'
          background-color:t='@white'
          background-position:t='4px'
          background-repeat:t='expand'
          background-image:t='#ui/gameuiskin#ribbonbar_bg.png'

          <<#fontIcon>>
          tdiv {
            size:t='ph-12px, ph-12px'
            pos:t='8px, ph/2-h/2'
            position:t='relative'

            text {
              pos:t='pw/2-w/2, ph/2-h/2'
              position:t='absolute'
              style:t='font:@fontBigBold; color:@white'
              font-tex:t='ui/gradient_v.ddsx'
              shadeStyle:t='LiveStats'
              text:t='<<fontIcon>>'
            }
          }
          <</fontIcon>>

          img {
            size:t='pw, ph'
            position:t='absolute'
            background-repeat:t='repeat'
            background-image:t='#ui/gameuiskin#pattern_bright_texture.png'
            background-position:t="4px"
          }

          tdiv {
            size:t='fw - 12/720@shHud, ph'
            <<^fontIcon>>
            size:t='pw, ph'
            <</fontIcon>>

            text {
              id:t='txt_<<id>>'
              pos:t='pw/2-w/2, ph/2-h/2'
              position:t='absolute'
              style:t='font:@fontHudMedium; color:@white'
              shadeStyle:t='LiveStats'
              text:t=''
            }
          }
        }

        <<#label>>
        textareaNoTab {
          id:t='lable_<<id>>'
          pos:t='pw/2-w/2, 4/720@shHud'
          position:t='relative'
          max-width:t='pw'
          text-align:t='center'
          text:t='<<label>>'
          style:t='font:@fontHudSmall; color:#80808080'
          shadeStyle:t='HudTinyLight'
        }
        <</label>>
      }
    }
    <</player>>
  }

  <<#units>>
  textareaNoTab {
    id:t='hero_units'
    pos:t='pw/2-w/2, 8/720@shHud'
    position:t='relative'
    text:t='<<units>>'
  }
  <</units>>

  timer {
    id:t='update_timer'
    timer_handler_func:t='update'
    timer_interval_msec:t='250'
  }
}
