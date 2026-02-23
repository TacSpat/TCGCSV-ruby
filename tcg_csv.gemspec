# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'tcg_csv'
  spec.version       = '1.0.0'
  spec.authors       = ['Juan']
  spec.summary       = 'Ruby client for the TCGCSV trading card API'
  spec.description   = 'Fetch trading card categories, sets, products, and prices from tcgcsv.com. ' \
                       'Supports Pokemon, Magic: The Gathering, Yu-Gi-Oh!, and 80+ other TCGs.'
  spec.homepage      = 'https://github.com/TacSpat/TCGCSV-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.files         = Dir['lib/**/*.rb'] + ['README.md', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency 'net-http', '~> 0.4'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
