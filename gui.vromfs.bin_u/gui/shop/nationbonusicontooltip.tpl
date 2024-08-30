tdiv {
  flow:t='vertical'
  tdiv {
    flow:t='horizontal'
    activeText {
      text:t='#shop/unit_nation_bonus_tooltip/header'
      smallFont:t='yes'
    }
    <<#unitName>>
    activeText {
      text:t='<<unitName>>'
      smallFont:t='yes'
    }
    <</unitName>>
  }

  <<^isOver>>
    text {
      text:t='<<battlesRemain>>'
      smallFont:t='yes'
    }
    tdiv {
      flow:t='horizontal'
      textareaNoTab {
        smallFont:t='yes'
        text:t='<<bonusText>>'
      }
      <<^isRecentlyReleased>>
      img {
        background-image:t='#ui/gameuiskin#nation_bonus_icon.svg'
        size:t='14@sf/@pf, 18@sf/@pf'
        background-svg-size:t='28@sf/@pf, 36@sf/@pf'
      }
      text {
        text:t='<<rangNum>>'
        smallFont:t='yes'
      }
      <</isRecentlyReleased>>
    }

    textareaNoTab {
      text:t='<<percents>>'
      overlayTextColor:t='faded'
      smallFont:t='yes'
    }
  <</isOver>>

  <<#isOver>>
    tdiv {
      flow:t='horizontal'
      textareaNoTab {
        text:t='<<timeLabel>>'
        smallFont:t='yes'
      }
      textareaNoTab {
        id:t='time_text'
        text:t='<<timeText>>'
        smallFont:t='yes'
      }
    }
    timer{
      id:t='over_timer'
      seconds:t='0'
      timeInSeconds:t='<<timeInSeconds>>'
      timer_interval_msec:t='1000'
      timer_handler_func:t='updateNationBonusTooltipTime'
    }
  <</isOver>>
}