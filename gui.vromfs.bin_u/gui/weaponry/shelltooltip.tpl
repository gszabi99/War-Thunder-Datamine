tdiv {
  flow:t='vertical'

  <<#warningText>>
  weaponTooltipBlock {
    margin-bottom:t='0.5*@bulletTooltipPadding'
    width:t='1@bulletTooltipCardWidth'
    padding:t='@bulletTooltipPadding, 0.5*@bulletTooltipPadding'

    warning_icon {
      size:t='@cIco, @cIco'
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='#ui/gameuiskin#new_icon.svg'
      background-svg-size:t='@cIco, @cIco'
      background-color:t='@white'
    }
    textareaNoTab {
      pos:t='0, ph/2-h/2'
      position:t='relative'
      smallFont:t='yes'
      overlayTextColor:t='warning'
      text:t='<<warningText>>'
    }
  }
  <</warningText>>

  <<#reqText>>
  weaponTooltipBlock {
    width:t='1@bulletTooltipCardWidth'
    margin-bottom:t='0.5*@bulletTooltipPadding'
    padding:t='@bulletTooltipPadding, 0.5*@bulletTooltipPadding'
    tooltipDesc {
      text:t='<<reqText>>'
    }
  }
  <</reqText>>

  weaponTooltipBlock {
    width:t='1@bulletTooltipCardWidth'
    flow:t='vertical'

    shellTooltipHeader {
      width:t='1@bulletTooltipCardWidth'
      padding:t='1@bulletTooltipPadding'
      background-color:t='@frameHeaderBackgroundColor'
      flow:t='vertical'

      textareaNoTab {
        fontSmall:t='yes'
        text:t='<<name>>'
      }
      tooltipDesc {
        tinyFont:t='yes'
        text:t='<<desc>>'
        max-width:t='@bulletAnimationWidth'
      }
    }

    <<#hasBulletAnimation>>
    shellTooltipAnimation {
      padding:t='1@bulletTooltipPadding'
      movie {
        size:t='1@bulletAnimationWidth, 1@bulletAnimationHeight'
        <<#bulletAnimations>>
        movie-load<<loadIdPosfix>>:t='<<fileName>>'
        <</bulletAnimations>>
        movie-autoStart:t='yes'
        movie-loop:t='yes'
      }
    }
    <</hasBulletAnimation>>

    <<#showBulletMainParams>>
    shellTooltipMainParams {
      css-hier-invalidate:t='yes'
      <<^hasBulletAnimation>>
      margin-top:t='1@bulletTooltipPadding'
      <</hasBulletAnimation>>
      width:t='1@bulletTooltipCardWidth'
      margin-bottom:t="1@bulletTooltipPadding"

      <<#bulletMainParams>>
      tdiv {
        position:t='absolute'
        left:t='1@bulletTooltipPadding + <<idx>> * ((( 1@bulletAnimationWidth - ( <<bulletMainParamsDividers>> * 1/2@bulletTooltipPadding )) / <<bulletMainParamsCount>> ) + 1/2@bulletTooltipPadding )'
        width:t='(1@bulletAnimationWidth - (<<bulletMainParamsDividers>> * 1/2@bulletTooltipPadding)) / <<bulletMainParamsCount>>'
        height:t='ph'
        background-color:t='@frameHeaderBackgroundColor'
      }
      tdiv {
        left:t='1@bulletTooltipPadding'
        position:t='relative'
        width:t='(1@bulletAnimationWidth - (<<bulletMainParamsDividers>> * 1/2@bulletTooltipPadding)) / <<bulletMainParamsCount>>'

        padding:t='0,1@bulletTooltipPadding'
        margin-right:t='1/2@bulletTooltipPadding'

        tdiv {
          valign:t='center'
          flow:t='vertical'
          left:t='pw/2-w/2'
          width:t='pw'
          textAreaSmall {
            text:t='<<value>>'
            position:t='relative'
            left:t='(pw-w)/2'
          }
          <<#text>>
          tooltipDesc {
            text:t='<<text>>'
            tinyFont:t='yes'
            text-align:t='center'
          }
          <</text>>
          <<@customDesc>>
        }
      }
      <</bulletMainParams>>
    }
    <</showBulletMainParams>>

    <<#bulletParams>>
    shellTooltipParams {
      width:t='1@bulletTooltipCardWidth'
      margin:t='1@bulletTooltipPadding, 0, 1@bulletTooltipPadding, 3/4@bulletTooltipPadding'
      <<^bulletMainParams>>
      margin-top:t='1@bulletTooltipPadding'
      <</bulletMainParams>>
      flow:t='vertical'
      <<#props>>
      <<^divider>>
      tdiv {
        margin-bottom:t='1/4@bulletTooltipPadding'
        <<#value>>
        activeText { text:t='<<value>>'; smallFont:t='yes' }
        textareaNoTab {
          text:t=' - <<text>>';
          smallFont:t='yes'
          valign:t='center';
          overlayTextColor:t='minor';
        }
        <</value>>
      }
      <</divider>>
      <<#divider>>
      horizontalLine {
        width:t='pw-2@bulletTooltipPadding'
        margin-top:t='1/2@bulletTooltipPadding'
        margin-bottom:t='3/4@bulletTooltipPadding'
      }
      <</divider>>
      <</props>>
    }
    <</bulletParams>>

    <<#bulletRicochetData>>
    shellTooltipRicochet {
      flow:t='vertical'
      width:t='1@bulletTooltipCardWidth'

      tooltipDesc {
        tinyFont:t='yes'
        text:t='<<text>>'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        background-color:t='@frameHeaderBackgroundColor'
      }

      tdiv {
        width:t='1@bulletTooltipCardWidth'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'

        <<#data>>
        tdiv {
          width:t='1/3@bulletAnimationWidth'
          flow-align:t='center'
          activeText { text:t='<<angle>> - '; smallFont:t='yes' }
          textareaNoTab { text:t='<<value>>'; smallFont:t='yes' }
          <<#rightBorder>>
          verticalLine {
            position:t='absolute';
            pos:t='pw,0';
            height:t='19@sf/@pf'
          }
          <</rightBorder>>
        }
        <</data>>
      }
    }
    <</bulletRicochetData>>

    <<#bulletPenetrationData>>
    include "%gui/weaponry/shellArmorPenetration.tpl"
    <</bulletPenetrationData>>

    <<#delayed>>
    animated_wait_icon
    {
      id:t='loading'
      pos:t="50%pw-50%w,0";
      position:t='relative';
      background-rotation:t = '0'
    }
    <</delayed>>

  <<#showFooter>>
  div {
    width:t='pw'
    include "%gui/weaponry/weaponTooltipFooter.tpl"
  }
  <</showFooter>>

  }
}

timer {
  id:t = 'weapons_timer'
  timer_handler_func:t = 'onUpdateWeaponTooltip'
  timer_interval_msec:t='100'
}
