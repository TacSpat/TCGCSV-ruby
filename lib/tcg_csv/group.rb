# frozen_string_literal: true

module TcgCsv
  class Group
    attr_reader :id, :name, :abbreviation, :supplemental,
                :published_on, :modified_on, :category_id

    def initialize(data, client = nil)
      @client        = client
      @id            = data['groupId']
      @name          = data['name']
      @abbreviation  = data['abbreviation']
      @supplemental  = data['isSupplemental']
      @published_on  = data['publishedOn']
      @modified_on   = data['modifiedOn']
      @category_id   = data['categoryId']
    end

    # Fetch all products (cards, packs, boxes) in this set
    def products
      @client.products(@category_id, @id)
    end

    # Fetch all price data for this set
    def prices
      @client.prices(@category_id, @id)
    end

    # Fetch products with prices merged in
    def products_with_prices
      @client.products_with_prices(@category_id, @id)
    end

    # Get the N most expensive cards in this set
    def top_cards(limit: 10, sub_type: nil)
      @client.top_cards(@category_id, @id, limit: limit, sub_type: sub_type)
    end

    # List all cards of a given rarity
    def by_rarity(rarity)
      @client.by_rarity(@category_id, @id, rarity)
    end

    # Find a single card by name (partial, case-insensitive) with prices loaded.
    # Returns nil if not found.
    #
    #   set.find_card("Charizard")
    #   set.find_card("Lugia VSTAR")
    #
    def find_card(name)
      pattern = name.downcase
      prods = @client.products_with_prices(@category_id, @id)
      prods.find { |p| p.name.downcase.include?(pattern) }
    end

    # Find ALL cards matching a name (partial, case-insensitive) with prices loaded.
    #
    #   set.find_cards("Lugia")
    #   # => [Lugia V, Lugia VSTAR, Lugia V (Full Art), ...]
    #
    def find_cards(name)
      pattern = name.downcase
      prods = @client.products_with_prices(@category_id, @id)
      prods.select { |p| p.name.downcase.include?(pattern) }
    end

    # Search for products by name in this set
    def search(query, **opts)
      @client.search(query, category: @category_id, group: @id, **opts)
    end

    def supplemental?
      @supplemental
    end

    def to_s
      name
    end

    def inspect
      "#<TcgCsv::Group id=#{@id} name=#{@name.inspect} category_id=#{@category_id}>"
    end
  end
end
