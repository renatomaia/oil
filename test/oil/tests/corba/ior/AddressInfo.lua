return function()
	local oil = require "oil"
	local socket = require "socket.core"

	local hostname = socket.dns.gethostname()
	local portno = 2089
	local ip, dnsinfo = socket.dns.toip(hostname)

	assert(hostname == dnsinfo.name)
	for index, ip in ipairs(dnsinfo.ip) do
		dnsinfo.ip[index] = {host=ip,port=portno}
	end
	for index, alias in ipairs(dnsinfo.alias) do
		dnsinfo.alias[index] = {host=alias,port=portno}
		if alias == hostname then hostname = nil end
	end
	if hostname ~= nil then
		dnsinfo.alias[#dnsinfo.alias+1] = {host=hostname,port=portno}
	end

	local cases = {
		localhost = {
			ip = {{host="127.0.0.1",port=portno}},
			names = {{host="localhost",port=portno}},
		},
		["127.0.0.1"] = {
			ip = {{host="127.0.0.1",port=portno}},
			names = {{host="localhost",port=portno}},
		},
		["*"] = {
			ip = dnsinfo.ip,
			names = dnsinfo.alias,
		},
	}
	local additional = {
		{host="external"},
		{port=171},
		{host="althost",port=9802},
	}

	local function toset(...)
		local set = {}
		for index = 1, select("#", ...) do
			local list = select(index, ...)
			for _, value in ipairs(list) do
				local ports = set[value.host]
				if ports == nil then
					ports = {}
					set[value.host] = ports
				end
				ports[value.port] = true
			end
		end
		return set
	end

	for host, info in pairs(cases) do
		local ipdefault = {
			{host="external",port=portno},
			{host=info.ip[1].host,port=171},
			{host="althost",port=9802},
		}
		local namedefault = {
			{host="external",port=portno},
			{host=info.names[1].host,port=171},
			{host="althost",port=9802},
		}
		for options, expected in pairs{
			[{                                                    }] = toset(info.ip, info.names),
			[{                hostname=false                      }] = toset(info.ip),
			[{ipaddress=false                                     }] = toset(info.names),
			[{ipaddress=false,hostname=false                      }] = toset(info.ip),
			[{                               additional=additional}] = toset(info.ip, info.names, ipdefault),
			[{                hostname=false,additional=additional}] = toset(info.ip, ipdefault),
			[{ipaddress=false,               additional=additional}] = toset(info.names, namedefault),
			[{ipaddress=false,hostname=false,additional=additional}] = toset(ipdefault),

			[{ipaddress=true ,hostname=true                       }] = toset(info.ip, info.names),
			[{ipaddress=true ,hostname=false                      }] = toset(info.ip),
			[{ipaddress=false,hostname=true                       }] = toset(info.names),
			[{ipaddress=false,hostname=false                      }] = toset(info.ip),
			[{ipaddress=true ,hostname=true ,additional=additional}] = toset(info.ip, info.names, ipdefault),
			[{ipaddress=true ,hostname=false,additional=additional}] = toset(info.ip, ipdefault),
			[{ipaddress=false,hostname=true ,additional=additional}] = toset(info.names, namedefault),
			[{ipaddress=false,hostname=false,additional=additional}] = toset(ipdefault),
		} do
			local orb = oil.init{
				flavor = "corba",
				host = host,
				port = portno,
				objrefaddr = options,
			}
			local servant = orb:newservant({}, nil, "::CORBA::InterfaceDef")
			local ref = servant.__reference
			for _, profile in ipairs(ref.profiles) do
				assert(profile.tag == 0)
				profile = assert(orb.IIOPProfiler.profiler:decode(profile.profile_data))
				local ports = assert(expected[profile.host])
				assert(ports[profile.port] == true)
				ports[profile.port] = nil
				if next(ports) == nil then expected[profile.host] = nil end
			end
			assert(next(expected) == nil)
			orb:shutdown()
		end
	end
end
