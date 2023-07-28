table {
  tr {
    <<#columns>>
    td {
      padding-left:t='4@blockInterval'
      padding-right:t='4@blockInterval'

      textareaNoTab {
        halign:t='center'
        text:t='#<<titleLocId>>'
      }
    }
    <</columns>>
  }
  <<#rows>>
  tr {
    <<#isEven>>
    even:t='yes'
    <</isEven>>

    <<#cells>>
    td {
      padding-left:t='4@blockInterval'
      padding-right:t='4@blockInterval'
      <<#cell>>
      <<#text>>
      activeText {
        text:t = '<<text>>'
      }
      <</text>>

      <<#image>>
      tdiv {
        size='pw, ph'
        margin-left='1@sf/@pf'

        img {
          halign='center'
          valign='center'
          background-image:t='<<src>>'
          <<#size>>
          size:t='<<size>>'
          background-svg-size:t='<<size>>'
          <</size>>
          <<^size>>
          size:t='1@sIco, 1@sIco'
          background-svg-size:t='1@sIco, 1@sIco'
          <</size>>
        }
      }
      <</image>>

      <<#hasFormula>>
      tdiv {
        position:t='relative'
        pos:t='pw-w, 0'

        include "%gui/debriefing/rewardSources.tpl"
      }
      <</hasFormula>>
      <</cell>>
    }
    <</cells>>
  }
  <</rows>>
}