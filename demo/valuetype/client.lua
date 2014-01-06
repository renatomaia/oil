local oil = require "oil"

oil.main(function()
	local orb = oil.init()
	orb:loadidlfile("valuetype.idl")
	
	local servant = orb:newproxy(assert(oil.readfrom("ref.ior")))
	
	local val = {
		__type = assert(orb.types:lookup("AccountVal")),
		m_account_id = 1234;
		m_owner = "John Doe";
		m_balance = 500;
	}
	
	servant:pass_account_val(val)
	
	orb:shutdown()
end)
