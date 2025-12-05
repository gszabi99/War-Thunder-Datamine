module server_debug_common shared
require app

def exec_server_cmd(message : string) 
  send_command(message);
