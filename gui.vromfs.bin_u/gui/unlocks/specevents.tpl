<<#events>>
tdiv {
  id:t='<<eventId>>'
  eventKey:t='<<eventKey>>'
  position:t='relative'
  size:t='@eventSlotWidth + 1@eSItemMargin, 575@sf/@pf'
  margin-bottom:t='1@contAreaScrlOffset'
  total-input-transparent:t='yes'

  specEventCard {
    position:t='absolute'
    flow:t='vertical'
    size:t='@eventSlotWidth, ph'
    left:t='(pw-w)/2'
    css-hier-invalidate:t='yes'
    <<^isLocked>>
    isLockedCard:t='no'
    <</isLocked>>

    blur_foreground {}

    img {
      position:t='absolute'
      size:t='pw, ph'
      background-image:t='<<bgImage>>'
      background-svg-size:t='w, ph'
    }
    <<^isActive>>
    img {
      position:t='absolute'
      size:t='pw, ph'
      isDeadCardOverlay:t='yes'
    }
    <</isActive>>

    tdiv {
      position:t='absolute'
      size:t='pw, 180@sf/@pf'
      background-image:t='#ui/gameuiskin#specCardGradient@@ss.svg'
      background-svg-size:t='32, 180'
      background-color:t='@white'
      background-repeat:t='expand'
    }

    tdiv {
      position:t='absolute'
      size:t='pw, 180@sf/@pf'
      top:t='ph-h'
      rotation:t='180'
      background-image:t='#ui/gameuiskin#specCardGradient@@ss.svg'
      background-svg-size:t='32, 180'
      background-color:t='@white'
      background-repeat:t='expand'
    }

    hoverDiv {
      position:t='absolute'
      size:t='pw, ph'
      display:t='hide'

      tdiv {
        position:t='absolute'
        size:t='pw, 65@sf/@pf'
        top:t='ph-h'
        background-image:t='#ui/gameuiskin#specCardHoverGradient.svg'
        background-svg-size:t='160, 32'
        background-color:t='@white'
        background-repeat:t='expand'
      }

      tdiv {
        position:t='absolute'
        size:t='pw, 65@sf/@pf'
        rotation:t='180'
        background-image:t='#ui/gameuiskin#specCardHoverGradient.svg'
        background-svg-size:t='160, 32'
        background-color:t='@white'
        background-repeat:t='expand'
      }
    }

    tdiv {
      flow:t='horizontal'
      position:t='relative'
      left:t='0.5pw-0.5w'
      padding-top:t='40@sf/@pf'

      img {
        id:t='locked_sign'
        size:t='@sIco, @sIco'
        valign:t='center'
        background-image:t='#ui/gameuiskin#locked.svg'
        background-svg-size:t='@sIco, @sIco'
        display:t='<<#isLocked>>show<</isLocked>><<^isLocked>>hide<</isLocked>>'
      }

      tdiv {
        position:t='relative'
        max-width:t='p.p.w - @sIco - 2@blockInterval'
        valign:t='center'
        overflow:t='hidden'
        textareaNoTab {
          behaviour:t='OverflowScroller'
          visualStyle:t='default'
          text:t='<<nameText>>'
          text-align:t='center'
          mediumFont:t='yes'
        }
      }
    }

    textareaNoTab {
      width:t='pw'
      padding:t='0, @blockInterval'
      text:t='<<statusText>>'
      text-align:t='center'
      smallFont:t='yes'
    }

    <<#isActive>>
    tdiv {
      position:t='absolute'
      flow:t='vertical'
      top:t='ph-h-44@sf/@pf'
      width:t='pw'
      display:t='<<#isLocked>>hide<</isLocked>><<^isLocked>>show<</isLocked>>'

      textareaNoTab {
        position:t='relative'
        width:t='pw'
        text:t='#mainmenu/tasksCompleted'
        text-align:t='center'
      }

      textareaNoTab {
        width:t='pw'
        overlayTextColor:t='active'
        text:t='<<completed>>/<<total>>'
        text-align:t='center'
      }

      tdiv {
        position:t='relative'
        size:t='pw-120@sf/@pf, 6@sf/@pf'
        halign:t='center'
        margin-top:t='10@sf/@pf'

        <<#progBar>>
        tdiv {
          size:t='pw/<<total>>, ph'
          padding:t='1@dp, 0'
          tdiv {
            size:t='fw, ph'
            bgcolor:t='<<bgcolor>>'
          }
        }
        <</progBar>>
      }
    }
    specEventCardSelectRect{}
    <</isActive>>
    focus_border {}
  }
}
<</events>>