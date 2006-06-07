--------------------------------------------------------------------------------
-- Project: Extra Utilities for Lua                                           --
-- Version: 2.0 alpha                                                         --
-- Title  : Coroutine Scheduler Integrated with LuaSocket API                 --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--          Carlos Cassino <cassino@tecgraf.puc-rio.br>                       --
-- Date   : 03/08/2005 16:11                                                  --
--------------------------------------------------------------------------------

local type         = type
local pairs        = pairs
local assert       = assert
local ipairs       = ipairs
local tostring     = tostring
local unpack       = unpack
local setmetatable = setmetatable
local require      = require
local error        = error

local string       = require "string"
local os           = require "os"
local table        = require "table"
local math         = require "math"
local coroutine    = require "coroutine"

module "scheduler"

--------------------------------------------------------------------------------
-- ######   #####   ##   ##  #######  ######   ##   ##  ##     #######  ###### 
--##       ##   ##  ##   ##  ##       ##   ##  ##   ##  ##     ##       ##   ##
-- #####   ##       #######  #####    ##   ##  ##   ##  ##     #####    ###### 
--     ##  ##   ##  ##   ##  ##       ##   ##  ##   ##  ##     ##       ##   ##
--######    #####   ##   ##  #######  ######    #####   ###### #######  ##   ##
--------------------------------------------------------------------------------

require "coroutine"
require "table"
require "os"                                                                    --[[VERBOSE]] local verbose = require "loop.debug.verbose" local verbose_tabs, Labels = setmetatable({}, {__mode = "v"})

--------------------------------------------------------------------------------
-- Required data structures ----------------------------------------------------
--------------------------------------------------------------------------------

local OrderedSet = require "loop.collection.OrderedSet"
local PriorityQueue = require "loop.collection.PriorityQueue"
local MapWithKeyArray = require "loop.collection.MapWithKeyArray"

--------------------------------------------------------------------------------
-- Local module variables ------------------------------------------------------
--------------------------------------------------------------------------------

local CurrentRoutine
local CurrentRoutineKey

local RoutineTrap
local RunningQueue
local SleepingQueue
local SuspendedSet
local PCallMap

local BlockedReadSet -- Maps sockets to blocked threads. Hold a list of sockets on numeric indices
local BlockedWriteSet -- Maps sockets to blocked threads. Hold a list of sockets on numeric indices
local ReadLocks
local WriteLocks

local socketselect
local ossleep
local ostime

local StartTime = os.time()
function ostime() return os.difftime(os.time(), StartTime) end

--------------------------------------------------------------------------------
-- Internal functions ----------------------------------------------------------
--------------------------------------------------------------------------------
                                                                                --[[VERBOSE]] local verbose_base, verbose_routine
local function resume_all(success, ...)                                         --[[VERBOSE]] if success ~= nil then verbose_tabs[verbose_routine] = verbose.gettab() verbose.settab(verbose_base) verbose.threads() end
	if CurrentRoutine then
		local routine = CurrentRoutine
		if coroutine.status(routine) == "dead" then      														--[[VERBOSE]] verbose.threads{"thread finished ", Labels[routine]}
			CurrentRoutine = nil
			RunningQueue:remove(routine, CurrentRoutineKey)
			if RoutineTrap[routine] then                                              --[[VERBOSE]] verbose.threads({"executing trap for thread ", Labels[routine]}, true)
				RoutineTrap[routine](routine, success, unpack(arg, 1, arg.n))                     --[[VERBOSE]] verbose.threads()
				RoutineTrap[routine] = nil
			elseif not success then
				error("["..tostring(routine).."]: "..tostring(arg[1]))
			end
		elseif RunningQueue:contains(routine) then
			CurrentRoutineKey = routine
		end
	end
	CurrentRoutine = RunningQueue[CurrentRoutineKey]                              --[[VERBOSE]] if CurrentRoutine then verbose_routine = CurrentRoutine verbose.threads({"resuming thread ", Labels[verbose_routine]}, true) verbose_base = verbose.gettab() if verbose_tabs[verbose_routine] then verbose.settab(verbose_tabs[verbose_routine]) end end
	if CurrentRoutine
		then return resume_all(coroutine.resume(CurrentRoutine, unpack(arg, 1, arg.n)))
		else return success ~= nil                                                  --[[VERBOSE]] , verbose.scheduler()
	end
