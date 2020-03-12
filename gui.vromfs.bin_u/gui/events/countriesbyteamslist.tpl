<<#countriesSets>>
tdiv {
<<^isCentered>>
  <<#teamA>>
  tdiv {
    id:t='countries1';
    pos:t='0, 50%ph-50%h'; position:t='relative'
    include "gui/countriesList"
  }
  <</teamA>>
  <<#teamB>>
  activeText {
    id:t='vsText'
    text:t='#country/VS';
    pos:t='0, 50%ph-50%h'; position:t='relative'
    margin:t='1@blockInterval, 0'
    text-align:t='center'
    mediumFont:t='yes'
  }
  tdiv {
    id:t='countries2';
    pos:t='0, 50%ph-50%h'; position:t='relative'
    include "gui/countriesList"
  }
  <</teamB>>
<</isCentered>>

<<#isCentered>>
  width:t='pw'

  activeText {
    id:t='vsText'
    text:t='#country/VS';
    pos:t='50%pw-50%w, 50%ph-50%h'; position:t='relative'
    mediumFont:t='yes'

    <<#teamA>>
    tdiv {
      id:t='countries1';
      pos:t='-w - 1@blockInterval, 50%ph-50%h'; position:t='absolute'
      include "gui/countriesList"
    }
    <</teamA>>

    <<#teamB>>
    tdiv {
      id:t='countries2';
      pos:t='pw + 1@blockInterval, 50%ph-50%h'; position:t='absolute'
      include "gui/countriesList"
    }
    <</teamB>>
  }
<</isCentered>>
}
<</countriesSets>>