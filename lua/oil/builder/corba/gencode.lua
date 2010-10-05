local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.corba.common"

module "oil.builder.corba.gencode"

ValueEncoder = arch.ValueEncoder{require "oil.corba.giop.CodecGen"  }

function create(comps)
	return builder.create(_M, comps)
end
