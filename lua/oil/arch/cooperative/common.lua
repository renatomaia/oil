local port = require "oil.port"
local component = require "oil.component"
local base = require "oil.arch.basic.common"

return {
	BasicSystem = component.Template({
		tasks = port.Facet,
	}, base.BasicSystem),
}
