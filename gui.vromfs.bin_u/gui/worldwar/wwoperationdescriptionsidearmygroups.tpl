tdiv {
  height:t='ph'
  flow:t='vertical'
  padding:t='1@framePadding'

  <<#isInvert>>
    left:t='pw-w'; position:t='relative'
  <</isInvert>>

  textareaNoTab {
    id:t='clan_block_text'
    <<#isInvert>>
      position:t='relative'
      right:t='0'
    <</isInvert>>
    margin-bottom:t='1@framePadding'
    text:t=''
    overlayTextColor:t='active'
  }

  <<#columns>>
  tdiv {
    height:t='ph'
    flow:t='vertical'
    <<#isInvert>>
      left:t='pw-w'; position:t='relative'
    <</isInvert>>

    <<#armyGroupNames>>
      textareaNoTab {
        <<^isSingleColumn>>
          height:t='@leaderboardTrHeight'
        <</isSingleColumn>>
        <<#isSingleColumn>>
          height:t='fh'
          max-height:t='1.3@leaderboardTrHeight'
        <</isSingleColumn>>
        <<#isInvert>>
          left:t='pw-w'; position:t='relative'
        <</isInvert>>
        text:t='<<name>>'
      }
    <</armyGroupNames>>
    <<#managers>>
      include "%gui/worldWar/wwArmyManagersStat.tpl"
    <</managers>>
  }
  <</columns>>
}