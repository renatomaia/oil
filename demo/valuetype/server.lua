local oil = require "oil"

oil.main(function()
	local servant = {}
	function servant:pass_account_val(val)
		print("account ID", val.m_account_id)
		print("account's owner", val.m_owner)
		print("account balance", val.m_balance)
		
		local before = val.m_balance
		val:pay_in(200)
		print("account balance", val.m_balance)
		val:withdraw(100)
		print("account balance", val.m_balance)
	end
	
	local orb = oil.init{
		valuefactories = {
			["IDL:AccountVal:1.0"] = function(val)
				function val:withdraw(value)
					if self.m_balance >= value then
						self.m_balance = self.m_balance - value
						return true
					end
					return false
				end
				function val:pay_in(value)
					self.m_balance = self.m_balance + value
				end
			end,
		}
	}
	orb:loadidlfile("valuetype.idl")
	
	local servant = orb:newservant(servant, nil, "PassByValue")
	
	local ref = tostring(servant)
	if not oil.writeto("ref.ior", ref) then
		print(ref)
	end
end)
