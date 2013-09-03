local oil = require "oil"
local oo = require "oil.oo"
local assert = require "oil.assert"
local os = require "os"

local EventFactory = oo.class()

function EventFactory:create(data)
  assert.type(data, "table")
  return {
    created = os.time(),
    data = data
  }
end

return EventFactory
