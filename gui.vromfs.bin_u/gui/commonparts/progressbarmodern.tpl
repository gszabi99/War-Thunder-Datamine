everyDayRewardProgress {
  id:t='<<id>>'
  size:t='pw, ph'
  foreground-color:t='<<#color>><<color>><</color>><<^color>>@progressBarBlueColor<</color>>'
  <<#value>>
    value:t='<<value>>'
  <</value>>
  tooltip:t='<<tooltip>>'
  total-input-transparent:t='yes'
  css-hier-invalidate:t='yes'

  <<#additionalProgress>>
    additionalProgress {
      id:t='<<addId>>'
      size:t='pw, ph'
      position:t="absolute"
      background-color:t='@transparent'
      foreground-color:t='<<#addColor>><<addColor>><</addColor>><<^addColor>>@progressBarRedColor<</addColor>>'
      <<#addValue>>
        value:t='<<addValue>>'
      <</addValue>>
    }
  <</additionalProgress>>

  pattern {
    type:t='dark_diag_lines'
    position:t='absolute'
  }
}