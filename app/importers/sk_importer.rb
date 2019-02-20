class SkImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(entity_resolver: EntityResolver.new, client: SkClient.new)
    @entity_resolver = entity_resolver
    @client = client
  end

  def process_records(records)
    records.each { |r| process(r) }
  end

  def process(record)
    # Pre-emptive check for pagination in child entities. We've never seen it,
    # but we think it's theoretically possible and we want to know asap if it
    # appears because it will mean we miss data
    if record['PartneriVerejnehoSektora@odata.nextLink']
      Rollbar.error("SK record Id: #{record['Id']} has paginated child entities (PartneriVerejnehoSektora)")
    end
    child_entity = child_entity!(record)
    return if child_entity.nil?

    parent_entities = record['KonecniUzivateliaVyhod']
    # Some parent entity lists are paginated but the pagination links don't
    # work, so we have to request the data from elsewhere
    if record['KonecniUzivateliaVyhod@odata.nextLink']
      Rails.logger.info("[#{self.class.name}] record Id: #{record['Id']} has paginated parent entities (KonecniUzivateliaVyhod)")
      parent_entities = all_parent_entities(record)
    end

    parent_entities.each do |item|
      parent_entity = parent_entity!(item)
      relationship!(child_entity, parent_entity, item)
    end
  end

  private

  def child_entity!(record)
    item = record['PartneriVerejnehoSektora'].find { |p| p['PlatnostDo'].nil? }

    if item.nil?
      Rails.logger.warn("[#{self.class.name}] record Id: #{record['Id']} has no current child entity (PartneriVerejnehoSektora)")
      return
    elsif !slovakian_address?(item['Adresa'])
      Rails.logger.warn("[#{self.class.name}] record Id: #{record['Id']} has a child entity (PartneriVerejnehoSektora) with a non-Slovakian address")
      return
    elsif item['ObchodneMeno'].nil?
      Rails.logger.warn("[#{self.class.name}] record Id: #{record['Id']} has a child entity (PartneriVerejnehoSektora) with no company name (ObchodneMeno)")
      return
    end

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => item['Ico'],
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'sk',
      company_number: item['Ico'],
      name: item['ObchodneMeno'].strip,
      address: address_string(item['Adresa']),
    )
    @entity_resolver.resolve!(entity)

    entity
      .tap(&:upsert)
      .tap(&method(:index_entity))
  end

  def parent_entity!(item)
    attributes = {
      identifiers: [
        {
          'document_id' => document_id,
          'beneficial_owner_id' => item['Id'],
        },
      ],
      type: Entity::Types::NATURAL_PERSON,
      name: name_string(item),
      nationality: country_from_nationality(item).try(:alpha2),
      address: item['Adresa'].presence && address_string(item['Adresa']),
      dob: entity_dob(item['DatumNarodenia']),
    }

    Entity
      .new(attributes)
      .tap(&:upsert)
      .tap(&method(:index_entity))
  end

  def relationship!(child_entity, parent_entity, item)
    attributes = {
      _id: {
        'document_id' => document_id,
        'beneficial_owner_id' => item['Id'],
      },
      source: parent_entity,
      target: child_entity,
      sample_date: Date.parse(item['PlatnostOd']).to_s,
      started_date: Date.parse(item['PlatnostOd']).to_s,
      ended_date: item['PlatnostDo'].presence && Date.parse(item['PlatnostDo']).to_s,
      provenance: {
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    Relationship.new(attributes).upsert
  end

  def slovakian_address?(address)
    address['Psc'].present? && address['Psc'].strip =~ /^\d{3} ?\d{2}$/
  end

  def address_string(address)
    first_line = [address['OrientacneCislo'], address['MenoUlice']].map(&:presence).compact.join(' ')

    [first_line, address['Mesto'], address['Psc']].map(&:presence).compact.map(&:strip).join(', ')
  end

  def name_string(item)
    item.values_at('Meno', 'Priezvisko').map(&:presence).compact.join(' ')
  end

  def country_from_nationality(item)
    ISO3166::Country.find_country_by_number(item['StatnaPrislusnost']['StatistickyKod'])
  end

  def entity_dob(timestamp)
    return unless timestamp
    ISO8601::Date.new(timestamp.split('T')[0])
  end

  def all_parent_entities(record)
    company_record = @client.company_record(record['Id'])
    return [] if company_record.nil?
    company_record['KonecniUzivateliaVyhod']
  end

  def index_entity(entity)
    IndexEntityService.new(entity).index
  end
end
