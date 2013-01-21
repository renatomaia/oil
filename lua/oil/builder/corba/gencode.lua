local arch = require "oil.arch.corba.common"

return {
	ValueEncoder = arch.ValueEncoder{ require "oil.corba.giop.CodecGen" },
}
