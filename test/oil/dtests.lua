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
		config.options = config.options or {}
		config.options.tcp = config.options.tcp or {}
		config.options.tcp.reuseaddr = true
		if flavor:find("ssl", 1, true) then
			config.options.security = "preferred"
			config.options.ssl = config.options.ssl or {}
			config.options.ssl.key = "../certs/clientAkey.pem"
			config.options.ssl.certificate = "../certs/clientAcert.pem"
			config.options.ssl.cafile = "../certs/rootA.pem"
		end
		oil.dtests.orb = oil.init(config)
		return oil.dtests.orb
	end,
}

return oil.dtests