end

local function process_running_queue()                                          --[[VERBOSE]] verbose.scheduler("processing running queue", true)
	CurrentRoutineKey = OrderedSet.firstkey
	return resume_all()
end

--------------------------------------------------------------------------------

local function remove_blocked(routine, waitingtype)
	local unblocked
	if waitingtype ~= "write" then
		local index = 1
		while index <= table.getn(BlockedReadSet) do
			local socket = BlockedReadSet[index]
			if BlockedReadSet[socket] == routine then
				BlockedReadSet:removeat(index)
				ReadLocks[socket] = nil
				unblocked = true                                                        --[[VERBOSE]] verbose.threads{"thread ", Labels[routine]," removed from read block on socket ", Labels[socket]}
			else
				index = index + 1
			end
		end
	end
	if waitingtype ~= "read" then
		local index = 1
		while index <= table.getn(BlockedWriteSet) do
			local socket = BlockedWriteSet[index]
			if BlockedWriteSet[socket] == routine then
				BlockedWriteSet:removeat(index)
				WriteLocks[socket] = nil
				unblocked = true                                                        --[[VERBOSE]] verbose.threads{"thread ", Labels[routine], " removed from write block on socket ", Labels[socket]}
			else
				index = index + 1
			end
		end
	end
	return unblocked
end

local function process_blocked_set(timeout)
	if (table.getn(BlockedReadSet) > 0) or (table.getn(BlockedWriteSet) > 0) then --[[VERBOSE]] verbose.scheduler({"processing threads blocked on sockets for up to ", timeout, " seconds"}, true)
		
		assert(socketselect, "no socket API defined on scheduler")
		
		local ready_read, ready_write = 
			socketselect(BlockedReadSet, BlockedWriteSet, timeout)                    --[[VERBOSE]] verbose.wappedsockets{ "ready sockets selected: read(", table.getn(ready_read), "); write(", table.getn(ready_write), ")" }
	
		local index = 1
		while index <= table.getn(BlockedReadSet) do
			local socket = BlockedReadSet[index]
			if ready_read[socket] then
				RunningQueue:enqueue(BlockedReadSet[socket])                            --[[VERBOSE]] local verbose_routine = BlockedReadSet[socket]
				BlockedReadSet:removeat(index)                                          --[[VERBOSE]] verbose.threads{"unblocking thread ", Labels[verbose_routine], " due to data availability on socket ", Labels[socket]}
			else
				index = index + 1
			end
		end
		index = 1
		while index <= table.getn(BlockedWriteSet) do
			local socket = BlockedWriteSet[index]
			if ready_write[socket] then
				RunningQueue:enqueue(BlockedWriteSet[socket])                           --[[VERBOSE]] local verbose_routine = BlockedWriteSet[socket]
				BlockedWriteSet:removeat(index)                                         --[[VERBOSE]] verbose.threads{"unblocking thread ", Labels[verbose_routine], " due to buffer space availability on socket ", Labels[socket]}
			else
				index = index + 1
			end
		end                                                                         --[[VERBOSE]] verbose.scheduler()
		
		return true -- notify that blocked routine processing was done
		
	elseif timeout and ossleep then                                               --[[VERBOSE]] verbose.scheduler{"no processing for blocked threads, sleeping for ", timeout, " seconds"}
		
		ossleep(timeout)
		
	end
	
	return false -- notify that no blocked routine processing was done
end

--------------------------------------------------------------------------------

