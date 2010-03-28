local coroutine         = require "coroutine"
local oil               = require "oil"
local oo                = require "oil.oo"
local assert            = require "oil.assert"

module("oil.corba.services.event.EventQueue", oo.class)

-- filo por enquanto

count = 0

function enqueue(self, event)
  self.count = self.count + 1
  self[self.count] = event
  if self.count > 0 and self.waiting_thread then
    local t = self.waiting_thread
    self.waiting_thread = nil
    coroutine.yield("resume", t)
  end
end

function dequeue(self)
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

