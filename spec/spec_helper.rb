# frozen_string_literal: true

require 'webmock/rspec'
require 'tmpdir'
require 'tcg_csv'

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
end

def fixture(name)
  File.read(File.join(__dir__, 'fixtures', "#{name}.json"))
end

def stub_api(path, fixture_name)
  stub_request(:get, "https://tcgcsv.com#{path}")
    .to_return(status: 200, body: fixture(fixture_name), headers: { 'Content-Type' => 'application/json' })
end

# Temp cache directory for tests — cleaned up after each example
def test_cache_dir
  @test_cache_dir ||= Dir.mktmpdir('tcg_csv_test')
end

RSpec.configure do |config|
  config.after(:each) do
    if @test_cache_dir
      FileUtils.rm_rf(@test_cache_dir)
      @test_cache_dir = nil
    end
  end
end
