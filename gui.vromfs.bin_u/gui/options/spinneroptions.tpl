<<#controlTag>>
<<controlTag>> {
  height:t='ph'
  <<#isDropright>>
  width:t='pw'
  <</isDropright>>
<</controlTag>>
<<@controlStyle>>

  <<#id>>
    id:t = '<<id>>'
  <</id>>
  <<#cb>>
    on_select:t = '<<cb>>'
  <</cb>>

  <<#beforeSelectCb>>
  on_before_select:t='<<beforeSelectCb>>'
  <</beforeSelectCb>>

  <<#options>>
  <<optionTag>> {
    <<#isDropright>>
    max-width:t='p.p.w-5%sh'
    <</isDropright>>
    pare-text:t='yes'

    <<^enabled>>
      enable:t='no'
    <</enabled>>
    <<#selected>>
      selected:t = 'yes'
    <</selected>>
    <<#inactive>>
      inactive:t='yes'
    <</inactive>>

    <<#images>>
      optionImg { background-image:t='<<image>>' <<#imageNoMargin>>noMargin:t='yes'<</imageNoMargin>> }
    <</images>>

    <<@addDiv>>

    <<#hueColor>>
      colorBlock {
        <<#imageInHueBlock>>
          img {
            background-image:t='<<imageInHueBlock>>'
          }
        <</imageInHueBlock>>
        <<^imageInHueBlock>>
          background-color:t='#<<hueColor>>'
        <</imageInHueBlock>>
      }
    <</hueColor>>

     <<#smallHueColor>>
      smallcolorBlock {
        background-color:t='#<<color>>'
      }
    <</smallHueColor>>

    <<#optName>>
      optName:t='<<optName>>'
    <</optName>>

    <<#text>>
      optiontext {
        id:t='option_text'
        text:t = '<<text>>'
        <<@textStyle>>

        <<#fontOverride>>
        style:t='font:<<fontOverride>>;'
        <</fontOverride>>
        <<@textStyle>>
      }
    <</text>>

    <<#imagesAfterText>>
    optionImg { background-image:t='<<image>>' }
    <</imagesAfterText>>

    <<#tooltip>>
      tooltip:t = '<<tooltip>>'
    <</tooltip>>
    <<#tooltipObj>>
      title:t='$tooltipObj';
      tooltipObj {
        id:t='tooltip_<<id>>';
        on_tooltip_open:t='<<open>><<^open>>onGenericTooltipOpen<</open>>';
        on_tooltip_close:t='<<close>><<^close>>onTooltipObjClose<</close>>';
        display:t='hide';
        <<@tooltipParams>>
      }
    <</tooltipObj>>
    <<#idx>>
    idx:t='<<idx>>'
    <</idx>>
    <<#onOptHoverFnName>>
    on_hover:t='<<onOptHoverFnName>>'
    <</onOptHoverFnName>>
  }
  <</options>>

<<#controlTag>>
}
<</controlTag>>