# frozen_string_literal: true

require 'fileutils'
require 'digest'
require 'json'

module TcgCsv
  class FileCache
    DEFAULT_DIR = File.join(Dir.home, '.tcg_csv', 'cache')
    PRICE_TTL   = 86_400 # 24 hours — prices change daily
    STATIC_TTL  = nil # categories, groups, products never expire

    attr_reader :dir, :price_ttl

    def initialize(dir: DEFAULT_DIR, price_ttl: PRICE_TTL)
      @dir       = dir
      @price_ttl = price_ttl
      FileUtils.mkdir_p(@dir)
    end

    def key?(path)
      file = cache_file(path)
      return false unless File.exist?(file)

      ttl = ttl_for(path)
      return true if ttl.nil?

      age = Time.now - File.mtime(file)
      if age > ttl
        File.delete(file)
        meta = "#{file}.meta"
        FileUtils.rm_f(meta)
        false
      else
        true
      end
    end

    def [](path)
      file = cache_file(path)
      return nil unless File.exist?(file)

      JSON.parse(File.read(file))
    end

    def []=(path, data)
      file = cache_file(path)
      File.write(file, JSON.generate(data))

      meta_file = "#{file}.meta"
      File.write(meta_file, path)
    end

    def clear
      FileUtils.rm_rf(@dir)
      FileUtils.mkdir_p(@dir)
    end

    # Clear only expired price caches (keeps static data)
    def clear_prices!
      Dir.glob(File.join(@dir, '*.meta')).each do |meta_file|
        path = File.read(meta_file)
        next unless price_path?(path)

        json_file = meta_file.sub(/\.meta$/, '')
        FileUtils.rm_f(json_file)
        File.delete(meta_file)
      end
    end

    # Size of the cache directory in bytes
    def size
      Dir.glob(File.join(@dir, '*')).sum { |f| File.size(f) }
    end

    # Number of cached entries
    def count
      Dir.glob(File.join(@dir, '*.json')).size
    end

    # List cached paths with their age and type
    def entries
      Dir.glob(File.join(@dir, '*.json')).map do |file|
        meta_file = "#{file}.meta"
        path = File.exist?(meta_file) ? File.read(meta_file) : File.basename(file, '.json')
        age = (Time.now - File.mtime(file)).round
        type = price_path?(path) ? :price : :static
        { path: path, age: age, size: File.size(file), type: type }
      end
    end

    private

    def ttl_for(path)
      price_path?(path) ? @price_ttl : STATIC_TTL
    end

    def price_path?(path)
      path.include?('/prices')
    end

    def cache_file(path)
      slug = Digest::SHA256.hexdigest(path)
      File.join(@dir, "#{slug}.json")
    end
  end
end
