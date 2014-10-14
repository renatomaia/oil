oil = require "oil"                                     -- Load OiL package

--oil.verbose:level(4)
--require("cothread").verbose:flag("socket", true)
--require("cothread").verbose:flag("ssl", true)

iorfile = assert(..., "missing path to IOR file")

oil.main(function()
	orb = oil.init{
		flavor = "cooperative;corba;corba.ssl;kernel.ssl",
		options = {
			client = {
				security = "required",
				ssl = {
					key = "certs/client.key",
					certificate = "certs/client.crt",
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
	
	object = orb:newproxy(assert(oil.readfrom(iorfile)), nil, "demo::ssl::SSLDemo")

	print("[Client] about to invoke printCert()")
	object:printCert()
	print("[Client] Call to server succeeded")

	orb:shutdown()
end)
