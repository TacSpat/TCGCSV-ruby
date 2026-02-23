# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TcgCsv do
  let(:client) { TcgCsv::Client.new(cache_dir: test_cache_dir) }

  before do
    stub_api('/tcgplayer/categories', 'categories')
    stub_api('/tcgplayer/3/groups', 'groups')
    stub_api('/tcgplayer/3/3170/products', 'products')
    stub_api('/tcgplayer/3/3170/prices', 'prices')
  end

  describe 'Client#categories' do
    it 'returns all categories' do
      cats = client.categories
      expect(cats.length).to eq(3)
      expect(cats.map(&:name)).to include('Pokemon', 'Magic', 'YuGiOh')
    end
  end

  describe 'Client#category' do
    it 'finds a category by ID' do
      cat = client.category(3)
      expect(cat.name).to eq('Pokemon')
      expect(cat.id).to eq(3)
    end

    it 'finds a category by name (case-insensitive)' do
      cat = client.category('pokemon')
      expect(cat.name).to eq('Pokemon')
    end

    it 'finds a category by partial name' do
      cat = client.category('magic')
      expect(cat.display_name).to eq('Magic: The Gathering')
    end
  end

  describe 'Client#groups' do
    it 'returns groups for a category' do
      groups = client.groups(3)
      expect(groups.length).to eq(2)
      expect(groups.first.name).to eq('Silver Tempest')
    end
  end

  describe 'Client#group' do
    it 'finds a group by name' do
      group = client.group(3, 'Silver')
      expect(group.name).to eq('Silver Tempest')
      expect(group.abbreviation).to eq('SIT')
    end

    it 'finds a group by ID' do
      group = client.group(3, 604)
      expect(group.name).to eq('Base Set')
    end
  end

  describe 'Client#products' do
    it 'returns products with extended data' do
      products = client.products(3, 3170)
      expect(products.length).to eq(3)

      lugia_vstar = products.find { |p| p.name == 'Lugia VSTAR' }
      expect(lugia_vstar.rarity).to eq('Secret Rare')
      expect(lugia_vstar.hp).to eq('280')
      expect(lugia_vstar.card_type).to eq('Pokemon')
      expect(lugia_vstar.attack_1).to eq('Tempest Dive (220)')
      expect(lugia_vstar.weakness).to eq('Lightning')
      expect(lugia_vstar.number).to eq('202')
    end

    it 'provides bracket access for extended data' do
      products = client.products(3, 3170)
      lugia = products.first
      expect(lugia['Rarity']).to eq('Secret Rare')
      expect(lugia['HP']).to eq('280')
    end

    it 'lists extended field names' do
      products = client.products(3, 3170)
      fields = products.first.extended_fields
      expect(fields).to include('Rarity', 'HP', 'Card Type', 'Attack 1')
    end
  end

  describe 'Client#prices' do
    it 'returns price data' do
      prices = client.prices(3, 3170)
      expect(prices.length).to eq(4)

      holofoil = prices.find { |p| p.product_id == 451_396 }
      expect(holofoil.market_price).to eq(20.99)
      expect(holofoil.low_price).to eq(15.0)
      expect(holofoil.sub_type_name).to eq('Holofoil')
      expect(holofoil.direct?).to be true
    end

    it 'calculates spread' do
      prices = client.prices(3, 3170)
      holofoil = prices.find { |p| p.product_id == 451_396 }
      expect(holofoil.spread).to eq(30.0)
    end
  end

  describe 'Client#products_with_prices' do
    it 'merges prices into products' do
      products = client.products_with_prices(3, 3170)

      lugia_vstar = products.find { |p| p.name == 'Lugia VSTAR' }
      expect(lugia_vstar.prices.length).to eq(1)
      expect(lugia_vstar.market_price).to eq(20.99)

      lugia_v = products.find { |p| p.name == 'Lugia V' }
      expect(lugia_v.prices.length).to eq(2)
      expect(lugia_v.price_variants).to contain_exactly('Normal', 'Holofoil')
      expect(lugia_v.market_price(sub_type: 'Holofoil')).to eq(7.25)
    end
  end

  describe 'Client#top_cards' do
    it 'returns cards sorted by price descending' do
      top = client.top_cards(3, 3170, limit: 3)
      expect(top.first.name).to eq('Lugia VSTAR')
      expect(top.length).to eq(3)
    end

    it 'filters by sub_type' do
      top = client.top_cards(3, 3170, limit: 10, sub_type: 'Holofoil')
      expect(top.first.name).to eq('Lugia VSTAR')
    end
  end

  describe 'Client#by_rarity' do
    it 'returns cards matching rarity' do
      cards = client.by_rarity(3, 3170, 'Secret')
      expect(cards.length).to eq(1)
      expect(cards.first.name).to eq('Lugia VSTAR')
    end

    it 'is case-insensitive' do
      cards = client.by_rarity(3, 3170, 'ultra rare')
      expect(cards.length).to eq(1)
      expect(cards.first.name).to eq('Lugia V')
    end
  end

  describe 'Client#search' do
    it 'searches products by name within a category and group' do
      results = client.search('Lugia', category: 3, group: 3170)
      expect(results.length).to eq(2)
      expect(results.map(&:name)).to contain_exactly('Lugia VSTAR', 'Lugia V')
    end

    it 'filters by rarity' do
      results = client.search('Lugia', category: 3, group: 3170, rarity: 'Secret')
      expect(results.length).to eq(1)
      expect(results.first.name).to eq('Lugia VSTAR')
    end

    it 'filters by price range' do
      results = client.search('Lugia', category: 3, group: 3170, include_prices: true, min_price: 10.0)
      expect(results.length).to eq(1)
      expect(results.first.name).to eq('Lugia VSTAR')
    end

    it 'searches by category name' do
      results = client.search('Lugia', category: 'Pokemon', group: 3170)
      expect(results.length).to eq(2)
    end

    it 'searches by group name' do
      results = client.search('Lugia', category: 3, group: 'Silver Tempest')
      expect(results.length).to eq(2)
    end

    it 'raises without a category' do
      expect { client.search('Lugia') }.to raise_error(ArgumentError)
    end
  end

  describe 'Category navigation' do
    it 'navigates from category to groups to products' do
      cat = client.category('Pokemon')
      groups = cat.groups
      expect(groups.length).to eq(2)

      set = groups.first
      products = set.products
      expect(products.length).to eq(3)
    end

    it 'supports search from a category' do
      cat = client.category('Pokemon')
      results = cat.search('Lugia', group: 3170)
      expect(results.length).to eq(2)
    end
  end

  describe 'Group navigation' do
    it 'navigates from group to products with prices' do
      group = client.group(3, 'Silver')
      products = group.products_with_prices
      expect(products.first.prices).not_to be_empty
    end

    it 'gets top cards from a group' do
      group = client.group(3, 'Silver')
      top = group.top_cards(limit: 2)
      expect(top.length).to eq(2)
      expect(top.first.market_price).to be > top.last.market_price
    end
  end

  describe 'Client#find_card' do
    it 'finds a single card by name with prices' do
      card = client.find_card('Lugia VSTAR', category: 3, group: 3170)
      expect(card.name).to eq('Lugia VSTAR')
      expect(card.market_price).to eq(20.99)
      expect(card.prices).not_to be_empty
    end

    it 'finds by partial name (case-insensitive)' do
      card = client.find_card('lugia v', category: 3, group: 3170)
      expect(card).not_to be_nil
    end

    it 'resolves category and group by name' do
      card = client.find_card('Lugia VSTAR', category: 'Pokemon', group: 'Silver Tempest')
      expect(card.name).to eq('Lugia VSTAR')
      expect(card.market_price).to eq(20.99)
    end

    it 'returns nil when not found' do
      card = client.find_card('Mewtwo', category: 3, group: 3170)
      expect(card).to be_nil
    end
  end

  describe 'Client#find_cards' do
    it 'finds all matching cards with prices' do
      cards = client.find_cards('Lugia', category: 3, group: 3170)
      expect(cards.length).to eq(2)
      expect(cards.map(&:name)).to contain_exactly('Lugia VSTAR', 'Lugia V')
      cards.each { |c| expect(c.prices).not_to be_empty }
    end
  end

  describe 'Client#card_price' do
    it 'returns a price summary hash' do
      summary = client.card_price('Lugia VSTAR', category: 3, group: 3170)
      expect(summary).to be_a(Hash)
      expect(summary['Holofoil'][:market]).to eq(20.99)
      expect(summary['Holofoil'][:low]).to eq(15.0)
      expect(summary['Holofoil'][:high]).to eq(45.0)
      expect(summary['Holofoil'][:direct_low]).to eq(18.50)
    end

    it 'returns multiple variants when they exist' do
      # Use find_cards to get the exact one, since "Lugia V" partial-matches "Lugia VSTAR" first
      cards = client.find_cards('Lugia', category: 3, group: 3170)
      lugia_v = cards.find { |c| c.name == 'Lugia V' }
      summary = lugia_v.price_summary
      expect(summary.keys).to contain_exactly('Normal', 'Holofoil')
      expect(summary['Normal'][:market]).to eq(3.75)
      expect(summary['Holofoil'][:market]).to eq(7.25)
    end

    it 'raises when card is not found' do
      expect do
        client.card_price('Mewtwo', category: 3, group: 3170)
      end.to raise_error(TcgCsv::NotFoundError)
    end
  end

  describe 'Product#fetch_prices!' do
    it 'lazy-loads prices for a product' do
      products = client.products(3, 3170)
      lugia = products.find { |p| p.name == 'Lugia VSTAR' }
      expect(lugia.prices).to be_empty
      expect(lugia.prices_loaded?).to be false

      lugia.fetch_prices!
      expect(lugia.prices_loaded?).to be true
      expect(lugia.market_price).to eq(20.99)
    end

    it 'returns self for chaining' do
      products = client.products(3, 3170)
      lugia = products.find { |p| p.name == 'Lugia VSTAR' }
      result = lugia.fetch_prices!
      expect(result).to eq(lugia)
    end

    it 'is a no-op if prices are already loaded' do
      products = client.products_with_prices(3, 3170)
      lugia = products.find { |p| p.name == 'Lugia VSTAR' }
      lugia.fetch_prices!
      # Should not make another API call (would hit cache anyway, but the point is it returns early)
      expect(lugia.market_price).to eq(20.99)
    end
  end

  describe 'Product#price_summary' do
    it 'returns a full price breakdown' do
      products = client.products_with_prices(3, 3170)
      lugia_v = products.find { |p| p.name == 'Lugia V' }
      summary = lugia_v.price_summary

      expect(summary.keys).to contain_exactly('Normal', 'Holofoil')
      expect(summary['Normal']).to eq({ low: 2.0, mid: 4.5, high: 10.0, market: 3.75, direct_low: nil })
      expect(summary['Holofoil']).to eq({ low: 5.0, mid: 8.0, high: 15.0, market: 7.25, direct_low: 6.0 })
    end
  end

  describe 'Group#find_card' do
    it 'finds a card by name within the set' do
      group = client.group(3, 'Silver')
      card = group.find_card('Lugia VSTAR')
      expect(card.name).to eq('Lugia VSTAR')
      expect(card.market_price).to eq(20.99)
    end
  end

  describe 'Group#find_cards' do
    it 'finds all matching cards within the set' do
      group = client.group(3, 'Silver')
      cards = group.find_cards('Lugia')
      expect(cards.length).to eq(2)
    end
  end

  describe 'File-based caching' do
    it 'caches responses to disk — no second HTTP call' do
      client.categories
      client.categories
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/categories').once
    end

    it 'persists across client instances sharing the same cache_dir' do
      client.categories
      client2 = TcgCsv::Client.new(cache_dir: test_cache_dir)
      client2.categories
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/categories').once
    end

    it 'does not cache when cache: false' do
      no_cache = TcgCsv::Client.new(cache: false)
      no_cache.categories
      no_cache.categories
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/categories').twice
    end

    it 'clear_cache! wipes everything and re-fetches' do
      client.categories
      client.clear_cache!
      client.categories
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/categories').twice
    end

    it 'clear_prices! only wipes price data' do
      client.categories
      client.prices(3, 3170)
      client.clear_prices!

      # categories still cached
      client.categories
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/categories').once

      # prices must re-fetch
      client.prices(3, 3170)
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/3/3170/prices').twice
    end

    it 'static data (categories, groups, products) never expires' do
      cache = TcgCsv::FileCache.new(dir: test_cache_dir, price_ttl: 1)
      cache['/tcgplayer/categories'] = { 'test' => true }

      # Simulate age by touching the file to be old
      file = Dir.glob(File.join(test_cache_dir, '*.json')).first
      FileUtils.touch(file, mtime: Time.now - 999_999)

      expect(cache.key?('/tcgplayer/categories')).to be true
    end

    it 'price data expires after the TTL' do
      cache = TcgCsv::FileCache.new(dir: test_cache_dir, price_ttl: 1)
      cache['/tcgplayer/3/3170/prices'] = { 'test' => true }

      # Simulate age past TTL
      file = Dir.glob(File.join(test_cache_dir, '*.json')).first
      FileUtils.touch(file, mtime: Time.now - 10)

      expect(cache.key?('/tcgplayer/3/3170/prices')).to be false
    end

    it 'price data is served when still fresh' do
      cache = TcgCsv::FileCache.new(dir: test_cache_dir, price_ttl: 3600)
      cache['/tcgplayer/3/3170/prices'] = { 'results' => [] }

      expect(cache.key?('/tcgplayer/3/3170/prices')).to be true
      expect(cache['/tcgplayer/3/3170/prices']).to eq({ 'results' => [] })
    end

    it 'supports custom price_ttl on the client' do
      fast_client = TcgCsv::Client.new(cache_dir: test_cache_dir, price_ttl: 1)
      fast_client.prices(3, 3170)

      # Expire the price cache
      Dir.glob(File.join(test_cache_dir, '*.json')).each do |f|
        meta = "#{f}.meta"
        FileUtils.touch(f, mtime: Time.now - 10) if File.exist?(meta) && File.read(meta).include?('prices')
      end

      fast_client.prices(3, 3170)
      expect(WebMock).to have_requested(:get, 'https://tcgcsv.com/tcgplayer/3/3170/prices').twice
    end

    it 'cache.entries lists cached paths with type' do
      client.categories
      client.prices(3, 3170)

      entries = client.cache.entries
      expect(entries.length).to eq(2)

      types = entries.map { |e| e[:type] }
      expect(types).to contain_exactly(:static, :price)
    end

    it 'cache.count and cache.size work' do
      expect(client.cache.count).to eq(0)
      client.categories
      expect(client.cache.count).to eq(1)
      expect(client.cache.size).to be > 0
    end
  end

  describe 'Module-level access' do
    before do
      # Reset the module-level client so it picks up our test stubs
      TcgCsv.instance_variable_set(:@client, TcgCsv::Client.new(cache_dir: test_cache_dir))
    end

    it 'provides module-level convenience methods' do
      cats = TcgCsv.categories
      expect(cats.length).to eq(3)
    end
  end
end
