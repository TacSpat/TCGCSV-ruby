# frozen_string_literal: true

module TcgCsv
  class Client
    attr_reader :cache

    # Create a new client.
    #
    #   TcgCsv::Client.new                                  # file cache at ~/.tcg_csv/cache
    #   TcgCsv::Client.new(cache: false)                    # no caching at all
    #   TcgCsv::Client.new(cache_dir: "/tmp/tcg")           # custom cache directory
    #   TcgCsv::Client.new(price_ttl: 3600)                 # prices expire after 1 hour
    #
    # Categories, groups, and products are cached forever (static data).
    # Prices are cached for 24 hours by default.
    #
    def initialize(cache: true, cache_dir: nil, price_ttl: nil)
      @use_cache = cache
      if @use_cache
        opts = {}
        opts[:dir] = cache_dir if cache_dir
        opts[:price_ttl] = price_ttl if price_ttl
        @cache = FileCache.new(**opts)
      else
        @cache = {}
      end
    end

    # ── Categories ──────────────────────────────────────────────

    # Fetch all trading card game categories (Pokemon, Magic, Yu-Gi-Oh!, etc.)
    def categories
      data = get('/tcgplayer/categories')
      data['results'].map { |r| Category.new(r, self) }
    end

    # Find a single category by ID (Integer) or name (String, case-insensitive partial match)
    def category(name_or_id)
      return categories.find { |c| c.id == name_or_id } if name_or_id.is_a?(Integer)

      find_category_by_name(name_or_id.to_s.downcase)
    end

    # ── Groups (Sets) ───────────────────────────────────────────

    # Fetch all groups/sets for a category
    def groups(category_id)
      data = get("/tcgplayer/#{category_id}/groups")
      data['results'].map { |r| Group.new(r, self) }
    end

    # Find a specific group by name within a category
    def group(category_id, name_or_id)
      if name_or_id.is_a?(Integer)
        groups(category_id).find { |g| g.id == name_or_id }
      else
        pattern = name_or_id.to_s.downcase
        all = groups(category_id)
        all.find { |g| g.name.downcase == pattern } ||
          all.find { |g| g.name.downcase.include?(pattern) }
      end
    end

    # ── Products ────────────────────────────────────────────────

    # Fetch all products in a group (cards, boxes, packs, etc.)
    def products(category_id, group_id)
      data = get("/tcgplayer/#{category_id}/#{group_id}/products")
      data['results'].map { |r| Product.new(r, self) }
    end

    # ── Prices ──────────────────────────────────────────────────

    # Fetch all prices for products in a group
    def prices(category_id, group_id)
      data = get("/tcgplayer/#{category_id}/#{group_id}/prices")
      data['results'].map { |r| Price.new(r) }
    end

    # ── Combined: Products with Prices ──────────────────────────

    # Fetch products and merge price data into each product
    def products_with_prices(category_id, group_id)
      prods = products(category_id, group_id)
      price_list = prices(category_id, group_id)
      price_map = price_list.group_by(&:product_id)

      prods.each do |prod|
        prod.prices = price_map[prod.id] || []
      end

      prods
    end

    # ── Search ──────────────────────────────────────────────────

    # Search for products by name across one or more categories/groups.
    #
    #   client.search("Charizard", category: "Pokemon")
    #   client.search("Black Lotus", category: 1, group: 15)
    #   client.search("Lugia", category: "Pokemon", group: "Silver Tempest", include_prices: true)
    #
    # Options:
    #   category:       category name (String) or ID (Integer) — required
    #   group:          group name (String) or ID (Integer) — optional, searches all groups if omitted
    #   include_prices: merge price data into results (default: false)
    #   rarity:         filter by rarity (e.g. "Rare Holo V")
    #   min_price:      minimum market price filter
    #   max_price:      maximum market price filter
    def search(query, **opts)
      Search.new(self, query, **opts).results
    end

    # ── Single Card Lookup ───────────────────────────────────────

    # Find a single card by name and return it with prices loaded.
    #
    #   client.find_card("Charizard", category: "Pokemon", group: "Base Set")
    #   client.find_card("Lugia VSTAR", category: 3, group: 3170)
    #
    def find_card(name, category:, group:)
      cat_id = resolve_id(category, :category)
      grp_id = resolve_id(group, :group, cat_id)
      pattern = name.downcase
      products_with_prices(cat_id, grp_id).find { |p| p.name.downcase.include?(pattern) }
    end

    # Find ALL cards matching a name with prices loaded.
    #
    #   client.find_cards("Pikachu", category: "Pokemon", group: "Base Set")
    #   # => [Pikachu, Pikachu (Full Art), ...]
    #
    def find_cards(name, category:, group:)
      cat_id = resolve_id(category, :category)
      grp_id = resolve_id(group, :group, cat_id)
      pattern = name.downcase
      products_with_prices(cat_id, grp_id).select { |p| p.name.downcase.include?(pattern) }
    end

    # Get a quick price hash for a card.
    #
    #   client.card_price("Charizard", category: "Pokemon", group: "Base Set")
    #   # => { "Holofoil" => { low: 200.0, mid: 350.0, high: 500.0, market: 345.00, direct_low: nil } }
    #
    #   client.card_price("Lugia VSTAR", category: 3, group: 3170)
    #   # => { "Holofoil" => { low: 15.0, mid: 22.5, high: 45.0, market: 20.99, direct_low: 18.50 } }
    #
    def card_price(name, category:, group:)
      card = find_card(name, category: category, group: group)
      raise NotFoundError, "Card not found: #{name}" unless card

      card.price_summary
    end

    # ── Convenience ─────────────────────────────────────────────

    # Get the top N most expensive cards in a set
    def top_cards(category_id, group_id, limit: 10, sub_type: nil)
      items = products_with_prices(category_id, group_id)

      items.select! { |p| p.prices.any? }
      items.sort_by! do |p|
        relevant = sub_type ? p.prices.select { |pr| pr.sub_type_name.downcase == sub_type.downcase } : p.prices
        -(relevant.map(&:market_price).compact.max || 0)
      end

      items.first(limit)
    end

    # List all cards of a given rarity in a set
    def by_rarity(category_id, group_id, rarity)
      products(category_id, group_id).select do |p|
        p.rarity&.downcase&.include?(rarity.downcase)
      end
    end

    # Pre-fetch and cache an entire category (all groups, products, and prices).
    # After this, all lookups for that category are instant from disk.
    #
    #   client.prefetch("Pokemon")                    # cache everything
    #   client.prefetch("Pokemon", groups: ["Base Set", "Silver Tempest"])  # specific sets only
    #
    def prefetch(category_name_or_id, groups: nil)
      cat = category(category_name_or_id)
      raise NotFoundError, "Category not found: #{category_name_or_id}" unless cat

      target_groups = if groups
                        groups.map { |g| group(cat.id, g) }.compact
                      else
                        self.groups(cat.id)
                      end

      target_groups.each do |grp|
        products(cat.id, grp.id)
        prices(cat.id, grp.id)
      end

      { category: cat.name, groups_cached: target_groups.length }
    end

    # Wipe the entire cache (static + prices)
    def clear_cache!
      @cache.clear
    end

    # Wipe only cached price data (keeps categories, groups, products)
    def clear_prices!
      @cache.clear_prices! if @cache.respond_to?(:clear_prices!)
    end

    private

    def find_category_by_name(pattern)
      all = categories
      all.find { |c| c.name.downcase == pattern || c.display_name.downcase == pattern } ||
        all.find { |c| c.name.downcase.include?(pattern) || c.display_name.downcase.include?(pattern) }
    end

    def resolve_id(name_or_id, type, parent_id = nil)
      return name_or_id if name_or_id.is_a?(Integer)

      case type
      when :category
        cat = category(name_or_id.to_s)
        raise NotFoundError, "Category not found: #{name_or_id}" unless cat

        cat.id
      when :group
        grp = group(parent_id, name_or_id.to_s)
        raise NotFoundError, "Group not found: #{name_or_id}" unless grp

        grp.id
      end
    end

    def get(path)
      return @cache[path] if @use_cache && @cache.key?(path)

      uri = URI("#{BASE_URL}#{path}")
      response = Net::HTTP.get_response(uri)

      case response
      when Net::HTTPSuccess
        data = JSON.parse(response.body)
        @cache[path] = data if @use_cache
        data
      when Net::HTTPNotFound
        raise NotFoundError, "Resource not found: #{path}"
      else
        raise ApiError, "API request failed (#{response.code}): #{path}"
      end
    end
  end
end
