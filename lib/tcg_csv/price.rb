# frozen_string_literal: true

module TcgCsv
  class Price
    attr_reader :product_id, :low_price, :mid_price, :high_price,
                :market_price, :direct_low_price, :sub_type_name

    def initialize(data)
      @product_id      = data['productId']
      @low_price       = data['lowPrice']
      @mid_price       = data['midPrice']
      @high_price      = data['highPrice']
      @market_price    = data['marketPrice']
      @direct_low_price = data['directLowPrice']
      @sub_type_name = data['subTypeName']
    end

    # Price spread (difference between high and low)
    def spread
      return nil unless @high_price && @low_price

      (@high_price - @low_price).round(2)
    end

    # Is the market price available?
    def market_price?
      !@market_price.nil?
    end

    # Is direct pricing available?
    def direct?
      !@direct_low_price.nil?
    end

    def to_s
      "$#{format('%.2f', @market_price || @mid_price || 0)} (#{@sub_type_name})"
    end

    def inspect
      "#<TcgCsv::Price product_id=#{@product_id} market=$#{@market_price} sub_type=#{@sub_type_name.inspect}>"
    end
  end
end
