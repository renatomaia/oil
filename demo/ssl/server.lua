oil = require "oil"

iorfile, killfile = ...

oil.main(function()
	orb = oil.init{
		flavor = "cooperative;corba;corba.ssl;kernel.ssl",
		options = {
			server = {
				security = "required",
				ssl = {
					key = "certs/server.key",
					certificate = "certs/server.crt",
					cafile = "certs/myca.crt",
				},
			},
		},
	}
	
	orb:loadidl [[
		module demo{
			module ssl{
				interface SSLDemo{
					void printCert();
				};
			};
		};
	]]
	
	servant = { __type = "::demo::ssl::SSLDemo" }
	function servant:printCert()
		print("[Server] invoked printCert()")
	end
	
	object = orb:newservant(servant)
	
	ref = tostring(object)

	if iorfile == nil or not oil.writeto(iorfile, ref) then
		print(ref)
	end

	if killfile ~= nil then
		repeat
			local file = io.open(killfile)
			if file ~= nil then
				file:close()
				break
			end
			oil.sleep(1)
		until false
		orb:shutdown()
	end
end)
