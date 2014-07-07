local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
orb = oil.dtests.init()
orb:shutdown()

local ok, res = pcall(orb.shutdown, orb)
assert(ok == false)
assert(res.error == "badsetup")
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
