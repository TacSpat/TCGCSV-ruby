# frozen_string_literal: true

module TcgCsv
  class Search
    def initialize(client, query, **opts)
      @client         = client
      @query          = query.downcase
      @category       = opts[:category]
      @group          = opts[:group]
      @include_prices = opts[:include_prices] || false
      @rarity         = opts[:rarity]
      @min_price      = opts[:min_price]
      @max_price      = opts[:max_price]
    end

    def results
      raise ArgumentError, 'category is required for search' unless @category

      cat_id = resolve_category
      group_ids = resolve_groups(cat_id)

      all_products = group_ids.flat_map do |gid|
        if @include_prices || @min_price || @max_price
          @client.products_with_prices(cat_id, gid)
        else
          @client.products(cat_id, gid)
        end
      end

      filter(all_products)
    end

    private

    def resolve_category
      if @category.is_a?(Integer)
        @category
      else
        cat = @client.category(@category.to_s)
        raise NotFoundError, "Category not found: #{@category}" unless cat

        cat.id
      end
    end

    def resolve_groups(cat_id)
      if @group.nil?
        @client.groups(cat_id).map(&:id)
      elsif @group.is_a?(Integer)
        [@group]
      else
        g = @client.group(cat_id, @group.to_s)
        raise NotFoundError, "Group not found: #{@group}" unless g

        [g.id]
      end
    end

    def filter(products)
      products.select do |p|
        matches_name?(p) && matches_rarity?(p) && matches_price?(p)
      end
    end

    def matches_name?(product)
      product.name.downcase.include?(@query)
    end

    def matches_rarity?(product)
      return true unless @rarity

      product.rarity&.downcase&.include?(@rarity.downcase)
    end

    def matches_price?(product)
      return true unless @min_price || @max_price

      price = product.market_price
      return false if price.nil?

      price_in_range?(price)
    end

    def price_in_range?(price)
      return false if @min_price && price < @min_price
      return false if @max_price && price > @max_price

      true
    end
  end
end
