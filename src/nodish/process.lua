local ev = require'ev'
local S = require'syscall'
local events = require'nodish.events'
local stream = require'nodish.stream'
local buffer = require'nodish.buffer'
local tinsert = table.insert

local stdin = function()
  local self = events.EventEmitter()
  self.watchers = {}
  stream.readable(self)
  self:setEncoding('utf8')
  S.stdin:nonblock(true)
  local chunkSize = 4096*2
  local buf
  self._read = function()
    if not buf or not buf:isReleased() then
      buf = buffer.Buffer(chunkSize)
    end
    local ret,err = S.stdin:read(buf.buf,chunkSize)
    if ret then
      if ret > 0 then
        buf:_setLength(ret)
        assert(buf.length == ret)
        data = buf
        return data,err
      elseif ret == 0 then
        return nil,nil,true
      end
    end
    return nil,err
  end
  self:addReadWatcher(S.stdin:getfd())
  return self
end

local stdout = function()
  local self = events.EventEmitter()
  self.watchers = {}
  stream.writable(self)
  S.stdout:nonblock(true)
  self._write = function(_,data)
    return S.stdout:write(data)
  end
  self:addWriteWatcher(S.stdout:getfd())
  return self
end

local stderr = function()
  local self = events.EventEmitter()
  self.watchers = {}
  stream.writable(self)
  S.stderr:nonblock(true)
  self._write = function(_,data)
    return S.stderr:write(data)
  end
  self:addWriteWatcher(S.stderr:getfd())
  return self
end

local unloop = function()
  print('quitting')
  ev.Loop.default:unloop()
end

local loop = function()
  local sigkill = 9
  local sigint = 2
  local sigquit = 3
  local sighup = 1
  for _,sig in ipairs({sigkill,sigint,sigquit,sighup}) do
    ev.Signal.new(
      unloop,
    sig):start(ev.Loop.default,true)
  end
  
  local sigpipe = 13
  ev.Signal.new(
    function()
      print('SIGPIPE ignored')
    end,
  sigpipe):start(ev.Loop.default,true)
  
  ev.Loop.default:loop()
end

return {
  nextTick = require'nodish.nexttick'.nextTick,
  stdin = stdin(),
  stdout = stdout(),
  stderr = stderr(),
  loop = loop,
  unloop = unloop,
}
