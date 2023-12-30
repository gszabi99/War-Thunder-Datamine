<<#rewards>>
tdiv {
  margin:t='2@blockInterval'
  background-color:t='#2D343C'
  padding:t='0.5@dIco'
  <<#isOpened>>
  border:t='yes'
  border-color:t='#E73C5A'
  <</isOpened>>

  include "%gui/items/item.tpl"

  image {
    size:t='1@dIco, 1@dIco'
    pos:t='0.5pw-0.5w, - 0.5h'
    position:t='absolute'
    background-svg-size:t='1@dIco, 1@dIco'
    <<#isOpened>>
    background-image:t='!#ui/gameuiskin#radiobutton_promo.svg'
    background-color:t='#E73C5A'
    <</isOpened>>
    <<^isOpened>>
    background-image:t='#ui/gameuiskin#timebar.svg'
    background-color:t='@minorTextColor'
    <</isOpened>>

    text {
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      position:t='absolute'
      text:t='<<stageRequired>>'
      <<#isOpened>>
      overlayTextColor:t='active'
      <</isOpened>>
      <<^isOpened>>
      overlayTextColor:t='minor'
      <</isOpened>>
    }
  }

  <<#stageTooltipId>>
  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<stageTooltipId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</stageTooltipId>>
}
<</rewards>>
