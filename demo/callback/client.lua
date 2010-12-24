require "oil"

local port = ...

oil.main(function()
	local orb = oil.init{port=port}
	local service = orb:newproxy(assert(oil.readfrom("ref.ior")))
	for i = 1, 3 do
		local timer
		timer = service:newtimer(i, {
			triggered = function(self, count)
				service:print(i..": Triggered "..count.." times")
			end
		})
		timer:enable()
		if i == 1 then i = "\n"..i end
	end
	orb:run()
end)
