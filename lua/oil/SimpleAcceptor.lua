-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.3 alpha                                                         --
-- Title  : Internet Inter-ORB Protocol (IIOP) over sockets                   --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--          Antonio Theophilo     <theophilo@inf.puc-rio.br>                  --
--------------------------------------------------------------------------------
-- Connection interface:                                                      --
--   receive(reqid)   Returns a message ID, header and buffer with the data   --
--   send(i,h,t,d)    Sends a message with ID,header,contents types and data  --
--   close()          Closes the connection                                   --
--      
-- Port interface:                                                            --
--   profile(objid)   Returns a marshalled profile with port and object id    --
--   waitformore(t)   Wait for more messages for t to 2*t seconds             --
--   accept(orb)      Reads one request and treat it with the provided ORB    --
--   acceptall(orb)   Handles all subsequent requests with the provided ORB   --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 15.7 of CORBA 3.0 specification.                             --
--   See section 13.6.10.3 of CORBA 3.0 specification for IIOP corbaloc.      --
--------------------------------------------------------------------------------

local require      = require
local print        = print

local oo        = require "oil.oo"

module ( "oil.SimpleAcceptor", oo.class )                                          --[[VERBOSE]] local verbose = require "oil.verbose"

------------------------------------------------------------------------------
function accept(self)
	local channel = self.listener:getchannel(self)
	local request = self.listener:getrequest(channel)
	if request then
		local result, errmsg = self.dispatcher:handle(request)
		return result, errmsg
	else
		return true -- there is no request, wait for a new one
	end
end

function acceptall(self)
	local success, errmsg
	repeat
		success, errmsg = self:accept()
	until not success
	return success, errmsg
end
function init(self, args)
	self.host = args.host
	self.port = args.port
	iorhost = args.iorhost
	iorport = args.iorport
end

function getinfo(self)
  return { host = self.host, 
	         port = self.port,
	}
end
