tdiv {
  <<#medal>>
  warbondSpecialMedal {
    pos:t='<<#posX>><<posX>><</posX>><<^posX>>0<</posX>>, 0'
    position:t='relative'
    margin:t='2@blockInterval, 0'

    <<#title>>
      textareaNoTab {
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        text:t='<<title>>'
        tooltip:t='<<titleTooltip>>'
        margin-right:t='1@blockInterval'
      }
    <</title>>

    <<#sector>>
      warbondSpecialMedalImg {
        background-image:t='<<image>>'
        background-position:t='0'
        background-repeat:t='aspect-ratio'
        background-color:t='@inactiveWarbondMedalImgColor'
        width:t='1@battleTasksHardMedalWidth'
        height:t='w'
        pos:t='0, 50%ph-50%h'
        position:t='absolute'
      }
    <</sector>>

    warbondSpecialMedalImg {
      background-image:t='<<image>>'
      background-position:t='0'
      background-repeat:t='aspect-ratio'
      <<#inactive>>
        background-color:t='@inactiveWarbondMedalImgColor'
      <</inactive>>
      <<^inactive>>
        background-color:t='@warbondMedalImgColor'
      <</inactive>>

      width:t='1@battleTasksHardMedalWidth'
      height:t='w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      <<#sector>>
        re-type:t='sector'
        sector-angle-1:t='<<sector>>'
        sector-angle-2:t='360'
      <</sector>>
    }
    <<#countText>>
      activeText {
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        text:t='x<<countText>>'
      }
    <</countText>>
  }
  <</medal>>
}