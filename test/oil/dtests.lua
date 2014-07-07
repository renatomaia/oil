local flavor

oil = require "oil"

oil.dtests = {
	checks = require "loop.test.checks",

	setup = function (flavorspec, hosts)
		flavor = flavorspec
		local flavorset = {}
		for name in flavorspec:gmatch('[^;]+') do
			flavorset[name] = true
		end
		if flavorset['corba.intercepted'] then
			flavorset.corba = true
		end
		oil.dtests.flavor = flavorset
		oil.dtests.hosts = hosts
	end,

	init = function (config)
		config = config or {}
		config.flavor = flavor
		config.tcpoptions = config.tcpoptions or {}
		config.tcpoptions.reuseaddr = true
		oil.dtests.orb = oil.init(config)
		return oil.dtests.orb
	end,
}

return oil.dtests
