require 'rsolr'
require 'rsolr/cloud'
require 'active_support'
require 'active_support/core_ext'
require 'zk'
require 'zk-server'
require 'rspec/expectations'

RSpec.configure do |config|

  config.before(:suite) do 
    ZK::Server.run do |c|
      c.force_sync = false
    end
  end

  config.after(:suite) do
    ZK::Server.shutdown
  end

end

RSpec::Matchers.define :be_one_of do |expected|
  match do |actual|
    expected.include?(actual)
  end
end

RSpec::Matchers.define :become_soon do |expected|
  match do |actual|
    while(actual.call != expected) do
      Thread.pass
    end
    true
  end
  def supports_block_expectations?
    true
  end
end

