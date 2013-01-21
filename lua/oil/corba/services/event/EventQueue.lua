local coroutine = require "coroutine"
local oil = require "oil"
local oo = require "oil.oo"
local assert = require "oil.assert"

local EventQueue = oo.class{ count = 0 }

function EventQueue:enqueue(event)
  self.count = self.count + 1
  self[self.count] = event
  if self.count > 0 and self.waiting_thread then
    local t = self.waiting_thread
    self.waiting_thread = nil
    coroutine.yield("last", t)
  end
end

function EventQueue:dequeue()
  if self.count == 0 then
    assert.results(self.waiting_thread == nil)
    self.waiting_thread = coroutine.running()
    coroutine.yield("suspend")
  end
  local e = self[self.count]
  self[self.count] = nil
  self.count = self.count - 1
  return e
end

return EventQueue
