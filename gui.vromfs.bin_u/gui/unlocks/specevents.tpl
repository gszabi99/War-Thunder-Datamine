<<#events>>
tdiv {
  position:t="relative"
  size:t="@eventSlotWidth, 454@sf/@pf"

  tdiv {
    id:t='<<eventId>>'
    eventKey:t='<<eventKey>>'
    position:t='absolute'
    left:t='(pw-w)/2'
    size:t="300@sf/@pf, 454@sf/@pf"
    padding:t='@blockInterval, @blockInterval'
    flow:t='vertical'
    behavior:t='button'
    on_click:t='onEventClick'
    focusBtnName:t='A'
    total-input-transparent:t='yes'
    not-input-transparent:t='yes'
    css-hier-invalidate:t='yes'

    blur_foreground {}

    img {
      position:t='absolute'
      size:t='pw, ph'
      background-image:t='<<bgImage>>'
      background-svg-size:t='pw, ph'
      <<^isActive>>
      background-saturate:t='0'
      isLocked:t='yes'
      <</isActive>>
    }

    tdiv {
      position:t='relative'
      padding:t='@blockInterval'
      left:t='0.5pw-0.5w'

      img {
        id:t='locked_sign'
        position:t='relative'
        size:t='@sIco, @sIco'
        top:t='(ph-h)/2'
        background-image:t='#ui/gameuiskin#locked.svg'
        background-svg-size:t='@sIco, @sIco'
        display:t='<<#isLocked>>hide<</isLocked>><<^isLocked>>show<</isLocked>>'
      }

      tdiv {
        position:t='relative'
        max-width:t='p.p.w - @sIco - 2@blockInterval'
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
      position:t="relative"
      width:t='pw'
      padding:t='0, @blockInterval'
      text:t='<<statusText>>'
      text-align:t='center'
      smallFont:t='yes'
    }

    tdiv {
      position:t="absolute"
      flow:t='vertical'
      top:t='ph-h'
      width:t='pw'
      display:t='<<#isLocked>>show<</isLocked>><<^isLocked>>hide<</isLocked>>'

      textareaNoTab {
        position:t="relative"
        width:t='pw'
        text:t='#mainmenu/tasksCompleted'
        text-align:t='center'
      }

      textareaNoTab {
        position:t='relative'
        width:t='pw'
        overlayTextColor:t='active'
        text:t='<<completed>>/<<total>>'
        text-align:t='center'
      }

      tdiv {
        margin:t='4@blockInterval, 2@blockInterval, 4@blockInterval, 36@sf/@pf'
        position:t='relative'
        size:t='pw-8@blockInterval, @blockInterval'

        <<#progBar>>
        tdiv {
          position:t='relative'
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

    hover_dark_border {}
    focus_border {}
  }
}
<</events>>
