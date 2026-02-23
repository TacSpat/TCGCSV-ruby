# frozen_string_literal: true

module TcgCsv
  class Category
    attr_reader :id, :name, :display_name, :seo_name, :description,
                :sealed_label, :non_sealed_label, :condition_guide_url,
                :scannable, :popularity, :direct, :modified_on

    def initialize(data, client = nil)
      @client            = client
      @id                = data['categoryId']
      @name              = data['name']
      @display_name      = data['displayName'] || @name
      @seo_name          = data['seoCategoryName']
      @description       = data['categoryDescription']
      @sealed_label      = data['sealedLabel']
      @non_sealed_label  = data['nonSealedLabel']
      @condition_guide_url = data['conditionGuideUrl']
      @scannable         = data['isScannable']
      @popularity        = data['popularity']
      @direct            = data['isDirect']
      @modified_on       = data['modifiedOn']
    end

    # Fetch all groups/sets in this category
    def groups
      @client.groups(@id)
    end

    # Find a group/set by name or ID
    def group(name_or_id)
      @client.group(@id, name_or_id)
    end

    # Search for products within this category
    def search(query, **opts)
      @client.search(query, category: @id, **opts)
    end

    def to_s
      display_name
    end

    def inspect
      "#<TcgCsv::Category id=#{@id} name=#{@display_name.inspect}>"
    end
  end
end
