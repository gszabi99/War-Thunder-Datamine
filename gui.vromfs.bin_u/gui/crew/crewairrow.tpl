<<#rows>>
tr {
  id:t='<<id>>'
  <<#even>> even:t='yes' <</even>>

  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<rowTooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  td {
    cellType:t='left';
    padding-left:t='5*@sf/100.0'
    optiontext { text:t='<<unitName>>' }
    cardImg { id:t='name_icon'; display:t='hide'; background-image:t='#ui/gameuiskin#crew_skill_points.svg' }
  }
  td {
    activeText { id:t='curValue'; text:t='<<curValue>>'; valign:t='center' }
    <<#hasProgressBar>>
    crewSpecProgressBar {
      id:t='crew_spec_progress_bar'
      height:t='@referenceProgressHeight'
      width:t='pw - 4*@sf/@pf_outdated'
      pos:t='0, ph-6*@sf/@pf_outdated'
      position:t='absolute'
      min:t='0'
      max:t='1000'
      value:t='<<progressBarValue>>'
      display:t='<<progressBarDisplay>>'
    }
    <</hasProgressBar>>
    cardImg { id:t='curValue_icon'; display:t='hide'; background-image:t='#ui/gameuiskin#crew_skill_points.svg' }
  }
  td {
    width:t='0.092@scrn_tgt'

    <<#btnSpec>>
    hoverBgButton {
      id:t='btn_spec<<id>>'
      size:t='ph, ph'
      pos:t='0, 50%ph-50%h'; position:t='relative'
      holderId:t='<<holderId>>'
      foreground-image:t='<<icon>>'
      foreground-position:t='3'
      enable:t='<<enable>>'
      on_click:t='onSpecIncrease<<id>>'

      title:t='$tooltipObj'
      tooltipObj {
        <<#isExpertSpecType>>tooltipId:t='<<buySpecTooltipId1>>'<</isExpertSpecType>>
        <<^isExpertSpecType>>tooltipId:t='<<buySpecTooltipId2>>'<</isExpertSpecType>>
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }
    <</btnSpec>>
  }
  td {
    padding-left:t='1*@scrn_tgt/100.0'
    textareaNoTab {
      id:t='cost';
      text:t='<<costText>>';
      min-width:t='10*@scrn_tgt/100.0';
      text-align:t='right';
      valign:t='center';
      display:t='<<#enableForBuy>>show<</enableForBuy>><<^enableForBuy>>hide<</enableForBuy>>'
    }
  }
  td {
    id:t='<<holderId>>'
    padding-right:t='5*@sf/100.0'
    min-width:t='0.15@sf'
    max-width:t='0.45@sf'

    Button_text {
      id:t='buttonRowApply';
      on_click:t='onButtonRowApply'
      text:t='<<buttonRowText>>'
      redDisabled:t='yes'
      pos:t='0, 50%ph-50%h';
      position:t='relative';
      noMargin:t='yes'
      display:t='<<buttonRowDisplay>>'
      enable:t='<<#enableForBuy>>yes<</enableForBuy>><<^enableForBuy>>no<</enableForBuy>>'
      btnName:t=''

      ButtonImg {
        id:t='ButtonImg'
        btnName:t='X'
        showOn:t='selectedAndEnabled'
      }

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<buySpecTooltipId>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }

    discount {
      id:t='buy-discount'
      text:t=''
      pos:t='pw-15%w-5*@sf/100.0, 50%ph-60%h'; position:t='absolute'
      rotation:t='-10'
    }
  }
}
<</rows>>
