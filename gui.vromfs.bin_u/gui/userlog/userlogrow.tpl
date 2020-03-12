highlightedRowLine {}
selImg {
  tdiv {
    size:t='pw, 5.5*@sf/100.0<<#buttonName>>+ 1@blockInterval<</buttonName>>'
    tdiv {
      size:t='pw, 5.5*@sf/100.0'
      padding-left:t='8.0*@scrn_tgt/100.0'
      padding-right:t='1*@scrn_tgt/100.0'

      tdiv {
        pos:t='4*@scrn_tgt/100.0-50%w, 50%ph-50%h'; position:t='absolute'
        cardImg { id:t='log_image'
          <<#logImg>>
          background-image:t='<<logImg>>'
          <</logImg>>
        }
        cardImg { id:t='log_image2'
          margin-left:t='0.5*@scrn_tgt/100.0'
          <<#logImg2>>
          background-image:t='<<logImg2>>'
          <</logImg2>>
        }
      }

      <<#logBonus>>
      tdiv {
        pos:t='-1, -2'; position:t='absolute'
        bonus {
          id:t='log_bonus'
          bonusType:t='<<bonusType>>'
          tooltip:t='<<tooltip>>'
          background-image:t='<<background-image>>'
        }
      }
      <</logBonus>>
      textAreaNoScroll { id:t='name';
        width:t='fw'; max-height:t='ph'; pare-text:t='yes'
        valign:t='center'; class:t='active'; overflow:t='hidden'
        padding-top:t='-0.5*@scrn_tgt/100.0'
        text:t=<<#name>>'<<name>>'<</name>><<^name>>''<</name>>
      }
      text { id:t='time'
        text:t=<<#time>>'<<time>>'<</time>><<^time>>''<</time>>
        min-width:t='0.20@sf'
        <<^buttonName>>
        valign:t='center'
        <</buttonName>>
        <<#buttonName>>
        margin-top:t='1*@scrn_tgt/100.0 - 1@selImgBottomPadding'
        <</buttonName>>
        text-align:t='right'; smallFont:t='yes'
      }

      <<#middle>>
      text { id:t='middle'; text:t='<<middle>>'; top:t='50%ph-50%h'; position:t='absolute'; width:t='pw'; text-align:t='center' }
      <</middle>>
    }
    <<#hasExpandImg>>
    expandImg {
      id:t='expandImg'
      height:t='1*@scrn_tgt/100.0'
      width:t='2h'
      pos:t='50%pw-50%w, ph-h'; position:t='absolute'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
    }
    <</hasExpandImg>>
  }

  <<#descriptionBlk>>
  hiddenDiv {
    id:t='hiddenDiv'
    width:t='pw'
    padding:t='8*@scrn_tgt/100.0, 0, 1*@scrn_tgt/100.0, 0'
    flow:t='vertical';
    <<@descriptionBlk>>
  }
  <</descriptionBlk>>

  <<#buttonName>>
  Button_text {
    pos:t='pw-w - 1*@scrn_tgt/100.0 - 1@selImgRightPadding, ph-h - 1*@scrn_tgt/100.0'
    position:t='absolute'
    noMargin:t='yes'
    text:t='<<buttonName>>'
    logIdx:t='<<logIdx>>'
    on_click:t = 'onUserLogAction'
    btnName:t=''
    ButtonImg {
      btnName:t='A'
      showOnSelect:t='focus'
    }
  }
  <</buttonName>>
}