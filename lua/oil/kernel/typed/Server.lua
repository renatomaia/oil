--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4                                                               --
-- Title  : Server-Side Broker                                                --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- broker:Facet
-- 	[configs:table], [except:table] initialize([configs:table])
-- 	servant:object object(impl:object, [objectkey:string])
-- 	reference:string tostring(servant:object)
-- 	success:boolean, [except:table] pending()
-- 	success:boolean, [except:table] step()
-- 	success:boolean, [except:table] run()
-- 	success:boolean, [except:table] shutdown()
-- 
-- objects:Receptacle
-- 	objectkey:string register(impl:object, objectkey:string)
-- 
-- acceptor:Receptacle
-- 	configs:table, [except:table] setup([configs:table])
-- 	success:boolean, [except:table] hasrequest(configs:table)
-- 	success:boolean, [except:table] acceptone(configs:table)
-- 	success:boolean, [except:table] acceptall(configs:table)
-- 	success:boolean, [except:table] halt(configs:table)
-- 
-- references:Receptacle
-- 	reference:table referenceto(objectkey:string, accesspointinfo:table...)
-- 	stringfiedref:string encode(reference:table)
-- 
-- types:Receptacle
-- 	type:table resolve(type:string)
--------------------------------------------------------------------------------

local getmetatable = getmetatable
local rawget       = rawget
local rawset       = rawset
local setmetatable = setmetatable
local luatostring  = tostring

local table = require "loop.table"

local oo     = require "oil.oo"
local Server = require "oil.kernel.base.Server"                                 --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Server"

oo.class(_M, Server)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function object(self, object, key, type)
	local context = self.context
	if not key then
		local meta = getmetatable(object)
		local backup
		if meta then
			backup = rawget(meta, "__tostring")
			if backup ~= nil then rawset(meta, "__tostring", nil) end
		end
		key = luatostring(object):match("%l+: (%w+)")
		if meta then
			if backup ~= nil then rawset(meta, "__tostring", backup) end
		end
	end
	type   = context.types:resolve(type)
	type   = context.mapper:register(type, key)
	object = context.objects:register(object, key)
	key    = context.references:referenceto(key, self.config)
	return table.copy(key, object)
end
