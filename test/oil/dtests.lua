local flavor

oil = require "oil"

oil.dtests = {
	setup = function (flavorspec, hosts, checks)
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
		oil.dtests.checks = checks
	end,

	init = function (config)
		config = config or {}
		config.flavor = flavor
		config.tcpoptions = {reuseaddr=true}
		oil.dtests.orb = oil.init(config)
		return oil.dtests.orb
	end,
}

return oil.dtests
