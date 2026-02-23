# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative 'tcg_csv/file_cache'
require_relative 'tcg_csv/client'
require_relative 'tcg_csv/category'
require_relative 'tcg_csv/group'
require_relative 'tcg_csv/product'
require_relative 'tcg_csv/price'
require_relative 'tcg_csv/search'

module TcgCsv
  BASE_URL = 'https://tcgcsv.com'

  class Error < StandardError; end
  class NotFoundError < Error; end
  class ApiError < Error; end

  # Quick-access module methods that use a shared default client
  class << self
    def client
      @client ||= Client.new
    end

    def categories
      client.categories
    end

    def category(name_or_id)
      client.category(name_or_id)
    end

    def groups(category_id)
      client.groups(category_id)
    end

    def products(category_id, group_id)
      client.products(category_id, group_id)
    end

    def prices(category_id, group_id)
      client.prices(category_id, group_id)
    end

    def search(query, **opts)
      client.search(query, **opts)
    end

    def find_card(name, **opts)
      client.find_card(name, **opts)
    end

    def find_cards(name, **opts)
      client.find_cards(name, **opts)
    end

    def card_price(name, **opts)
      client.card_price(name, **opts)
    end

    def prefetch(category_name_or_id, **opts)
      client.prefetch(category_name_or_id, **opts)
    end
  end
end
