require 'rsolr'
require 'rsolr/cloud'
require 'active_support'
require 'active_support/core_ext'
require 'zk'
require 'zk-server'
require 'rspec/expectations'

module Helpers
  def delete_with_children(zk, path)
    zk.children(path).each do |node|
      delete_with_children(zk, File.join(path, node))
    end
    zk.delete(path)
  rescue ZK::Exceptions::NoNode # rubocop:disable HandleExceptions
    # don't care if it already exists or not.
  end

  def wait_until(timeout = 10)
    started_on = Time.now
    result = false
    loop do
      result = yield
      break if result || started_on < timeout.second.ago
      Thread.pass
    end
    raise 'Timed out' unless result
  end
end

RSpec.configure do |config|
  config.include Helpers
  config.before(:suite) do
    ZK::Server.run do |c|
      c.force_sync = false
    end
  end
  config.after(:suite) do
    ZK::Server.server.clobber!
  end
end

RSpec::Matchers.define :be_one_of do |expected|
  match do |actual|
    expected.include?(actual)
  end
end

RSpec::Matchers.define :become_soon do |expected|
  match do |actual|
    begin
      wait_until do
        actual.call == expected
      end
    rescue
      false
    else
      true
    end
  end

  def supports_block_expectations?
    true
  end
end
