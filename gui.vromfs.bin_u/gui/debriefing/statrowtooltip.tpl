tdiv {
  flow:t='vertical'

  table {
    <<#rows>>
    tr {
      td {
        activeText {
          min-width:t='0.25@sf'
          parseTags:t='yes'
          text:t='<<name>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@sf'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<info>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@sf'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<time>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@sf'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<value>>'
        }
        <<#value_image>>
        img {
          size:t='1@sIco, 1@sIco'
          top:t='0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<value_image>>'
          background-svg-size:t='1@sIco, 1@sIco'
        }
        <</value_image>>
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@sf'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<reward>>'
        }
        <<#reward_image>>
        img {
          size:t='1@sIco, 1@sIco'
          top:t='0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<reward_image>>'
          background-svg-size:t='1@sIco, 1@sIco'
        }
        <</reward_image>>
      }
    }

    <<#bonuses>>
    tr {
      td {
        tdiv {
          pos:t='0.03@sf, 0'
          position:t='relative'
          width:t='0.07@sf'

          include "%gui/debriefing/rewardSources.tpl"
        }
      }
    }
    <</bonuses>>
    <</rows>>
  }

<<#tooltipComment>>
  _newline {}

  textareaNoTab {
    <<#commentMaxWidth>>
    max-width:t='<<commentMaxWidth>>'
    <</commentMaxWidth>>

    <<^commentMaxWidth>>
    max-width:t='0.65@sf'
    <</commentMaxWidth>>
    style:t='color:@fadedTextColor'
    smallFont:t='yes'
    text:t='<<tooltipComment>>'
  }
<</tooltipComment>>
}
