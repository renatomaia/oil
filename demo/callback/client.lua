require "oil"

oil.main(function()
	local orb = oil.init()
	orb:loadidlfile("interfaces.idl")
	local service = orb:newproxy(assert(oil.readfrom("ref.ior")), nil, "TimeEventService")
	for i = 1, 3 do
		local timer
		timer = service:newtimer(i, {
			triggered = function(self, count)
				service:print(i..": Triggered "..count.." times")
			end
		})
		if i == 1 then i = "\n"..i end
		timer:enable()
	end
	orb:run()
end)