local function process_sleeping_queue()
	if SleepingQueue:head() then                                                  --[[VERBOSE]] verbose.scheduler("processing sleeping queue", true)
		local now = ostime()
		repeat
			if SleepingQueue:wakeup(SleepingQueue:head()) <= now
				then RunningQueue:enqueue(SleepingQueue:dequeue())                      --[[VERBOSE]] verbose.threads{"thread ", Labels[RunningQueue:tail()], " woke up due to timeout"}
				else break
			end
		until SleepingQueue:empty()                                                 --[[VERBOSE]] verbose.scheduler()
		
		return true -- notify that sleeping routine processing was done
	end
	return false -- notify that no sleeping routine processing was done
end

local function sleep_as_needed(timeout)
	if RunningQueue:empty() then
		if SleepingQueue:head() then
			local sleep_time = SleepingQueue:wakeup(SleepingQueue:head()) - ostime()
			if not timeout or sleep_time < timeout then
				timeout = math.max(sleep_time, 0)
			end 
		end                                                                         --[[VERBOSE]] verbose.scheduler({"sleeping for ", timeout, " seconds"}, true)
		process_blocked_set(timeout)                                                --[[VERBOSE]] verbose.scheduler()
	end
end

--------------------------------------------------------------------------------
-- Exported API ----------------------------------------------------------------
--------------------------------------------------------------------------------

function reset()                                                                --[[VERBOSE]] verbose.scheduler "reseting scheduler"
	RunningQueue = OrderedSet()
	SleepingQueue = PriorityQueue()
	SleepingQueue.wakeup = SleepingQueue.priority
	SuspendedSet = setmetatable({}, { __mode = "k" })
	PCallMap = {}

	BlockedReadSet = MapWithKeyArray{ n = 0 }
	BlockedWriteSet = MapWithKeyArray{ n = 0 }
	ReadLocks = {}
	WriteLocks = {}
	
	RoutineTrap = {}

	CurrentRoutine = nil
	CurrentRoutineKey = nil
end

function current()
	return CurrentRoutine
end

function new(func, ...)
	return RunningQueue:enqueue(
		coroutine.create(
			function()
				return func(unpack(arg, 1, arg.n))
			end
		)
	)                                                                             --[[VERBOSE]] , verbose.threads{"new thread created: ", Labels[RunningQueue:tail()]}
end

function remove(routine)
	assert(routine, "scheduled routine expected (got "..tostring(routine)..")")
	if CurrentRoutine == routine then
		RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)                      --[[VERBOSE]] verbose.threads{"current thread removed: ", Labels[routine]}
	elseif SuspendedSet[routine] then
		SuspendedSet[routine] = nil                                                 --[[VERBOSE]] verbose.threads{"suspended thread removed: ", Labels[routine]}
	elseif not RunningQueue:remove(routine) then
		SleepingQueue:remove(routine)
		remove_blocked(routine)                                                     --[[VERBOSE]] verbose.threads{"blocked (on socket or for timeout) thread removed: ", Labels[routine]} else verbose.scheduler{"executing thread removed: ", Labels[routine]}
	end
end

function trap(routine, callback)                                                --[[VERBOSE]] verbose.threads{"new trap created for thread ", Labels[routine]}
	RoutineTrap[routine] = callback
end

local function resumepcall(pcall, success, ...)
	if coroutine.status(pcall) == "suspended" then
		return resumepcall(pcall, coroutine.resume(pcall, coroutine.yield(unpack(arg, 1, arg.n))))
	else
		PCallMap[CurrentRoutine] = PCallMap[pcall]                                  --[[VERBOSE]] verbose.copcall "restoring old pcall and returning results" verbose.copcall()
		PCallMap[pcall] = nil
		return success, unpack(arg, 1, arg.n)
	end
