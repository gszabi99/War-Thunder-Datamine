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

    <<#images>>
      optionImg { background-image:t='<<image>>' <<#imageNoMargin>>noMargin:t='yes'<</imageNoMargin>> }
    <</images>>

    <<@addDiv>>

    <<#hueColor>>
      colorBlock {
        background-color:t='#<<hueColor>>'
      }
    <</hueColor>>

     <<#smallHueColor>>
      smallcolorBlock {
        background-color:t='#<<color>>'
      }
    <</smallHueColor>>

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
  }
  <</options>>

<<#controlTag>>
}
<</controlTag>>