local inventoryClient = require("scripts/inventory/inventoryClient.nut")

foreach (notificationName, callback in
          {
            ["mrpc.generic_notify"] = function (params)
              {
                local from = ::getTblValue("from", params)
                if (from == "web-service")
                  ::handle_web_rpc(params)
                else if (from == "inventory")
                  inventoryClient.handleRpc(params)
              },

            ["mrpc.generic_rpc"] = function (params, cb)
              {
                local from = ::getTblValue("from", params)
                if (from == "web-service")
                {
                  cb(::handle_web_rpc(params))
                  return
                }
                else if (from == "inventory")
                {
                  inventoryClient.handleRpc(params)
                  return
                }
                cb({error = "unknown service"})
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)