end
function pcall(func, ...)
	assert(CurrentRoutine,
		"attempt to call scheduler operation out of a scheduled routine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
	
	local pcall = coroutine.create(func)                                          --[[VERBOSE]] verbose.copcall({"new protected call in thread ", Labels[CurrentRoutine]}, true)
	PCallMap[pcall] = PCallMap[CurrentRoutine]                                    --[[VERBOSE]] verbose.copcall "registering current pcall for recovery"
	PCallMap[CurrentRoutine] = pcall                                              --[[VERBOSE]] verbose.copcall{"setting the pcall for thread ", Labels[CurrentRoutine]}
	return resumepcall(pcall, coroutine.resume(pcall, unpack(arg, 1, arg.n)))
end

function sleep(sleep_time)
	assert(CurrentRoutine,
		"attempt to call scheduler operation out of a scheduled routine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
	assert(
		sleep_time == nil
			or
		(
			type(sleep_time) == "number"
				and
			sleep_time >= 0
		)
		,
		"invalid time (got " .. tostring(sleep_time) .. ").")
	
	RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)
	if sleep_time then
		local wakeup = ostime() + sleep_time
		assert(SleepingQueue:enqueue(CurrentRoutine, wakeup))                       --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked for ", sleep_time, " seconds"}
	else
		SuspendedSet[CurrentRoutine] = true                                         --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " suspended until signal"}
	end

	return coroutine.yield()
end

function wake(routine)
	if SuspendedSet[routine] then
		RunningQueue:insert(routine, CurrentRoutine)
		SuspendedSet[routine] = nil                                                 --[[VERBOSE]] verbose.threads{"suspended thread ", Labels[routine], " waken"}
	end
end

function step()                                                                 --[[VERBOSE]] verbose.scheduler("performing scheduler step", true)
	local sleeping = process_sleeping_queue()
	local blocked = process_blocked_set(0)
	local running = process_running_queue()
	return sleeping or blocked or running                                         --[[VERBOSE]] , verbose.scheduler()
end

function run(timeout)                                                           --[[VERBOSE]] verbose.scheduler({"executing scheduler for ", timeout, " seconds"}, true)
	local start = ostime()
	while step() do
		if timeout then
			timeout = timeout - (ostime() - start)
			if timeout < 0 then return end
		end
		sleep_as_needed(timeout)
	end                                                                           --[[VERBOSE]] verbose.scheduler()
end

function systemsleep(value)
	if value ~= nil then ossleep = value end
	return ossleep
end

--------------------------------------------------------------------------------
-- Initialization code ---------------------------------------------------------
--------------------------------------------------------------------------------

reset()

--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--------   ######   #####    #####   ##   ##  #######  #######   ###### --------
--------  ##       ##   ##  ##   ##  ##  ##   ##         ###    ##      --------
--------   #####   ##   ##  ##       #####    #####      ###     #####  --------
--------       ##  ##   ##  ##   ##  ##  ##   ##         ###         ## --------
--------  ######    #####    #####   ##   ##  #######    ###    ######  --------
--------------------------------------------------------------------------------

require "string"

--------------------------------------------------------------------------------
-- Required classes ------------------------------------------------------------
--------------------------------------------------------------------------------

local Wrapper = require "loop.extras.Wrapper"

--------------------------------------------------------------------------------
-- Internal functions ----------------------------------------------------------
--------------------------------------------------------------------------------

local wrap

