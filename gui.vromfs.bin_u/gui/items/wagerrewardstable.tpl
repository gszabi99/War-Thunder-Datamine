table {
  margin-right:t='0.01*@scrn_tgt'
  width:t='pw'
  <<#rows>>
  tr {
    td {
      <<#showCheckedIcon>>
      img {
        position:t='absolute'
        size:t='@unlockIconSize, @unlockIconSize'
        background-image:t='#ui/gameuiskin#favorite'
        pos:t='0.25w,-0.3h'
      }
      <</showCheckedIcon>>
      textarea {
        removeParagraphIndent:t='yes'
        halign:t='center'
        text:t='<<#color>><color=<<color>>><</color>><<winCount>><<#color>></color><</color>>'
      }
    }
    td {
      textarea {
        removeParagraphIndent:t='yes'
        halign:t='center'
        text:t='<<#color>><color=<<color>>><</color>><<rewardText>><<#color>></color><</color>>'
      }
    }
    <<#secondaryRewardText>>
    td {
      textarea {
        removeParagraphIndent:t='yes'
        halign:t='center'
        text:t='<<#color>><color=<<color>>><</color>><<secondaryRewardText>><<#color>></color><</color>>'
      }
    }
    <</secondaryRewardText>>
  }
  <</rows>>
}
