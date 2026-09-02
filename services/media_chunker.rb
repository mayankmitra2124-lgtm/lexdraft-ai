# frozen_string_literal: true

require 'fileutils'

module MediaChunker
  CHUNK_SIZE_THRESHOLD_BYTES = 25 * 1024 * 1024 # 25MB threshold for chunking

  def self.should_chunk?(file_record)
    file_type = file_record['file_type']
    file_size = file_record['file_size'].to_i

    return true if %w[Audio Video].include?(file_type) && file_size > (10 * 1024 * 1024) # >10MB audio/video
    return true if file_type == 'WhatsApp/Text' && file_size > (5 * 1024 * 1024)        # >5MB text chat
    return true if file_size > CHUNK_SIZE_THRESHOLD_BYTES
    false
  end

  def self.chunk_file(file_record)
    file_id = file_record['id']
    file_path = file_record['storage_path']
    file_type = file_record['file_type']
    file_size = file_record['file_size'].to_i

    chunks = []

    if file_type == 'Audio' || file_type == 'Video'
      # Calculate estimated 10-15 min segment count
      # (assuming ~1-2MB/min for compressed media or based on size)
      estimated_duration_min = [15, (file_size / (1.5 * 1024 * 1024)).ceil].max
      chunk_duration_min = 12 # 12-minute segments
      num_chunks = (estimated_duration_min.to_f / chunk_duration_min).ceil
      num_chunks = [num_chunks, 1].max

      (0...num_chunks).each do |i|
        start_min = i * chunk_duration_min
        end_min = [start_min + chunk_duration_min, estimated_duration_min].min
        start_str = format("%02d:%02d:00", start_min / 60, start_min % 60)
        end_str = format("%02d:%02d:00", end_min / 60, end_min % 60)
        title = "Segment #{i + 1} (#{start_str} - #{end_str})"

        chunk_id = Database.create_chunk(
          file_id,
          i + 1,
          title,
          start_str,
          end_str,
          file_path
        )
        chunks << { 'id' => chunk_id, 'title' => title, 'start' => start_str, 'end' => end_str }
      end

    elsif file_type == 'WhatsApp/Text'
      # Text chat chunking by message block or date block
      lines = File.readlines(file_path, encoding: 'UTF-8') rescue []
      chunk_size_lines = 1000
      num_chunks = (lines.size.to_f / chunk_size_lines).ceil
      num_chunks = [num_chunks, 1].max

      (0...num_chunks).each do |i|
        start_idx = i * chunk_size_lines
        end_idx = [(i + 1) * chunk_size_lines, lines.size].min
        title = "Chat Messages #{start_idx + 1} to #{end_idx}"

        chunk_id = Database.create_chunk(
          file_id,
          i + 1,
          title,
          "Line #{start_idx + 1}",
          "Line #{end_idx}",
          file_path
        )
        chunks << { 'id' => chunk_id, 'title' => title, 'start' => "Line #{start_idx + 1}", 'end' => "Line #{end_idx}" }
      end

    else
      # Default single chunk
      chunk_id = Database.create_chunk(
        file_id,
        1,
        "Full Document",
        "Page 1",
        "End",
        file_path
      )
      chunks << { 'id' => chunk_id, 'title' => 'Full Document', 'start' => 'Page 1', 'end' => 'End' }
    end

    chunks
  end
end
