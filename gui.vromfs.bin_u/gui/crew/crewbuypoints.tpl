table {
  id:t='buy_table'
  pos:t='50%pw-50%w, 0.02sh'
  margin-bottom:t='0.02sh'
  position:t='relative'

  class:t='crewTable'
  selfFocusBorder:t='yes'
  behavior:t = 'HoverNavigator'

  <<#rows>>
  tr {
    id:t='<<id>>'
    <<#even>> even:t='yes' <</even>>

    td {
      cellType:t='left'
      padding-left:t='5*@sf/100.0'
      textareaNoTab {
        valign:t='center'
        text:t='<<skills>>'
      }
    }
    td {
      activeText {
        padding-left:t='2*@sf/100.0'
        valign:t='center'
        text:t='<<bonusText>>'
      }
    }
    td {
      padding-left:t='1*@scrn_tgt/100.0'
      textareaNoTab {
        min-width:t='10*@scrn_tgt/100.0'
        text-align:t='right'
        valign:t='center'
        text:t='<<cost>>'
      }
    }
    td {
      min-width:t='150*@sf/@pf_outdated'
      padding-right:t='5*@sf/100.0'

      Button_text {
        id:t='buttonRowApply';
        pos:t='0, 50%ph-50%h';
        position:t='relative';
        redDisabled:t='yes'
        showOn:t='hoverOrPcSelect'
        noMargin:t='yes'

        text:t='#mainmenu/btnBuy'
        tooltip:t='#mainmenu/btnBuySkillPoints'

        holderId:t='<<rowIdx>>'
        on_click:t='onButtonRowApply'
        btnName:t=''

        visualStyle:t='purchase'
        buttonWink {}
        buttonGlance{}

        ButtonImg {
          id:t='ButtonImg'
          btnName:t='A'
          showOn:t='hoverOrPcSelect'
        }
      }

      discount {
        id:t='buy_discount_<<rowIdx>>'
        text:t=''
        pos:t='pw-15%w-5*@sf/100.0, 50%ph-60%h'; position:t='absolute'
        rotation:t='-10'
      }
    }
  }
  <</rows>>
}

DummyButton {
  on_click:t='onButtonRowApply'
  btnName:t='A'
}