local function wrapped_accept(self)                                             --[[VERBOSE]] verbose.wrappedsocket("performing wrapped accept", true)
	local socket = self.wrapped
	assert(socket,
		"bad argument #1 to `accept' (wrapped socket expected, got " ..
		tostring(self) .. ").")
	assert(CurrentRoutine,
		"attempt to call wrapped socket operation out of a coroutine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
	assert((BlockedReadSet[socket] == nil) and (ReadLocks[socket] == nil),
		"attempt to block a socket blocked for other coroutine.")
	
	local conn, errmsg = socket:accept()
	if conn then
		return wrap(conn)                                                           --[[VERBOSE]] , verbose.wrappedsocket "returning results without yielding"
    elseif errmsg ~= "timeout" then
		return nil, errmsg                                                          --[[VERBOSE]] , verbose.wrappedsocket "returning error without yielding"
	end

	-- block current thread on the socket
	BlockedReadSet:add(socket, CurrentRoutine)
	
	-- set to be waken at timeout, if specified
	local timeout
	if self.timeout and self.timeout >= 0 then
		timeout = ostime() + self.timeout
		SleepingQueue:enqueue(CurrentRoutine, timeout)
	end

	-- stop current thread
	RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)                        --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked listening on socket ", Labels[socket], " for up to ", self.timeout, " seconds"} verbose.wrappedsocket()

	coroutine.yield()                                                             --[[VERBOSE]] verbose.wrappedsocket("wrapped accept resumed", true)

	-- remove from sleeping queue, in case it was waken because of data on socket.
	if timeout then
		SleepingQueue:remove(CurrentRoutine)                                        --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " removed from sleeping queue"}
	end

	-- check if the socket is ready
	if BlockedReadSet[socket] == CurrentRoutine then                              --[[VERBOSE]] verbose.wrappedsocket "accept timed out"
		BlockedReadSet:remove(socket)                                               --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " released blocking on socket"}
		return nil, "timeout"                                                       --[[VERBOSE]] , verbose.wrappedsocket()
	else                                                                          --[[VERBOSE]] verbose.wrappedsocket "accepting new connection"
		return wrap(socket:accept())                                                --[[VERBOSE]] , verbose.wrappedsocket()
	end
end

--------------------------------------------------------------------------------

local function wrapped_connect(self, host, port)                                --[[VERBOSE]] verbose.wrappedsocket "performing synchronous connect"
	local socket = self.wrapped
	socket:settimeout(-1)
	local result, errmsg = socket:connect(host, port)
	socket:settimeout(0)
	return result, errmsg
end

--------------------------------------------------------------------------------

local function wrapped_receive(self, pattern)                                   --[[VERBOSE]] verbose.wrappedsocket("performing wrapped receive", true)
	local socket = self.wrapped
	assert(socket,
		"bad argument #1 to `receive' (wrapped socket expected, got " ..
		tostring(self) .. ").")
	assert(CurrentRoutine,
		"attempt to call wrapped socket operation out of a coroutine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
	assert((BlockedReadSet[socket] == nil) and (ReadLocks[socket] == nil),
		"attempt to block a socket blocked for other coroutine.")

	-- get data already avaliable
	local result, errmsg, partial = socket:receive(pattern)

	-- check if job has completed
	if not result and errmsg == "timeout" then

		-- reduce the number of required bytes
		if type(pattern) == "number" then
			pattern = pattern - string.len(partial)
		end
		
		-- lock socket to avoid use by other coroutines
		ReadLocks[socket] = true
	
		-- block current thread on the socket
		BlockedReadSet:add(socket, CurrentRoutine)
	
		-- set to be waken at timeout, if specified
		if self.timeout and (self.timeout >= 0) then
			local timeout = ostime() + self.timeout
			SleepingQueue:enqueue(CurrentRoutine, timeout)
		end
	
		repeat
			-- stop current thread
			RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)                    --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked reading socket ", Labels[socket], " for up to ", self.timeout, " seconds"} verbose.wrappedsocket()
			coroutine.yield()                                                         --[[VERBOSE]] verbose.wrappedsocket("wrapped receive resumed", true)
		
			-- check if the socket is ready
			if BlockedReadSet[socket] == CurrentRoutine then                          --[[VERBOSE]] verbose.wrappedsocket{"receive timed out", partial = partial}
				BlockedReadSet:remove(socket)                                           --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " released blocking on socket"}
				errmsg = "timeout"
			else                                                                      --[[VERBOSE]] verbose.wrappedsocket "reading data from socket"
				local newdata
				result, errmsg, newdata = socket:receive(pattern)
				if result then                                                          --[[VERBOSE]] verbose.wrappedsocket "received the whole requested data"
					result, errmsg, partial = partial..result, nil, nil
				else                                                                    --[[VERBOSE]] verbose.wrappedsocket "received only partial data"
					partial = partial..newdata
					
					if errmsg == "timeout" then
						-- reduce the number of required bytes
						if type(pattern) == "number" then
							pattern = pattern - string.len(newdata)
						end
						
						-- block current thread on the socket for more data
						BlockedReadSet:add(socket, CurrentRoutine)                          --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked once more reading socket ", Labels[socket], " for the rest of the requested data"}
						
						-- cancel error message
						errmsg = nil
					end
				end
			end
		until result or errmsg
	
		-- remove from sleeping queue, in case it was waken because of data on socket.
		if errmsg ~= "timeout" then
			SleepingQueue:remove(CurrentRoutine)                                      --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " removed from sleeping queue"}
		end
	
		-- unlock socket to allow use by other coroutines
		ReadLocks[socket] = nil                                                     --[[VERBOSE]] else verbose.wrappedsocket "returning results without yielding"
	
	end
	
	return result, errmsg, partial                                                --[[VERBOSE]] , verbose.wrappedsocket()
