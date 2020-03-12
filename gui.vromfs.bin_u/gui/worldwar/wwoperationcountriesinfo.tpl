textAreaCentered {
  id:t='countries_vs_text'
  text-align:t='center'
  text:t='<<vsText>><<^vsText>>#country/VS<</vsText>>'

  <<#side1>>
  tdiv {
    pos:t='-w, 50%ph-50%h'
    position:t='absolute'
    padding-right:t='1@blockInterval'
    include "gui/worldWar/countriesListWithQueue"
  }
  <</side1>>

  <<#side2>>
  tdiv {
    pos:t='pw, 50%ph-50%h'
    position:t='absolute'
    padding-left:t='1@blockInterval'
    include "gui/worldWar/countriesListWithQueue"
  }
  <</side2>>
}