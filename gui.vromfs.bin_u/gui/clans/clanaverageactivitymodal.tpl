root {
  id:t='clan_average_activity_modal'
  blur {}
  blur_foreground {}
  type:t='big'

  frame {
    width:t= '70*@scrn_tgt/100'
    pos:t='0.5pw-0.5w, 1@titleLogoPlateHeight + 0.3*(sh - 1@titleLogoPlateHeight - h)'
    position:t='absolute'
    class:t='wnd'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<clan_activity_header_text>>'
      }
      Button_close {}
    }

    table {
      width:t='pw'
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      padding:t='5@blockInterval, 1@blockInterval'
      class:t='pbarTable'

      <<#rows>>
      tr{
        display:t='<<progressDisplay>>'
        td{ activeText { text:t='<<title>>'; tdalign:t='left'; position:t='relative'; top:t='50%ph-50%h'} }
        td{
          tdiv {
            position:t='relative'
            pos:t='pw-0.4@scrn_tgt, 50%ph-50%h'
            width:t='<<#widthPercent>><<widthPercent>>%<</widthPercent>>0.4@scrn_tgt'

            <<#progress>>
            expProgress {
              width:t='pw'
              position:t='absolute'
              type:t='<<type>>'
              value:t='<<value>>'

              referenceMarker {
                left:t='<<markerPos>>%pw-50%w'
                rotation:t = '<<rotation>>'
                display:t='<<markerDisplay>>'
                <<textType>> {
                  top:t='-h'
                  rotation:t = '<<rotation>>'
                  left:t='<<textPos>>'
                  position:t='absolute'
                  text:t='<<text>>'
                  tooltip:t='<<tooltip>>'
                }
              }
            }
            <</progress>>
          }
        }
      }
      <</rows>>
    }

    textareaNoTab {
      padding:t='1@blockInterval'
      max-width:t='pw'
      text:t='<<clan_activity_description>>'
    }
  }
}