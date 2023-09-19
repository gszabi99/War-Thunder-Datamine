bonusTierItem {
  height:t='1@modItemHeight'
  width:t='<<itemWidth>>@modItemWidth'
  left:t='(<<posX>> + 0.5 * <<itemWidth>>) * 1@modCellWidth - 0.5w'
  top:t='(<<posY>> + 0.5) * 1@modCellHeight - 0.5h + 1@slotTopLineHeight - 1@slotBorderSize'
  position:t='absolute'
  flow:t='vertical'
  total-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  <<#isBonusTier>>
  id:t=<<id>>
  tooltip:t='<<tooltip>>'
  topLine {}
  progressBonus {
    progressCurrent {
      id:t='progressCurrent'
      width:t='<<progress>>pw'
    }
  }
  tdiv {
    flow:t='horizontal'
    halign:t='center'
    height:t='fh'
    tdiv {
      pos:t='pw/2 - w/2, ph/2 - h/2'
      position:t='absolute'
      img {
        id:t='favoriteImg'
        size:t='24@sf/@pf, 24@sf/@pf'
        background-image:t='#ui/gameuiskin#favorite'
        display:t=<<#isBonusReceived>>'show'<</isBonusReceived>><<^isBonusReceived>>'hide'<</isBonusReceived>>
      }
      textareaNoTab {
        id:t='bonusText'
        margin-top:t='2@sf/@pf'
        smallFont:t='yes'
        text:t=<<#isBonusReceived>>'#modification/bonusReceived'<</isBonusReceived>><<^isBonusReceived>><<bonus>><</isBonusReceived>>
      }
    }
  }
  <</isBonusTier>>
}
