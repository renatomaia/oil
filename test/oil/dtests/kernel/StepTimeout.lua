local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()

orb:step(0)
orb:step(.1)
orb:step(.1)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{}
