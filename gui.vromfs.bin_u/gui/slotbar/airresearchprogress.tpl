<<#airResearchProgress>>
airResearchProgress {
  value:t='<<airResearchProgressValue>>'

  <<#airResearchProgressType>>
  type:t='<<airResearchProgressType>>'
  <</airResearchProgressType>>

  <<#airResearchProgressHasPaused>>
  <<#airResearchProgressIsPaused>>
  paused:t='yes'
  <</airResearchProgressIsPaused>>

  <<^airResearchProgressIsPaused>>
  paused:t='no'
  <</airResearchProgressIsPaused>>
  <</airResearchProgressHasPaused>>

  <<#airResearchProgressAbsolutePosition>>
  position:t='absolute'
  <</airResearchProgressAbsolutePosition>>


  <<#airResearchProgressHasDisplay>>
  <<#airResearchProgressDisplay>>
  display:t='show'
  <</airResearchProgressDisplay>>
  <<^airResearchProgressDisplay>>
  display:t='hide'
  <</airResearchProgressDisplay>>
  <</airResearchProgressHasDisplay>>
}
<</airResearchProgress>>