end

--------------------------------------------------------------------------------

local function wrapped_send(self, data, i, j)                                   --[[VERBOSE]] verbose.wrappedsocket("performing wrapped send", true)
	local socket = self.wrapped
	assert(socket,
		"bad argument #1 to `send' (wrapped socket expected, got " ..
		tostring(self) .. ").")
	assert(CurrentRoutine,
		"attempt to call wrapped socket operation out of a coroutine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
	assert((BlockedWriteSet[socket] == nil) and (WriteLocks[socket] == nil),
		"attempt to block a socket blocked for other coroutine.")

	-- fill buffer space already avaliable
	local sent, errmsg, i = socket:send(data, i, j)

	-- check if job has completed
	if not sent and errmsg == "timeout" then

		-- lock socket to avoid use by other coroutines
		WriteLocks[socket] = true
	
		-- block current thread on the socket
		BlockedWriteSet:add(socket, CurrentRoutine)
	
		-- set to be waken at timeout, if specified
		if self.timeout and (self.timeout >= 0) then
			local timeout = ostime() + self.timeout
			SleepingQueue:enqueue(CurrentRoutine, timeout)
		end
	
		repeat
			-- stop current thread
			RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)                    --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked writing on socket ", Labels[socket], " for up to ", self.timeout, " seconds"} verbose.wrappedsocket()
			
			coroutine.yield()                                                         --[[VERBOSE]] verbose.wrappedsocket("wrapped send resumed", true)
		
			-- check if the socket is ready
			if BlockedWriteSet[socket] == CurrentRoutine then                         --[[VERBOSE]] verbose.wrappedsocket "send timed out"
				BlockedWriteSet:remove(socket)
				errmsg = "timeout"
			else                                                                      --[[VERBOSE]] verbose.wrappedsocket "writing data on socket"
				sent, errmsg, i = socket:send(data, i + 1, j)
				if not sent then                                                        --[[VERBOSE]] verbose.wrappedsocket "sent only partial data"
					if errmsg == "timeout" then
						-- block current thread on the socket for more data
						BlockedWriteSet:add(socket, CurrentRoutine)                         --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked once more writing on socket ", Labels[socket], " for the rest of the provided data"}
						-- cancel error message
						errmsg = nil
					end                                                                   --[[VERBOSE]] else verbose.wrappedsocket "sent the whole supplied data"
				end
			end
		until sent or errmsg
	
		-- remove from sleeping queue, in case it was waken because of data on socket.
		if errmsg ~= "timeout" then
			SleepingQueue:remove(CurrentRoutine)                                      --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " removed from sleeping queue"}
		end
	
		-- unlock socket to allow use by other coroutines
		WriteLocks[socket] = nil                                                    --[[VERBOSE]] else verbose.wrappedsocket "returning results without yielding"
	
	end
	
	return sent, errmsg, i                                                        --[[VERBOSE]] , verbose.wrappedsocket()
