tdiv {
  flow:t='vertical'
  table {
    class:t='btlReward'

    <<#compactColumns>>
    compactColumns:t='yes'
    <</compactColumns>>

    <<^compactColumns>>
    compactColumns:t='no'
    <</compactColumns>>

    tr {
      headerRow:t='yes'

      <<#columns>>
      td {
        <<#compactColumns>><<^isFirstCol>>
        cellSeparator {}
        <</isFirstCol>><</compactColumns>>

        textareaNoTab {
          halign:t='center'
          valign:t='center'
          text-align:t='center'
          text:t='#<<titleLocId>>'
        }
      }
      <</columns>>
    }
    <<#rows>>
    tr {
      headerRow:t='no'

      <<#isEven>>
      even:t='yes'
      <</isEven>>

      <<#cells>>
      td {
        <<#compactColumns>><<^isFirstCol>>
        cellSeparator {}
        <</isFirstCol>><</compactColumns>>
        <<#cell>>
        <<#cellType>>
        cellType:t='<<cellType>>'
        <</cellType>>
        <<#hasFormula>>
        cellType:t='tdRight'
        <</hasFormula>>
        <<#image>>
        hasImage:t='yes'
        <</image>>
        <<^image>>
        hasImage:t='no'
        <</image>>
        <<#text>>
        activeText {
          valign:t='center'
          <<#isAlignCenter>>
          halign:t='center'
          <</isAlignCenter>>
          <<#parseTags>>
          parseTags:t='yes'
          <</parseTags>>
          text:t = '<<text>>'
        }
        <</text>>

        <<#hasFormula>>
        rewardFormula {
          position:t='relative'
          left:t='pw-w'
          valign:t='center'

          include "%gui/debriefing/rewardSources.tpl"
        }
        <</hasFormula>>

        <<#image>>
        tdiv {
          height:t='ph'
          margin-left:t='1@sf/@pf'

          img {
            halign:t='center'
            valign:t='center'
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
        <</cell>>
      }
      <</cells>>
    }
    <</rows>>
  }
  <<#isLongTooltip>>
  textareaNoTab {
    margin-left:t='4@blockInterval'
    text:t='...'
  }
  <<#allowToCopy>>
  textareaNoTab {
    margin-left:t='4@blockInterval'
    text:t='#userlog/copyToClipboardFullInfo'
  }
  <</allowToCopy>>
  <</isLongTooltip>>
}