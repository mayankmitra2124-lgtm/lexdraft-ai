# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'time'
require_relative '../db/database'

module AuthService
  PBKDF2_ITERATIONS = 25_000
  SESSION_DURATION_DAYS = 30

  # ==========================================
  # Cryptographic Password Hashing (PBKDF2-HMAC-SHA256)
  # ==========================================
  def self.hash_password(password, salt = nil)
    salt ||= SecureRandom.hex(16)
    hash = OpenSSL::PKCS5.pbkdf2_hmac(password.to_s, salt, PBKDF2_ITERATIONS, 32, "sha256").unpack1("H*")
    { hash: hash, salt: salt }
  end

  def self.verify_password(password, stored_hash, salt)
    return false if password.nil? || stored_hash.nil? || salt.nil?
    calculated = OpenSSL::PKCS5.pbkdf2_hmac(password.to_s, salt, PBKDF2_ITERATIONS, 32, "sha256").unpack1("H*")
    secure_compare(calculated, stored_hash)
  end

  def self.secure_compare(a, b)
    return false unless a.is_a?(String) && b.is_a?(String) && a.bytesize == b.bytesize
    bytes = a.unpack("C*")
    res = 0
    b.each_byte { |byte| res |= byte ^ bytes.shift }
    res == 0
  end

  # ==========================================
  # Validation Helpers
  # ==========================================
  def self.validate_signup_params(params)
    first_name = params['first_name'].to_s.strip
    last_name = params['last_name'].to_s.strip
    email = params['email'].to_s.strip.downcase
    password = params['password'].to_s
    confirmation = params['password_confirmation'].to_s

    errors = []
    errors << "First name is required." if first_name.empty?
    errors << "Last name is required." if last_name.empty?

    email_regex = /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\z/
    errors << "Please provide a valid email address." unless email =~ email_regex

    if password.length < 8
      errors << "Password must be at least 8 characters long."
    elsif !(password =~ /[0-9]/ || password =~ /[^A-Za-z0-9]/)
      errors << "Password must contain at least one number or special character."
    end

    errors << "Passwords do not match." if password != confirmation

    errors
  end

  # ==========================================
  # Core Authentication Flows
  # ==========================================
  def self.signup(params)
    errors = validate_signup_params(params)
    return { success: false, errors: errors, status: 400 } unless errors.empty?

    email = params['email'].to_s.strip.downcase
    first_name = params['first_name'].to_s.strip
    last_name = params['last_name'].to_s.strip
    password = params['password'].to_s

    # Check for duplicate email
    existing = Database.query_one("SELECT id FROM users WHERE LOWER(email) = ?", [email])
    if existing
      return { success: false, errors: ["An account with this email address already exists."], status: 409 }
    end

    user_id = "usr_#{Time.now.to_i}_#{rand(1000..9999)}"
    now = Time.now.utc.iso8601
    crypto = hash_password(password)

    Database.connection.execute(
      <<-SQL,
        INSERT INTO users (id, first_name, last_name, email, password_hash, salt, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      SQL
      [user_id, first_name, last_name, email, crypto[:hash], crypto[:salt], now, now]
    )

    # Seed initial demo case for new user
    seed_user_case(user_id, first_name, last_name)

    # Create active session
    session = create_session(user_id)

    user_payload = {
      'id' => user_id,
      'first_name' => first_name,
      'last_name' => last_name,
      'email' => email
    }

    {
      success: true,
      token: session[:token],
      user: user_payload,
      status: 201
    }
  end

  def self.signin(email, password)
    email_clean = email.to_s.strip.downcase
    user = Database.query_one("SELECT * FROM users WHERE LOWER(email) = ?", [email_clean])

    if user.nil? || !verify_password(password, user['password_hash'], user['salt'])
      return { success: false, errors: ["Invalid email address or password."], status: 401 }
    end

    session = create_session(user['id'])

    user_payload = {
      'id' => user['id'],
      'first_name' => user['first_name'],
      'last_name' => user['last_name'],
      'email' => user['email']
    }

    {
      success: true,
      token: session[:token],
      user: user_payload,
      status: 200
    }
  end

  def self.signout(token)
    return false if token.nil? || token.empty?
    clean = token.to_s.strip.sub(/\ABearer\s+/i, '').force_encoding('UTF-8')
    Database.connection.execute("DELETE FROM user_sessions WHERE token = ?", [clean])
    true
  end

  def self.create_session(user_id)
    session_id = "sess_#{Time.now.to_i}_#{rand(1000..9999)}"
    token = SecureRandom.hex(32)
    expires_at = (Time.now.utc + (SESSION_DURATION_DAYS * 86400)).iso8601
    now = Time.now.utc.iso8601

    Database.connection.execute(
      <<-SQL,
        INSERT INTO user_sessions (id, user_id, token, expires_at, created_at)
        VALUES (?, ?, ?, ?, ?)
      SQL
      [session_id, user_id, token, expires_at, now]
    )

    { session_id: session_id, token: token, expires_at: expires_at }
  end

  def self.authenticate_token(token)
    return nil if token.nil? || token.to_s.strip.empty?

    clean_token = token.to_s.strip.force_encoding('UTF-8')
    clean_token = clean_token.sub(/\ABearer\s+/i, '') if clean_token.start_with?("Bearer ", "bearer ")
    clean_token = clean_token.force_encoding('UTF-8')

    row = Database.query_one(
      <<-SQL,
        SELECT s.token, s.expires_at, u.id, u.first_name, u.last_name, u.email
        FROM user_sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.token = ?
      SQL
      [clean_token]
    )

    return nil unless row

    # Check expiration
    expires_at = Time.parse(row['expires_at']) rescue nil
    if expires_at && expires_at < Time.now.utc
      Database.connection.execute("DELETE FROM user_sessions WHERE token = ?", [clean_token])
      return nil
    end

    {
      'id' => row['id'],
      'first_name' => row['first_name'],
      'last_name' => row['last_name'],
      'email' => row['email']
    }
  end

  # Seed a fresh starter case for new users
  def self.seed_user_case(user_id, first_name, last_name)
    now = Time.now.utc.iso8601
    case_id = "case_#{user_id}_starter"

    Database.connection.execute(
      <<-SQL,
        INSERT OR IGNORE INTO cases (
          id, user_id, name, case_number, court_name, objective,
          parties_info, hearing_date, tier, max_storage_bytes, max_files,
          has_unread_changes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
      SQL
      [
        case_id,
        user_id,
        "Apex Infrastructure Ltd. v. Delhi Metro Real Estate Pvt. Ltd.",
        "ARB.P. / COMM. SUIT NO. 412 OF 2024",
        "IN THE HIGH COURT OF DELHI AT NEW DELHI (COMMERCIAL DIVISION)",
        "Recovery of unpaid milestone RA Bills (₹4,20,00,000) and adjudication of disputes under Clause 28 (Arbitration) of EPC Contract dated 14.01.2023.",
        "Apex Infrastructure Ltd. (Claimant/Petitioner) vs. Delhi Metro Real Estate Pvt. Ltd. (Respondent)",
        (Time.now + 86400 * 14).strftime("%Y-%m-%d"),
        "pro",
        4294967296,
        100,
        now,
        now
      ]
    )

    # Attach any global sample files to this case if available
    first_sample = Database.query_one("SELECT * FROM evidence_files WHERE case_id LIKE 'case_apex%' LIMIT 1")
    if first_sample
      new_file_id = "file_#{user_id}_sample"
      Database.connection.execute(
        <<-SQL,
          INSERT OR IGNORE INTO evidence_files (
            id, case_id, filename, original_name, file_type, file_size, storage_path,
            status, progress, error_message, is_critical_evidence, uploaded_at, processed_at, transcript
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        [
          new_file_id,
          case_id,
          first_sample['filename'],
          first_sample['original_name'],
          first_sample['file_type'],
          first_sample['file_size'],
          first_sample['storage_path'],
          'Complete',
          100,
          nil,
          1,
          now,
          now,
          first_sample['transcript']
        ]
      )

      # Copy extraction
      sample_ext = Database.query_one("SELECT * FROM extractions WHERE file_id = ?", [first_sample['id']])
      if sample_ext
        Database.connection.execute(
          <<-SQL,
            INSERT OR IGNORE INTO extractions (
              id, file_id, case_id, file_summary, parties_json, jurisdiction_json,
              chronology_json, facts_json, cause_of_action_json, people_entities_json,
              ambiguities_json, raw_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          SQL
          [
            "ext_#{user_id}_sample",
            new_file_id,
            case_id,
            sample_ext['file_summary'],
            sample_ext['parties_json'],
            sample_ext['jurisdiction_json'],
            sample_ext['chronology_json'],
            sample_ext['facts_json'],
            sample_ext['cause_of_action_json'],
            sample_ext['people_entities_json'],
            sample_ext['ambiguities_json'],
            sample_ext['raw_json'],
            now
          ]
        )
      end

      # Copy master summary
      sample_sum = Database.query_one("SELECT * FROM master_summaries WHERE case_id LIKE 'case_apex%' ORDER BY version DESC LIMIT 1")
      if sample_sum
        Database.connection.execute(
          <<-SQL,
            INSERT OR IGNORE INTO master_summaries (
              id, case_id, version, parties_json, jurisdiction_json,
              chronology_json, facts_narrative, cause_of_action_text, limitation_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          SQL
          [
            "sum_#{user_id}_sample",
            case_id,
            1,
            sample_sum['parties_json'],
            sample_sum['jurisdiction_json'],
            sample_sum['chronology_json'],
            sample_sum['facts_narrative'],
            sample_sum['cause_of_action_text'],
            sample_sum['limitation_json'],
            now
          ]
        )
      end
    end
  end
end