end

--------------------------------------------------------------------------------

local function wrapped_select(recvt, sendt, timeout)                            --[[VERBOSE]] verbose.wrappedsocket("performing wrapped select", true)
	assert(CurrentRoutine,
		"attempt to call wrapped socket operation out of a coroutine context.")
	assert(coroutine.status(CurrentRoutine) == "running" or
	       coroutine.status(PCallMap[CurrentRoutine]) == "running",
		"inconsistent internal state, current scheduled routine is not running.")
		
	if
		( (not timeout) or (timeout < 0) ) and -- Comment this line to work as in Windows Sockets.
		(table.getn(recvt) <= 0) and
		(table.getn(sendt) <= 0)
	then                                                                          --[[VERBOSE]] verbose.wrappedsocket "no sockets for selection"
		return {}, {}                                                               --[[VERBOSE]] , verbose.wrappedsocket()
	end

	-- assert that no thread is already blocked on these sockets
	for index, socket in ipairs(recvt) do
		assert((BlockedReadSet[socket] == nil) and (ReadLocks[socket] == nil),
			"attempt to block for reading a socket blocked for other coroutine.")
	end
	for index, socket in ipairs(sendt) do
		assert((BlockedWriteSet[socket] == nil) and (WriteLocks[socket] == nil),
			"attempt to block for writing a socket blocked for other coroutine.")
	end

	local ready_read, ready_write, errmsg = socketselect(recvt, sendt, 0)

	if timeout ~= 0 and errmsg == "timeout" then                                                                          --[[VERBOSE]] verbose.wrappedsocket "socket are ready right now"
	
		-- block current thread on all the sockets
		for index, socket in ipairs(recvt) do
			BlockedReadSet:add(socket, CurrentRoutine)
		end
		for index, socket in ipairs(sendt) do
			BlockedWriteSet:add(socket, CurrentRoutine)
		end
		
		-- set to be waken at timeout, if specified
		if timeout and timeout >= 0 then
			local wakeup = ostime() + timeout
			SleepingQueue:enqueue(CurrentRoutine, wakeup)
		else
			timeout = nil
		end
	
		-- stop current thread
		RunningQueue:remove(CurrentRoutine, CurrentRoutineKey)                      --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " blocked on socket selection for up to ", timeout, " seconds"} verbose.wrappedsocket()
	
		coroutine.yield()                                                           --[[VERBOSE]] verbose.wrappedsocket("wrapped select resumed", true)
	
		-- remove from sleeping queue, in case it was waken because of data on socket.
		if timeout then
			if SleepingQueue:remove(CurrentRoutine)
				then errmsg = nil                                                       --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " removed from sleeping queue"}
				else errmsg = "timeout"                                                 --[[VERBOSE]] verbose.wrappedsocket "select timed out"
			end
		end
	
		-- check which sockets are ready and remove block for other sockets
		for index, socket in ipairs(recvt) do
			if BlockedReadSet[socket] == CurrentRoutine
				then BlockedReadSet:remove(socket)
				else ready_read[socket] = true
			end
		end
		for index, socket in ipairs(sendt) do
			if BlockedWriteSet[socket] == CurrentRoutine
				then BlockedWriteSet:remove(socket)
				else ready_write[socket] = true
			end
		end                                                                         --[[VERBOSE]] verbose.threads{"thread ", Labels[CurrentRoutine], " released blocks on sockets"} else verbose.wrappedsocket "returning results without yielding"	
	end
	
	return ready_read, ready_write, errmsg                                        --[[VERBOSE]] , verbose.wrappedsocket()
end

--------------------------------------------------------------------------------

local function wrapped_settimeout(self, timeout)
	self.timeout = timeout
end

--------------------------------------------------------------------------------

