# frozen_string_literal: true

require 'mock_redis'

def redis
  @redis ||= MockRedis.new
  @redis
end

# Mock an object which represents a Logger.  This stops the proliferation
# of allow(logger).to .... expectations in tests.
class MockLogger
  def log(_level, string); end
end
