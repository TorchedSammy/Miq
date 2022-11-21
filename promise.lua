local Promise = {}

function Promise:__index(idx) return rawget(self, idx) or Promise[idx] end
function Promise.new(result) return setmetatable({ result = result, success = nil, _done = { }, _fail = { } }, Promise) end
function Promise:done(done) if self.success == true then done(self.result) else table.insert(self._done, done) end return self end
function Promise:fail(fail) if self.success == false then fail(self.result) else table.insert(self._fail, fail) end return self end
function Promise:resolve(result) self.result = result self.success = true for i,v in ipairs(self._done) do v(result) end return self end
function Promise:reject(result) self.result = result self.success = false for i,v in ipairs(self._fail) do v(result) end return self end
function Promise:forward(promise) self:done(function(data) promise:resolve(data) end) self:fail(function(data) promise:reject(data) end) return self end

return Promise
