tdiv {
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
  table {
    pos:t='0, @blockInterval'
    position:t='relative'
    allAlignLeft:t="yes"
    class:t='noPad'
    smallFont:t='yes'
    <<#bulletActions>>
    tr {
      td {
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
      }
      td { text { text:t='<<text>>'; valign:t='center' } }
    }
    <</bulletActions>>
  }
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
      background-image:t='#ui/gameuiskin#new_icon'
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
  }
  <</expText>>
  <<#showPrice>>
  tdiv{
    id:t='discount';
    smallFont:t='yes'
    pos:t='pw-w, @blockInterval'
    position:t='relative'
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

timer {
  id:t = 'weapons_timer'
  timer_handler_func:t = 'onUpdateWeaponTooltip'
  timer_interval_msec:t='100'
}
