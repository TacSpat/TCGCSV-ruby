# frozen_string_literal: true

module TcgCsv
  class Product
    attr_reader :id, :name, :clean_name, :image_url, :category_id, :group_id,
                :url, :modified_on, :image_count, :extended_data, :presale_info
    attr_accessor :prices

    def initialize(data, client = nil)
      @client       = client
      @id           = data['productId']
      @name         = data['name']
      @clean_name   = data['cleanName']
      @image_url    = data['imageUrl']
      @category_id  = data['categoryId']
      @group_id     = data['groupId']
      @url          = data['url']
      @modified_on  = data['modifiedOn']
      @image_count  = data['imageCount']
      @presale_info = data['presaleInfo']
      @extended_data = parse_extended_data(data['extendedData'] || [])
      @prices = []
    end

    # ── Extended Data Accessors ─────────────────────────────────
    # These dynamically pull from the extendedData hash

    def rarity
      @extended_data['Rarity']
    end

    def number
      @extended_data['Number']
    end

    def card_type
      @extended_data['Card Type']
    end

    def hp
      @extended_data['HP']
    end

    def stage
      @extended_data['Stage']
    end

    def card_text
      @extended_data['CardText']
    end

    def attack_1
      @extended_data['Attack 1']
    end

    def attack_2
      @extended_data['Attack 2']
    end

    def attack_3
      @extended_data['Attack 3']
    end

    def weakness
      @extended_data['Weakness']
    end

    def resistance
      @extended_data['Resistance']
    end

    def retreat_cost
      @extended_data['RetreatCost']
    end

    def upc
      @extended_data['UPC']
    end

    def description
      @extended_data['Description']
    end

    # Generic access to any extended data field
    def [](field_name)
      @extended_data[field_name]
    end

    # All available extended data field names for this product
    def extended_fields
      @extended_data.keys
    end

    # ── Price Helpers ───────────────────────────────────────────

    # Lazy-load prices from the API if they haven't been loaded yet.
    # Useful when you have a product from `products` (no prices) and want to
    # get its pricing without fetching the entire group upfront.
    #
    #   card = set.products.find { |p| p.name =~ /Charizard/ }
    #   card.fetch_prices!
    #   card.market_price  # => 350.00
    #
    def fetch_prices!
      return self if @prices.any?
      raise Error, 'No client available to fetch prices' unless @client

      all_prices = @client.prices(@category_id, @group_id)
      @prices = all_prices.select { |p| p.product_id == @id }
      self
    end

    # Returns true if price data has been loaded for this product
    def prices_loaded?
      @prices.any?
    end

    # Full price summary as a hash, loading prices if needed
    #
    #   card.price_summary
    #   # => { "Holofoil" => { low: 15.0, mid: 22.5, high: 45.0, market: 20.99 },
    #   #      "Reverse Holofoil" => { low: 5.0, mid: 8.0, high: 12.0, market: 7.25 } }
    #
    def price_summary
      fetch_prices! unless prices_loaded?
      @prices.each_with_object({}) do |p, hash|
        hash[p.sub_type_name] = {
          low: p.low_price,
          mid: p.mid_price,
          high: p.high_price,
          market: p.market_price,
          direct_low: p.direct_low_price
        }
      end
    end

    # Market price for a given sub-type (default: first available)
    def market_price(sub_type: nil)
      price_for(sub_type)&.market_price
    end

    # Low price for a given sub-type
    def low_price(sub_type: nil)
      price_for(sub_type)&.low_price
    end

    # Mid price for a given sub-type
    def mid_price(sub_type: nil)
      price_for(sub_type)&.mid_price
    end

    # High price for a given sub-type
    def high_price(sub_type: nil)
      price_for(sub_type)&.high_price
    end

    # All sub-types that have prices (e.g. "Normal", "Holofoil", "Reverse Holofoil")
    def price_variants
      @prices.map(&:sub_type_name)
    end

    def presale?
      @presale_info && @presale_info['isPresale']
    end

    def to_s
      name
    end

    def inspect
      price_str = @prices.any? ? " market_price=#{market_price}" : ''
      "#<TcgCsv::Product id=#{@id} name=#{@name.inspect}#{price_str}>"
    end

    private

    def parse_extended_data(entries)
      entries.each_with_object({}) do |entry, hash|
        hash[entry['name']] = entry['value']
      end
    end

    def price_for(sub_type)
      if sub_type
        @prices.find { |p| p.sub_type_name.downcase == sub_type.downcase }
      else
        @prices.first
      end
    end
  end
end
