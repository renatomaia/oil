local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
orb = oil.dtests.init()

local ok, ex = orb:step(0)
assert(ok == nil)
assert(ex.error == "timeout")

ok, ex = orb:step(.1)
assert(ok == nil)
assert(ex.error == "timeout")

ok, ex = orb:step(.1)
assert(ok == nil)
assert(ex.error == "timeout")

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{}
