tdiv {
  margin:t='1@framePadding, 0.02@scrn_tgt, 0, 0.03@scrn_tgt'

  activeText {
    text:t='#worldWar/waiting_session'
  }
}

tdiv {
  flow:t='vertical'
  margin-left:t='1@framePadding'

  <<#side>>
  tdiv {
    id:t='<<id>>'
    flow:t='vertical'
    margin-bottom:t='0.03@scrn_tgt'

    img {
      id:t='country'
      size:t='1@wwSmallCountryFlagWidth, 1@wwSmallCountryFlagHeight'
      margin-bottom:t='0.01@scrn_tgt'
      background-image:t=''
    }

    table {
      class:t='noPad'

      tr {
        td {
          cellType:t='right'
          optiontext {
            text:t='#events/handicap'
            padding-right:t='0.05@scrn_tgt'
            margin-bottom:t='0.01@scrn_tgt'
            overlayTextColor:t='active'
          }
        }
        td {
          optiontext {
            id:t='max_players_text'
            text:t='#ui/hyphen'
            overlayTextColor:t='active'
          }
        }
      }

      tr {
        td {
          cellType:t='right'
          optiontext {
            text:t='#worldwar/airfieldStrenght/clans_players'
            tooltip:t='#worldwar/airfieldStrenght/clans_players/tooltip'
            padding-right:t='0.05@scrn_tgt'
          }
        }
        td {
          optiontext {
            id:t='players_in_clans_count'
            text:t='#ui/hyphen'
          }
        }
      }

      tr {
        td {
          cellType:t='right'
          optiontext {
            text:t='#worldwar/airfieldStrenght/other'
            padding-right:t='0.05@scrn_tgt'
          }
        }
        td {
          optiontext {
            id:t='other_players_count'
            text:t='#ui/hyphen'
          }
        }
      }
    }
  }
  <</side>>
}

timer {
  id:t="ww_queue_update_timer"
  timer_handler_func:t='onTimerUpdate'
  timer_interval_msec:t='1000'
}
