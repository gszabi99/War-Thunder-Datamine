require ecs
require danetlibs.motion_matching.es.mm_events
require %game.events


[es(before=(animchar_es, human_anim_es, wait_motion_matching_job_es))]
def motion_matching_start_search_job(info : ParallelUpdateFrameDelayed)
  broadcastEventImmediate(MotionMatchingStartSearchJob(dt = info.dt))