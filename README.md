# TcgCsv

Ruby gem for the [tcgcsv.com](https://tcgcsv.com/) trading card API. Fetch categories, sets, products, and prices for **80+ trading card games** including Pokemon, Magic: The Gathering, Yu-Gi-Oh!, and more.

No API key required.

## Installation

```ruby
gem "tcg_csv"
```

## Quick Start

```ruby
require "tcg_csv"

# List all trading card games
TcgCsv.categories
# => [#<TcgCsv::Category id=1 name="Magic: The Gathering">, ...]

# Find a game by name
pokemon = TcgCsv.category("Pokemon")

# Browse sets
sets = pokemon.groups
base_set = pokemon.group("Base Set")

# Get cards with prices
cards = base_set.products_with_prices
cards.first.name          # => "Charizard"
cards.first.market_price  # => 350.00
cards.first.rarity        # => "Holo Rare"
```

## API

### Client

```ruby
client = TcgCsv::Client.new          # with caching (default)
client = TcgCsv::Client.new(cache: false)  # no caching

# Or use module-level methods (shared client)
TcgCsv.categories
TcgCsv.category("Pokemon")
```

### Categories

```ruby
# All categories
cats = client.categories

# Find by name (case-insensitive partial match) or ID
client.category("pokemon")
client.category("magic")
client.category(3)

# Category fields
cat.id             # => 3
cat.name           # => "Pokemon"
cat.display_name   # => "Pokemon"
cat.popularity     # => 5000000
cat.scannable      # => true
```

### Groups (Sets)

```ruby
# All sets in a category
sets = client.groups(3)
sets = pokemon.groups

# Find a specific set
set = client.group(3, "Silver Tempest")
set = client.group(3, 3170)

# Group fields
set.id             # => 3170
set.name           # => "Silver Tempest"
set.abbreviation   # => "SIT"
set.published_on   # => "2022-11-11T00:00:00"
set.supplemental?  # => false
```

### Products (Cards, Packs, Boxes)

```ruby
# All products in a set
products = client.products(3, 3170)
products = set.products

# Product fields
card.id           # => 451396
card.name         # => "Lugia VSTAR"
card.image_url    # => "https://..."
card.presale?     # => false

# Card-specific data (from extendedData)
card.rarity       # => "Secret Rare"
card.hp           # => "280"
card.card_type    # => "Pokemon"
card.stage        # => "VSTAR"
card.attack_1     # => "Tempest Dive (220)"
card.attack_2     # => nil
card.weakness     # => "Lightning"
card.resistance   # => "Fighting"
card.retreat_cost # => "2"
card.card_text    # => "Tempest Dive does big damage."
card.number       # => "202"
card.upc          # => nil

# Generic extended data access
card["Rarity"]         # => "Secret Rare"
card.extended_fields   # => ["Number", "Rarity", "Card Type", ...]
```

### Prices

```ruby
# Raw price data
prices = client.prices(3, 3170)
prices = set.prices

# Price fields
price.product_id      # => 451396
price.low_price       # => 15.00
price.mid_price       # => 22.50
price.high_price      # => 45.00
price.market_price    # => 20.99
price.direct_low_price # => 18.50
price.sub_type_name   # => "Holofoil"
price.spread          # => 30.00
price.direct?         # => true
```

### Products + Prices (Merged)

```ruby
# Products with prices merged in
cards = client.products_with_prices(3, 3170)
cards = set.products_with_prices

card.market_price                    # => 20.99
card.market_price(sub_type: "Holofoil")  # => 20.99
card.low_price                       # => 15.00
card.high_price                      # => 45.00
card.price_variants                  # => ["Holofoil"]
```

### Search

```ruby
# Search by name (requires category)
client.search("Charizard", category: "Pokemon", group: "Base Set")
client.search("Black Lotus", category: 1, group: 15)

# Filter by rarity
client.search("Lugia", category: "Pokemon", group: "Silver Tempest", rarity: "Secret")

# Filter by price range (enables price merging)
client.search("Pikachu", category: "Pokemon", group: "Base Set",
              include_prices: true, min_price: 5.0, max_price: 100.0)

# Search from a category or group object
pokemon.search("Charizard", group: "Base Set")
set.search("Lugia")
```

### Convenience Methods

```ruby
# Top N most expensive cards in a set
set.top_cards(limit: 10)
set.top_cards(limit: 5, sub_type: "Holofoil")

# Cards by rarity
set.by_rarity("Secret Rare")
set.by_rarity("ultra rare")  # case-insensitive
```

### Caching

All API responses are persisted to disk at `~/.tcg_csv/cache/` so you only hit the website once.

**Static data** (categories, groups, products) is cached **forever** — this data rarely changes.
**Price data** expires after **24 hours** by default since prices fluctuate.

```ruby
# Default: file cache at ~/.tcg_csv/cache, 24h price TTL
client = TcgCsv::Client.new

# Custom cache directory
client = TcgCsv::Client.new(cache_dir: "/tmp/tcg_cache")

# Custom price TTL (1 hour)
client = TcgCsv::Client.new(price_ttl: 3600)

# No caching (always hits the API)
client = TcgCsv::Client.new(cache: false)

# Cache survives across sessions — a new client reuses existing cache
client1 = TcgCsv::Client.new
client1.categories  # fetches from API

client2 = TcgCsv::Client.new
client2.categories  # served from disk, no HTTP request

# Cache management
client.clear_prices!  # wipe only price data (re-fetches fresh prices)
client.clear_cache!   # wipe everything

# Inspect the cache
client.cache.count    # => 5
client.cache.size     # => 234567  (bytes)
client.cache.entries  # => [{ path: "/tcgplayer/categories", age: 3600, type: :static }, ...]
```

## Data Hierarchy

```
Category (Pokemon, Magic, Yu-Gi-Oh!, ...)
  └── Group / Set (Base Set, Silver Tempest, ...)
        ├── Products (cards, packs, boxes)
        └── Prices (linked by productId)
```

## License

MIT
