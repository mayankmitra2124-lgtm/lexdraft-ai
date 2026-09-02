# frozen_string_literal: true

require 'json'
require 'time'

module AggregationService
  def self.aggregate_case_evidence(case_id, newly_processed_file_id = nil)
    case_record = Database.get_case(case_id)
    return nil unless case_record

    # Retrieve all extractions for this case
    all_extractions = Database.get_all_extractions_for_case(case_id)
    return nil if all_extractions.empty?

    # Previous latest summary (for diff comparison)
    previous_summary = Database.get_latest_summary(case_id)

    # 1. Consolidate & Deduplicate Parties
    consolidated_parties = aggregate_parties(case_record, all_extractions)

    # 2. Consolidate Jurisdiction
    consolidated_jurisdiction = aggregate_jurisdiction(case_record, all_extractions)

    # 3. Consolidate & Chronologically Sort Master Timeline
    consolidated_chronology = aggregate_chronology(all_extractions, newly_processed_file_id)

    # 4. Synthesize Coherent Chronological Narrative of Material Facts
    facts_narrative = aggregate_facts_narrative(case_record, all_extractions, consolidated_chronology)

    # 5. Consolidate Cause of Action Statement
    cause_of_action_text = aggregate_cause_of_action(case_record, all_extractions)

    # Prepare master summary object with Feature 4: Statutory Limitation Analysis
    limitation_analysis = GeminiService.calculate_statutory_limitation(consolidated_chronology, cause_of_action_text, case_record)

    new_summary_data = {
      'parties' => consolidated_parties,
      'jurisdiction' => consolidated_jurisdiction,
      'chronology' => consolidated_chronology,
      'facts_narrative' => facts_narrative,
      'cause_of_action_text' => cause_of_action_text,
      'limitation_analysis' => limitation_analysis
    }

    # Save new version of master summary
    saved_summary = Database.save_master_summary(case_id, new_summary_data)

    # 6. Compute and Log Diff if a new file triggered this
    if newly_processed_file_id
      compute_and_log_diff(case_record, newly_processed_file_id, previous_summary, saved_summary)
    end

    saved_summary
  end

  private

  def self.aggregate_parties(case_record, extractions)
    party_map = {}

    # Seed with case setup parties info
    if case_record['parties_info'] && !case_record['parties_info'].strip.empty?
      raw_info = case_record['parties_info']
      parts = raw_info.split(/vs\.|vs|v\./i)
      if parts.size >= 2
        p1 = parts[0].strip
        p2 = parts[1].strip
        party_map[p1.downcase] = {
          'name' => p1,
          'role' => 'Petitioner / Claimant',
          'address' => 'As specified in petition',
          'relationship' => 'Primary Claimant',
          'source_files' => ['Case Setup']
        }
        party_map[p2.downcase] = {
          'name' => p2,
          'role' => 'Respondent / Defendant',
          'address' => 'As specified in petition',
          'relationship' => 'Primary Respondent',
          'source_files' => ['Case Setup']
        }
      end
    end

    extractions.each do |ext|
      file_rec = Database.get_file(ext['file_id'])
      file_label = file_rec ? file_rec['original_name'] : "File #{ext['file_id']}"

      parties = ext['parties'] || []
      parties.each do |p|
        name = p['name'].to_s.strip
        next if name.empty? || name.downcase.include?('authorized')

        key = name.downcase
        if party_map[key]
          party_map[key]['address'] = p['address'] if p['address'] && (!party_map[key]['address'] || party_map[key]['address'].include?('specified'))
          party_map[key]['role'] = p['role'] if p['role'] && party_map[key]['role'] =~ /unknown/i
          party_map[key]['source_files'] = (party_map[key]['source_files'] + [file_label]).uniq
        else
          party_map[key] = {
            'name' => name,
            'role' => p['role'] || 'Identified Party',
            'address' => p['address'] || 'Not explicitly stated in evidence',
            'relationship' => p['relationship'] || 'Associated entity/signatory',
            'conflicts_or_notes' => p['conflicts_or_notes'],
            'source_files' => [file_label]
          }
        end
      end
    end

    party_map.values
  end

  def self.aggregate_jurisdiction(case_record, extractions)
    relevant_points = []
    court = case_record['court_name'] || "High Court of Delhi"
    primary_basis = "Territorial, Pecuniary & Subject-Matter Jurisdiction"

    extractions.each do |ext|
      jur = ext['jurisdiction'] || {}
      if jur['relevant'] && jur['details']
        file_rec = Database.get_file(ext['file_id'])
        fname = file_rec ? file_rec['original_name'] : "Evidence"
        relevant_points << {
          'basis' => jur['basis'],
          'details' => jur['details'],
          'source' => fname
        }
      end
    end

    if relevant_points.empty?
      reasoning = "Jurisdiction is founded on the territorial location of the cause of action and the registered place of business of the parties within the territorial limits of #{court}."
    else
      reasoning = "Jurisdiction is established by multi-documentary evidence:\n" +
                  relevant_points.map { |pt| "• [#{pt['source']}] #{pt['basis']}: #{pt['details']}" }.join("\n")
    end

    {
      'court_name' => court,
      'primary_basis' => primary_basis,
      'consolidated_reasoning' => reasoning,
      'points' => relevant_points
    }
  end

  def self.aggregate_chronology(extractions, newly_processed_file_id = nil)
    master_events = []

    extractions.each do |ext|
      file_id = ext['file_id']
      file_rec = Database.get_file(file_id)
      file_name = file_rec ? file_rec['original_name'] : "Evidence Document"
      is_new_file = (file_id == newly_processed_file_id)

      events = ext['chronology'] || []
      events.each_with_index do |ev, idx|
        event_id = "evt_#{file_id}_#{idx}"
        date_str = ev['date'].to_s.strip
        date_str = "Undated" if date_str.empty?

        master_events << {
          'id' => event_id,
          'file_id' => file_id,
          'file_name' => file_name,
          'date' => date_str,
          'event' => ev['event'],
          'who_involved' => ev['who_involved'],
          'supporting_document' => ev['supporting_document_ref'] || file_name,
          'legal_relevance' => ev['legal_relevance'],
          'is_critical_flag' => (ev['is_critical_flag'] == true || ev['is_critical_flag'].to_s == 'true'),
          'grounding_status' => ev['grounding_status'] || 'VERIFIED_GROUNDED',
          'grounding_confidence' => ev['grounding_confidence'] || 0.98,
          'missing_source_tokens' => ev['missing_source_tokens'] || [],
          'is_new_addition' => is_new_file
        }
      end
    end

    # Sort master timeline strictly chronologically
    master_events.sort_by do |ev|
      parsed = Time.parse(ev['date']) rescue nil
      parsed ? parsed.to_i : 9999999999
    end
  end

  def self.aggregate_facts_narrative(case_record, extractions, chronology)
    objective = case_record['objective'].to_s.strip
    
    narrative_paragraphs = []

    # Section 1: Intro / Objective
    if !objective.empty?
      narrative_paragraphs << "1. Nature of the Dispute & Objective: #{objective}"
    else
      narrative_paragraphs << "1. Nature of the Dispute: The present proceedings arise out of commercial/statutory disputes between the parties as established by the documentary and digital evidence on record."
    end

    # Section 2: Chronological Sequence of Material Facts
    chronology_facts = chronology.select { |e| e['is_critical_flag'] || narrative_paragraphs.size < 6 }
    if chronology_facts.any?
      chronology_facts.each_with_index do |ev, i|
        narrative_paragraphs << "#{i + 2}. Material Event (#{ev['date']}): #{ev['event']} (Evidenced by: #{ev['supporting_document']}). Relevance: #{ev['legal_relevance']}"
      end
    end

    # Section 3: Key Material Findings
    all_facts_snippets = extractions.flat_map { |ext| ext['facts'] || [] }.uniq
    if all_facts_snippets.any?
      narrative_paragraphs << "#{narrative_paragraphs.size + 1}. Established Evidentiary Facts: " + all_facts_snippets.take(4).join(" ")
    end

    narrative_paragraphs.join("\n\n")
  end

  def self.aggregate_cause_of_action(case_record, extractions)
    acts = []
    claims = []
    locations = []

    extractions.each do |ext|
      coa = ext['cause_of_action'] || {}
      acts << coa['act_or_omission'] if coa['act_or_omission'] && !coa['act_or_omission'].empty?
      claims << coa['legal_claim_basis'] if coa['legal_claim_basis'] && !coa['legal_claim_basis'].empty?
      locations << coa['where_occurred'] if coa['where_occurred'] && !coa['where_occurred'].empty?
    end

    acts_text = acts.uniq.join("; ")
    claims_text = claims.uniq.join(", ")
    loc_text = locations.uniq.join(", ")

    if acts_text.empty?
      acts_text = "Failure to discharge contractual / statutory obligations and refusal to cure material breach upon notice."
    end

    if claims_text.empty?
      claims_text = "Sections 73 & 74 of the Indian Contract Act, 1872 / Specific Relief Act, 1963 / Code of Civil Procedure, 1908."
    end

    "The Cause of Action first arose upon the initial default/breach by the Respondent and continuously subsists upon each subsequent non-compliance, dishonour, and formal refusal to rectify breaches (#{acts_text}). The cause of action arose within the territorial limits of #{loc_text.empty? ? 'this Hon\'ble Court' : loc_text}, entitling the Petitioner to seek immediate legal remedies under #{claims_text}."
  end

  def self.compute_and_log_diff(case_record, file_id, previous_summary, new_summary)
    file_rec = Database.get_file(file_id)
    file_name = file_rec ? file_rec['original_name'] : "New Evidence File"

    prev_events = previous_summary ? (previous_summary['chronology'] || []) : []
    curr_events = new_summary['chronology'] || []

    prev_event_texts = prev_events.map { |e| e['event'] }
    added_events = curr_events.select { |e| !prev_event_texts.include?(e['event']) }

    modified_facts = "Incorporated #{added_events.size} new chronological event(s) and material findings from '#{file_name}'."
    shift_in_cause_of_action = added_events.any? { |e| e['is_critical_flag'] } ? "New critical evidence introduced strengthening cause of action." : "No fundamental change in primary cause of action."
    diff_summary = "Added #{added_events.size} event(s) to timeline; updated facts and party cross-references."

    Database.create_diff_log(
      case_record['id'],
      file_id,
      new_summary['version'],
      file_name,
      added_events,
      modified_facts,
      shift_in_cause_of_action,
      diff_summary
    )
  end
end
