table {
  width:t='pw'
  padding-bottom:t='2*@scrn_tgt/100.0'
  position='relative'
  pos='-0.5*@scrn_tgt/100.0, 0'
  <<#battleRewards>>
  tr {
    <<#battleRewardTooltipId>>
    title:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='<<battleRewardTooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    <</battleRewardTooltipId>>
    td {
      min-width:t='0.4@sf'
      activeText {
        text:t='<<name>>'
      }
    }

    td {
      width:t='0.1@sf'
      textareaNoTab {
        width:t='pw'
        text-align:t='right'
        style:t='color:@activeTextColor'
        text:t='<<count>>'
      }
    }

    td {
      textareaNoTab {
        width:t='pw'
        text-align:t='right'
        style:t='color:@activeTextColor'
        text:t='<<wp>>'
      }
    }

    td {
      textareaNoTab {
        width:t='pw'
        text-align:t='right'
        style:t='color:@activeTextColor'
        text:t='<<exp>>'
      }
    }

    <<#battleRewardTooltipId>>
    td {
      padding-left:t='4@blockInterval'
      img {
        width:t='@sIco'
        height:t='@sIco'
        valign:t='center'
        background-image:t='#ui/gameuiskin#btn_help.svg'
        background-svg-size:t='@sIco, @sIco'
        style:t='background-color:@gray'
      }
    }
    <</battleRewardTooltipId>>
  }
  <</battleRewards>>
}