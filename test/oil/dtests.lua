local OIL_FLAVOR = OIL_FLAVOR

local oil = require "oil"

module "oil.dtests"

function init(config)
	config = config or {}
	config.flavor = OIL_FLAVOR
	config.tcpoptions = {reuseaddr=true}
	orb = oil.init(config)
	return orb
end
