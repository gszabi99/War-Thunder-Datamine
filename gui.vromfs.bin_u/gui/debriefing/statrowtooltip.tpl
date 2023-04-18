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
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@sf'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<reward>>'
        }
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
    max-width:t='0.65@sf'
    style:t='color:@fadedTextColor'
    smallFont:t='yes'
    text:t='<<tooltipComment>>'
  }
<</tooltipComment>>
}
