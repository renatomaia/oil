return function()
	local oil = require "oil"
	local socket = require "socket.core"

	local hostname = socket.dns.gethostname()
	local portno = 2089
	local ip, dnsinfo = socket.dns.toip(hostname)

	assert(hostname == dnsinfo.name)
	for _, alias in ipairs(dnsinfo.alias) do
		if alias == hostname then hostname = nil end
	end
	dnsinfo.alias[#dnsinfo.alias+1] = hostname

	local cases = {
		localhost = {ip={"127.0.0.1"},names={"localhost"}},
		["127.0.0.1"] = {ip={"127.0.0.1"},names={"localhost"}},
		["*"] = {ip=dnsinfo.ip,names=dnsinfo.alias},
	}
	local custom = {host="custom",port=11}

	local function toset(...)
		local set = {}
		for index = 1, select("#", ...) do
			local list = select(index, ...)
			for _, value in ipairs(list) do
				set[value] = true
			end
		end
		return set
	end

	for host, info in pairs(cases) do
		for options, expected in pairs{
			[{}]                                              = toset(info.ip, info.names),

			[{usedns=false}]                                  = toset(info.ip),
			[{ipaddr=false}]                                  = toset(info.names),
			[{ipaddr=false,usedns=false,additional={custom}}] = toset({custom.host}),
			[{usedns=true}]                                   = toset(info.ip, info.names),
			[{usedns=false,additional={custom}}]              = toset(info.ip, {custom.host}),
			[{ipaddr=false,additional={custom}}]              = toset(info.names, {custom.host}),

			[{ipaddr=true ,usedns=false}]                     = toset(info.ip),
			[{ipaddr=false,usedns=true }]                     = toset(info.names),
			[{ipaddr=false,usedns=false,additional={custom}}] = toset({custom.host}),
			[{ipaddr=true ,usedns=true }]                     = toset(info.ip, info.names),
			[{ipaddr=true ,usedns=false,additional={custom}}] = toset(info.ip, {custom.host}),
			[{ipaddr=false,usedns=true ,additional={custom}}] = toset(info.names, {custom.host}),
		} do
			local orb = oil.init{ host = host, port = portno, objrefaddr = options }
			local servant = orb:newservant({}, nil, "::CORBA::InterfaceDef")
			local ref = servant.__reference
			for _, profile in ipairs(ref.profiles) do
				assert(profile.tag == 0)
				profile = assert(orb.IIOPProfiler.profiler:decode(profile.profile_data))
				assert(expected[profile.host] == true)
				expected[profile.host] = nil
				local expectedport = (profile.host == custom.host) and custom.port or portno
				assert(profile.port == expectedport)
			end
			assert(next(expected) == nil)
			orb:shutdown()
		end
	end
end
