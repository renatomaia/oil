local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()

local ok, res = pcall(orb.shutdown, orb)
assert(ok == false)
assert(res.error == "badinitialize")
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
