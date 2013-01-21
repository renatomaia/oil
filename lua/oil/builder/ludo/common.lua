local arch = require "oil.arch.ludo.common"

return {
	ValueEncoder = arch.ValueEncoder{ require "oil.ludo.Codec" },
	ObjectReferrer = arch.ObjectReferrer{ require "oil.ludo.Referrer" },
}
