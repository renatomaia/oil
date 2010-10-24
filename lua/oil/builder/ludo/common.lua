local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.ludo.common"

module "oil.builder.ludo.common"

ValueEncoder = arch.ValueEncoder  {require "oil.ludo.Codec"   }
ObjectReferrer = arch.ObjectReferrer{require "oil.ludo.Referrer"}

function create(comps)
	return builder.create(_M, comps)
end