function wrap(socket, ...)                                                      --[[VERBOSE]] verbose.wrappedsocket "new wrapped socket"
	if socket then
		socket:settimeout(0)
		socket = Wrapper {
			wrapped = socket,

			settimeout = wrapped_settimeout,
			accept = wrapped_accept,
			connect = wrapped_connect,
			send = wrapped_send,
			receive = wrapped_receive,
		}
	end
	return socket, unpack(arg, 1, arg.n)
end

--------------------------------------------------------------------------------

local function wrapsocketapi(socket)                                            --[[VERBOSE]] verbose.wrappedsocket "wrapping socket API"
	
	local wrapped = setmetatable({
		scheduler = _M,
		
		newtry = socket.newtry,
		try = socket.try,
	
		sleep = sleep,
		select = wrapped_select,
	}, {__index = socket})
	
	function wrapped.tcp()
		return wrap(socket.tcp())
	end
	
	function wrapped.udp()
		return wrap(socket.udp())
	end
	
	function wrapped.connect(address, port)
		return wrap(socket.connect(address, port))
	end
	
	function wrapped.bind(address, port)
		return wrap(socket.bind(address, port))
	end
	
	return wrapped
end

--------------------------------------------------------------------------------
-- Module exported API ---------------------------------------------------------
--------------------------------------------------------------------------------

local WrappedAPI
function socketapi(socket)
	if socket then
		socketselect = socket.select
		if not ossleep then ossleep = socket.sleep end
		if SleepingQueue:empty() then
			ostime = socket.gettime
		end
		reset()
		WrappedAPI = wrapsocketapi(socket)
	end
	return WrappedAPI
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if verbose then

	require "io"
	local ObjectCache = require "loop.collection.ObjectCache"

	verbose.addgroup("concurrency", "scheduler","threads","copcall","wrappedsocket")
	
	Labels = ObjectCache{}
	local last_thread = 0
	local last_socket = 0
	local label_start = string.byte("A")
	
	function Labels:retrieve(element)
		if type(element) == "thread" then
			local id = last_thread
			local label = {}
			repeat
				table.insert(label, label_start + math.mod(id, 26))
				id = math.floor(id / 26)
			until id <= 0
			last_thread = last_thread + 1
			return string.char(unpack(label))
		else
			last_socket = last_socket + 1
			return last_socket
		end
	end
	
	function verbose.threads(message, start)
		if verbose.Flags.threads then
			if verbose.Details.threads and message then
				verbose.addtab()
				local newline = "\n"..verbose.gettabs()
				if type(message) ~= "table" then message = { message } end
				table.insert(message, newline)
				table.insert(message, "Current: ")
				if CurrentRoutine then table.insert(message, Labels[CurrentRoutine]) end
	
				table.insert(message, newline)
				table.insert(message, "Running:")
				for current in RunningQueue:sequence() do
					table.insert(message, " ")
					table.insert(message, Labels[current])
				end
				
				table.insert(message, newline)
				table.insert(message, "Sleeping:")
				for current in SleepingQueue:sequence() do
					table.insert(message, " ")
					table.insert(message, Labels[current])
				end
				
				table.insert(message, newline)
				table.insert(message, "Read Blocked:")
				for _, socket in ipairs(BlockedReadSet) do
					table.insert(message, " ")
					table.insert(message, Labels[ BlockedReadSet[socket] ])
					table.insert(message, ":")
					table.insert(message, Labels[socket])
				end
	
				table.insert(message, newline)
				table.insert(message, "Write Blocked:")
				for index, socket in ipairs(BlockedWriteSet) do
					table.insert(message, " ")
					table.insert(message, Labels[ BlockedWriteSet[socket] ])
					table.insert(message, ":")
					table.insert(message, Labels[socket])
				end
				
				table.insert(message, newline)
				table.insert(message, "Suspended:")
				for current, _ in pairs(SuspendedSet) do
					table.insert(message, " ")
					table.insert(message, Labels[current])
				end
				verbose.removetab()
			end
			return verbose.Flags.threads(message, start)
		end
	end

end
