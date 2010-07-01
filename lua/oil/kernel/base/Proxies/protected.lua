return function(invoker)
	return function(self, ...)
		return invoker(self, ...):results(self.__timeout)
	end
end
