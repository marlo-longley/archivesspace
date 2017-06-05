require_relative 'oai_utils'

class OAIMODSMapper

  def map_oai_record(record)
    jsonmodel = record.jsonmodel_record
    result = Nokogiri::XML::Builder.new do |xml|

      xml.mods('xmlns' => 'http://www.loc.gov/mods/v3',
               'xmlns:xlink' => 'http://www.w3.org/1999/xlink',
               'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 https://www.loc.gov/standards/mods/v3/mods-3-6.xsd') do

        # Repo name -> location/physicalLocation
        xml.location {
          xml.physicalLocation(jsonmodel['repository']['_resolved']['name'])
        }

        # Identifier -> identifier
        merged_identifier = ([jsonmodel['component_id']] + jsonmodel['ancestors'].map {|a| a['_resolved']['component_id']}).compact.reverse.join(".")
        unless merged_identifier.empty?
          xml.identifier(merged_identifier)
        end

        # Creator -> name/namePart
        Array(jsonmodel['linked_agents']).each do |link|
          if link['role'] == 'creator'
            xml.name { xml.namePart(link['_resolved']['title']) }
          end
        end

        # Title -> titleInfo/title
        xml.title(OAIUtils.strip_mixed_content(jsonmodel['display_string']))

        # Dates -> originInfo/dateCreated
        Array(jsonmodel['dates']).each do |date|
          next unless date['label'] == 'creation'

          date_str = if date['expression']
                       date['expression']
                     else
                       [date['begin'], date['end']].compact.join(' -- ')
                     end

          xml.originInfo { xml.dateCreated(date_str) }
        end

        # Extent -> physicalDescription/extent
        Array(jsonmodel['extents']).each do |extent|
          extent_str = [extent['number'] + ' ' + extent['extent_type'], extent['container_summary']].compact.join('; ')
          xml.physicalDescription { xml.extent(extent_str) }
        end

        # Dimensions notes -> physicalDescription/extent
        Array(jsonmodel['notes'])
          .select {|note| ['dimensions'].include?(note['type'])}
          .each do |note|
          OAIUtils.extract_published_note_content(note).each do |content|
            xml.physicalDescription { xml.extent(content) }
          end
        end

        # Language -> language/languageTerm
        if jsonmodel['language']
          xml.language { xml.languageTerm(jsonmodel['language']) }
        end

        # Abstract note -> abstract
        Array(jsonmodel['notes'])
          .each do |note|
          OAIUtils.extract_published_note_content(note).each do |content|
            case note['type']
            when 'bioghist'
              xml.note({'type' => 'biographical'}, content)
            when 'scopecontent', 'abstract'
              xml.abstract(content)
            when 'odd'
              xml.note(content)
            when 'arrangement'
              xml.note({'type' => 'organization'}, content)
            when 'altformavail'
              xml.note({'type' => 'additionalform'}, content)
            when 'altformavail'
              xml.note({'type' => 'additionalform'}, content)
            when 'accessrestrict'
              xml.accessCondition({'type' => 'restrictionOnAccess'}, content)
            when 'userestrict'
              xml.accessCondition({'type' => 'useAndReproduction'}, content)
            when 'userestrict'
              xml.accessCondition({'type' => 'useAndReproduction'}, content)
            when 'accruals'
              xml.note({'type' => 'accrual method'}, content)
            when 'acqinfo'
              xml.note({'type' => 'acquisition'}, content)
            when 'appraisal'
              xml.note({'type' => 'action'}, content)
            when 'bibliography'
              xml.note({'type' => 'citation'}, content)
            when 'custodhist'
              xml.note({'type' => 'ownership'}, content)
            when 'originalsloc'
              xml.note({'type' => 'originallocation'}, content)
            when 'fileplan'
              xml.note({'type' => 'fileplan'}, content)
            when 'otherfindaid'
              xml.note({'type' => 'otherfindaid'}, content)
            when 'phystech'
              xml.note({'type' => 'systemdetails'}, content)
            when 'prefercite'
              xml.note({'type' => 'preferredcitation'}, content)
            when 'processinfo'
              xml.note({'type' => 'action'}, content)
            when 'relatedmaterial'
              xml.note({'type' => 'relatedmaterial'}, content)
            when 'separatedmaterial'
              xml.note({'type' => 'separatedmaterial'}, content)
            end
          end
        end

        # Subjects
        Array(jsonmodel['subjects']).each do |subject|
          term_types = subject['_resolved']['terms'].map {|term| term['term_type']}

          if term_types.include?('topical')
            xml.subject { xml.topic(subject['_resolved']['title']) }
          elsif term_types.include?('geographic')
            xml.subject { xml.geographic(subject['_resolved']['title']) }
          elsif term_types.include?('genre_form')
            xml.subject { xml.genre(subject['_resolved']['title']) }
          else
            xml.subject(subject['_resolved']['title'])
          end
        end


        # Non-creator agents
        Array(jsonmodel['linked_agents']).each do |link|
          next if link['role'] == 'creator'

          case link['_resolved']['agent_type']
          when 'agent_person', 'agent_family'
            xml.subject { xml.name({'type' => 'personal'}, link['_resolved']['title']) }
          when 'agent_corporate_entity'
            xml.subject { xml.name({'type' => 'corporate'}, link['_resolved']['title']) }
          end
        end
      end
    end

    result.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
  end

end
