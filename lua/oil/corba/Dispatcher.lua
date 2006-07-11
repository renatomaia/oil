module "oil.corba.Dispatcher"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function isbaseof(baseid, iface)
	if iface.is_a then                                                            --[[VERBOSE]] verbose:servant(true, "executing interface is_a operation")
		return iface:is_a(baseid)                                                   --[[VERBOSE]] , verbose:servant(false)
	end                                                                           --[[VERBOSE]] verbose:servant(true, "checking if ", baseid, " is base of ", iface.repID)
	
	local data = { iface }
	while table.getn(data) > 0 do
		iface = table.remove(data)
		if not data[iface] then                                                     --[[VERBOSE]] verbose:servant("reached interface ", iface.repID)
			data[iface] = true
			if iface.repID == baseid then
				return true                                                             --[[VERBOSE]] , verbose:servant(false)
			end
			for _, base in ipairs(iface.base_interfaces) do
				table.insert(data, base)
			end
		end
	end                                                                           --[[VERBOSE]] verbose:servant(false)
	
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- TODO:[maia] add basic operations for servants
CorbaObject = oo.class({}, Object)

function Object:_is_a(repID)                                                    --[[VERBOSE]] verbose:servant(true, "verifying if object interface ", self._iface.repID, " is a ", repIDtrue )
	return isbaseof(repID, self._iface)                                           --[[VERBOSE]] , verbose:servant(false)
end

function Object:_interface()                                                    --[[VERBOSE]] verbose:servant "retrieveing object interface"
	local iface = self._iface
	if getmetatable(iface)
		then return iface
		else assert.raise{ "INTF_REPOS", minor_code_value = 1,
			reason = "interface",
			iface = iface,
		}
	end
end

function Object:_non_existent()                                                 --[[VERBOSE]] verbose:servant "probing for object existency, returning false"
	return false
end

function dispatch()
	
	-- if it is an attribute
		local result
		if member.inputs[1] 
			then servant[member.attribute] = buffer:get(member.inputs[1])     --[[VERBOSE]] verbose:dispatcher("changed the value of ", member.attribute)
			else result = servant[member.attribute]                           --[[VERBOSE]] verbose:dispatcher("the value of ", member.attribute, " is ", result)
		end                                                                 --[[VERBOSE]] verbose:dispatcher(false)
		if conn.pending[requestid] and header.response_expected then
			Reply.request_id = requestid                                      --[[VERBOSE]] verbose:dispatcher(true, "send reply for request ", requestid)
			Reply.reply_status = "NO_EXCEPTION"
			local stream = createMessage(self, ReplyID, Reply,
														member.outputs, result)
			_, except = conn:send(stream)                                     --[[VERBOSE]] verbose:dispatcher(false) else verbose:dispatcher("no reply expected or canceled for request ", requestid)
		end

end

