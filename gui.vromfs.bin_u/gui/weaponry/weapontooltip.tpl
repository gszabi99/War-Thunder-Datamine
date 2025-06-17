tdiv {
  flow:t='vertical'

  <<#topReqBlock>>
  weaponTooltipBlock {
    min-width:t='1@bulletTooltipCardWidthNarrow'
    max-width:t='1@bulletTooltipCardWidth'
    margin-bottom:t='0.5*@bulletTooltipPadding'
    padding:t='@bulletTooltipPadding, 0.5*@bulletTooltipPadding'
    tooltipDesc {
      text:t='<<topReqBlock>>'
    }
  }
  <</topReqBlock>>

  weaponTooltipBlock {
    min-width:t='1@bulletTooltipCardWidthNarrow'
    max-width:t='1@bulletTooltipCardWidth'
    padding:t='@bulletTooltipPadding, 0.5*@bulletTooltipPadding'
    flow:t='vertical'

    textareaNoTab {
      text:t='<<name>>'
    }
    tooltipDesc {
      text:t='<<reqText>>'
    }
    tooltipDesc {
      text:t='<<desc>>'
    }

    <<#hasSweepRange>>
    textareaNoTab {
      pos:t='0, @blockInterval'
      id:t='sweepRange'
      position:t='relative'
      text:t='#presets/wing_sweep_limitation'
      smallFont:t='yes'
      overlayTextColor:t='bad'
    }
    <</hasSweepRange>>

    <<#hasBulletAnimation>>
    tdiv {
      margin-top:t='1@blockInterval'
      movie {
        size:t='1@bulletAnimationWidth ,1@bulletAnimationHeight'
        <<#bulletAnimations>>
        movie-load<<loadIdPosfix>>:t='<<fileName>>'
        <</bulletAnimations>>
        movie-autoStart:t='yes'
        movie-loop:t='yes'
      }
    }
    <</hasBulletAnimation>>
    tdiv {
      pos:t='0, @blockInterval'
      position:t='relative'
      smallFont:t='yes'
      <<#bulletActions>>
      tdiv {
        padding-right:t='@blockInterval'
        modIcon{
          size:t='@modIcoSize, @modIcoSize'
          ignoreStatus:t='yes'
          wallpaper{
            pattern{type:t='bright_texture';}
          }
          tdiv{
            size:t='pw-9@sf/@pf, ph-9@sf/@pf'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            <<@visual>>
          }
        }
        text { text:t='<<text>>'; valign:t='center' }
      }
      <</bulletActions>>
    }

    <<#modificationAnimation>>
    tdiv {
      margin-top:t='1@blockInterval'
      movie {
        size:t='1@tooltipAnimationWidth , 1@tooltipAnimationHeight'
        movie-load:t='<<modificationAnimation>>'
        movie-autoStart:t='yes'
        movie-loop:t='yes'
      }
    }
    <</modificationAnimation>>
    tooltipDesc {
      pos:t='0, @blockInterval'
      position:t='relative'
      hideEmptyText:t='yes'
      text:t='<<addDesc>>'
    }

    <<#bulletParams>>
      tooltipDesc {
        pos:t='0, @blockInterval'
        position:t='relative'
        hideEmptyText:t='yes'
        text:t='<<header>>'
      }
      table {
        <<^header>>
        pos:t='0, @blockInterval'
        position:t='relative'
        <</header>>
        allAlignLeft:t="yes"
        class:t='noPad'
        smallFont:t='yes'

        <<#props>>
        tr {
          td { textareaNoTab { text:t='<<text>>' } }
          <<#value>>
          td { textareaNoTab { text:t='<<value>>'; padding-left:t='@blockInterval' } }
          <</value>>
          <<#values>>
          td { textareaNoTab { text:t='<<value>>'; padding-left:t='@blockInterval' } }
          <</values>>
        }
        <</props>>
      }
    <</bulletParams>>

    <<#bulletsDesc>>
    tooltipDesc {
      pos:t='0, @blockInterval'
      position:t='relative'
      hideEmptyText:t='yes'
      text:t='<<bulletsDesc>>'
    }
    <</bulletsDesc>>

    <<#warningText>>
    tdiv {
      pos:t='0, @blockInterval'
      position:t='relative'
      warning_icon {
        size:t='@cIco, @cIco'
        pos:t='0, ph/2-h/2'
        position:t='relative'
        background-image:t='#ui/gameuiskin#new_icon.svg'
        background-svg-size:t='@cIco, @cIco'
        background-color:t='@white'
      }
      textareaNoTab {
        pos:t='@blockInterval, ph/2-h/2'
        position:t='relative'
        smallFont:t='yes'
        overlayTextColor:t='warning'
        text:t='<<warningText>>'
      }
    }
    <</warningText>>

    <<#amountText>>
    textareaNoTab {
      pos:t='pw-w, @blockInterval'
      position:t='relative'
      smallFont:t='yes'
      text:t='<<amountText>>'
    }
    <</amountText>>

    <<#delayed>>
    animated_wait_icon
    {
      id:t='loading'
      pos:t="50%pw-50%w,0";
      position:t='relative';
      background-rotation:t = '0'
    }
    <</delayed>>
    <<#expText>>
    textareaNoTab {
      smallFont:t='yes'
      pos:t='pw-w, @blockInterval'
      position:t='relative'
      text:t='<<expText>>'
      <<^addDesc>>margin-top:t='18@sf/@pf'<</addDesc>>
    }
    <</expText>>
    <<#showPrice>>
    tdiv{
      id:t='discount';
      smallFont:t='yes'
      pos:t='pw-w, @blockInterval'
      position:t='relative'
      <<^addDesc>>margin-top:t='18@sf/@pf'<</addDesc>>
      textareaNoTab{
        text:t='<<?ugm/price>><<#noDiscountPrice>><<?ugm/withDiscount>><</noDiscountPrice>><<?ui/colon>>'
      }
      tdiv{
        textareaNoTab{
          text:t='<<noDiscountPrice>>'
          margin-right:t='3@sf/@pf'
          tdiv{
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t='absolute';
            size:t='pw, 1@dp';
            background-color:t='@oldPrice';
          }
        }
        textareaNoTab{
          text:t='<<currentPrice>>'
        }
      }
    }
    <</showPrice>>
  }
}

timer {
  id:t = 'weapons_timer'
  timer_handler_func:t = 'onUpdateWeaponTooltip'
  timer_interval_msec:t='100'
}
