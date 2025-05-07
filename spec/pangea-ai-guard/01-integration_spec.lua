local helpers = require("spec.helpers")
local http_mock = require("spec.helpers.http_mock")

for _, strategy in helpers.each_strategy() do
	describe("pangea-ai-guard [" .. strategy .. "]", function()
		describe("openai integration", function()
			it("rewrite request", function() end)
			it("rewrite response", function() end)
			it("block request", function() end)
			it("block response", function() end)
		end)
	end)
end
