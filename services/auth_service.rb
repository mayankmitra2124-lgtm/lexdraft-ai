# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'time'
require_relative '../db/database'

module AuthService
  PBKDF2_ITERATIONS = 25_000
  SESSION_DURATION_DAYS = 30
  MAX_ACCOUNT_ATTEMPTS = (ENV['MAX_LOGIN_ATTEMPTS'] || 5).to_i
  ACCOUNT_LOCK_MINUTES = (ENV['ACCOUNT_LOCK_MINUTES'] || 15).to_i
  MAX_IP_ATTEMPTS = (ENV['MAX_IP_LOGIN_ATTEMPTS'] || 20).to_i
  IP_LOCK_MINUTES = (ENV['IP_LOCK_MINUTES'] || 15).to_i

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
    tenant_id = "tnt_#{user_id.sub(/\Ausr_/, '')}"
    chamber_name = "#{first_name} #{last_name}'s Chambers"
    subdomain = "chambers-#{user_id.sub(/\Ausr_/, '')}"
    now = Time.now.utc.iso8601
    crypto = hash_password(password)

    # Provision enterprise tenant boundary for new user
    Database.connection.execute(
      "INSERT OR IGNORE INTO tenants (id, name, subdomain, tier, max_storage_bytes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [tenant_id, chamber_name, subdomain, 'pro', 10737418240, now, now]
    )

    # SECURITY FIX: All public signups are strictly 'user' role.
    # Admin accounts must be provisioned manually in the database
    # (e.g. UPDATE users SET role = 'admin' WHERE id = ?), never via
    # public signup, to prevent takeover by whoever signs up first
    # with the ADMIN_EMAIL address.
    role = 'user'

    Database.connection.execute(
      <<-SQL,
        INSERT INTO users (id, tenant_id, first_name, last_name, email, password_hash, salt, role, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
      [user_id, tenant_id, first_name, last_name, email, crypto[:hash], crypto[:salt], role, now, now]
    )

    # Seed initial demo case for new user scoped to tenant
    seed_user_case(user_id, first_name, last_name, tenant_id)

    # Create active session with hashed storage
    session = create_session(user_id)

    # Immutable Audit Log
    Database.log_audit_event(
      tenant_id: tenant_id,
      user_id: user_id,
      action: 'auth.signup_success',
      resource_type: 'user',
      resource_id: user_id,
      metadata: { email: email }
    )

    user_payload = {
      'id' => user_id,
      'tenant_id' => tenant_id,
      'first_name' => first_name,
      'last_name' => last_name,
      'email' => email,
      'role' => role
    }

    {
      success: true,
      token: session[:token],
      user: user_payload,
      status: 201
    }
  end

  def self.signin(email, password, ip = nil)
    # 1. IP-level rate limiting check
    if ip
      ip_err = check_ip_lockout(ip)
      return { success: false, errors: [ip_err], status: 429 } if ip_err
    end

    email_clean = email.to_s.strip.downcase
    user = Database.query_one("SELECT * FROM users WHERE LOWER(email) = ?", [email_clean])

    # 2. Account-level lockout check
    if user && user['locked_until']
      lock_time = Time.parse(user['locked_until']) rescue nil
      if lock_time && lock_time > Time.now.utc
        minutes_left = [((lock_time - Time.now.utc) / 60.0).ceil, 1].max
        Database.log_audit_event(
          tenant_id: user['tenant_id'],
          user_id: user['id'],
          action: 'auth.lockout_blocked',
          resource_type: 'user',
          resource_id: user['id'],
          ip_address: ip,
          metadata: { email: email_clean, minutes_left: minutes_left }
        )
        return {
          success: false,
          errors: ["Too many failed attempts. Account is locked, try again in #{minutes_left} minute#{'s' if minutes_left != 1}."],
          status: 429
        }
      else
        # Lockout period expired: reset counter
        Database.connection.execute("UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = ?", [user['id']])
        user['failed_login_attempts'] = 0
        user['locked_until'] = nil
      end
    end

    # 3. Password verification
    if user.nil? || !verify_password(password, user['password_hash'], user['salt'])
      # If account exists, track failed attempt against account
      if user
        new_attempts = user['failed_login_attempts'].to_i + 1
        if new_attempts >= MAX_ACCOUNT_ATTEMPTS
          locked_until = (Time.now.utc + (ACCOUNT_LOCK_MINUTES * 60)).iso8601
          Database.connection.execute(
            "UPDATE users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?",
            [new_attempts, locked_until, user['id']]
          )
          record_failed_ip_attempt(ip) if ip
          Database.log_audit_event(
            tenant_id: user['tenant_id'],
            user_id: user['id'],
            action: 'auth.lockout_triggered',
            resource_type: 'user',
            resource_id: user['id'],
            ip_address: ip,
            metadata: { email: email_clean, attempts: new_attempts, lock_duration_minutes: ACCOUNT_LOCK_MINUTES }
          )
          return {
            success: false,
            errors: ["Too many failed attempts. Account is locked, try again in #{ACCOUNT_LOCK_MINUTES} minutes."],
            status: 429
          }
        else
          Database.connection.execute(
            "UPDATE users SET failed_login_attempts = ? WHERE id = ?",
            [new_attempts, user['id']]
          )
          Database.log_audit_event(
            tenant_id: user['tenant_id'],
            user_id: user['id'],
            action: 'auth.signin_failed',
            resource_type: 'user',
            resource_id: user['id'],
            ip_address: ip,
            metadata: { email: email_clean, attempts: new_attempts, failure_reason: 'invalid_password' }
          )
        end
      end

      record_failed_ip_attempt(ip) if ip
      return { success: false, errors: ["Invalid email address or password."], status: 401 }
    end

    # 4. Successful login: Reset counters and clear lock
    Database.connection.execute(
      "UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = ?",
      [user['id']]
    )
    reset_ip_attempts(ip) if ip

    session = create_session(user['id'])

    Database.log_audit_event(
      tenant_id: user['tenant_id'],
      user_id: user['id'],
      action: 'auth.signin_success',
      resource_type: 'user',
      resource_id: user['id'],
      ip_address: ip,
      metadata: { email: email_clean }
    )

    user_payload = {
      'id' => user['id'],
      'tenant_id' => user['tenant_id'],
      'first_name' => user['first_name'],
      'last_name' => user['last_name'],
      'email' => user['email'],
      'role' => user['role'] || 'user'
    }

    {
      success: true,
      token: session[:token],
      user: user_payload,
      status: 200
    }
  end

  def self.check_ip_lockout(ip)
    return nil if ip.nil? || ip.to_s.strip.empty?
    ip_clean = ip.to_s.strip
    row = Database.query_one("SELECT * FROM ip_login_attempts WHERE ip = ?", [ip_clean])
    return nil unless row

    if row['locked_until']
      lock_time = Time.parse(row['locked_until']) rescue nil
      if lock_time && lock_time > Time.now.utc
        minutes_left = [((lock_time - Time.now.utc) / 60.0).ceil, 1].max
        return "Too many failed attempts from this IP. Please try again in #{minutes_left} minute#{'s' if minutes_left != 1}."
      end
    end
    nil
  end

  def self.record_failed_ip_attempt(ip)
    return unless ip && !ip.to_s.strip.empty?
    ip_clean = ip.to_s.strip
    now = Time.now.utc
    row = Database.query_one("SELECT * FROM ip_login_attempts WHERE ip = ?", [ip_clean])

    if row
      window_start = Time.parse(row['window_start']) rescue now
      if (now - window_start) > (IP_LOCK_MINUTES * 60)
        Database.connection.execute(
          "UPDATE ip_login_attempts SET attempt_count = 1, window_start = ?, locked_until = NULL WHERE ip = ?",
          [now.iso8601, ip_clean]
        )
      else
        new_count = row['attempt_count'].to_i + 1
        locked_until = new_count >= MAX_IP_ATTEMPTS ? (now + (IP_LOCK_MINUTES * 60)).iso8601 : nil
        Database.connection.execute(
          "UPDATE ip_login_attempts SET attempt_count = ?, locked_until = ? WHERE ip = ?",
          [new_count, locked_until, ip_clean]
        )
      end
    else
      Database.connection.execute(
        "INSERT INTO ip_login_attempts (ip, attempt_count, window_start, locked_until) VALUES (?, 1, ?, NULL)",
        [ip_clean, now.iso8601]
      )
    end
  end

  def self.reset_ip_attempts(ip)
    return unless ip && !ip.to_s.strip.empty?
    Database.connection.execute("DELETE FROM ip_login_attempts WHERE ip = ?", [ip.to_s.strip])
  end

  def self.signout(token)
    return false if token.nil? || token.empty?
    clean = token.to_s.strip.sub(/\ABearer\s+/i, '').force_encoding('UTF-8')
    hashed = OpenSSL::Digest::SHA256.hexdigest(clean)

    row = Database.query_one(
      "SELECT s.user_id, u.tenant_id FROM user_sessions s JOIN users u ON s.user_id = u.id WHERE s.token_hash = ? OR s.token = ?",
      [hashed, clean]
    )
    if row
      Database.log_audit_event(
        tenant_id: row['tenant_id'],
        user_id: row['user_id'],
        action: 'auth.signout',
        resource_type: 'user_session',
        metadata: { token_hash_prefix: hashed[0..7] }
      )
    end

    Database.connection.execute("DELETE FROM user_sessions WHERE token_hash = ? OR token = ?", [hashed, clean])
    true
  end

  def self.admin?(user)
    return false if user.nil?
    return true if user['role'].to_s.downcase == 'admin'
    admin_email = ENV['ADMIN_EMAIL']
    return true if admin_email && !admin_email.to_s.strip.empty? && user['email'].to_s.strip.downcase == admin_email.to_s.strip.downcase
    false
  end

  def self.create_session(user_id)
    session_id = "sess_#{Time.now.to_i}_#{rand(1000..9999)}"
    raw_token = SecureRandom.hex(32)
    token_hash = OpenSSL::Digest::SHA256.hexdigest(raw_token)
    expires_at = (Time.now.utc + (SESSION_DURATION_DAYS * 86400)).iso8601
    now = Time.now.utc.iso8601

    Database.connection.execute(
      <<-SQL,
        INSERT INTO user_sessions (id, user_id, token, token_hash, expires_at, created_at)
        VALUES (?, ?, NULL, ?, ?, ?)
      SQL
      [session_id, user_id, token_hash, expires_at, now]
    )

    { session_id: session_id, token: raw_token, token_hash: token_hash, expires_at: expires_at }
  end

  def self.authenticate_token(token)
    return nil if token.nil? || token.to_s.strip.empty?

    clean_token = token.to_s.strip.force_encoding('UTF-8')
    clean_token = clean_token.sub(/\ABearer\s+/i, '') if clean_token.start_with?("Bearer ", "bearer ")
    clean_token = clean_token.force_encoding('UTF-8')
    hashed = OpenSSL::Digest::SHA256.hexdigest(clean_token)

    row = Database.query_one(
      <<-SQL,
        SELECT s.id as session_id, s.token, s.token_hash, s.expires_at,
               u.id, u.tenant_id, u.first_name, u.last_name, u.email, u.role
        FROM user_sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.token_hash = ? OR s.token = ?
      SQL
      [hashed, clean_token]
    )

    return nil unless row

    # Dual-Read Transition Bridge: If matched on legacy plaintext token, upgrade in-place immediately
    if row['token_hash'].nil?
      Database.connection.execute(
        "UPDATE user_sessions SET token_hash = ?, token = NULL WHERE id = ?",
        [hashed, row['session_id']]
      )
    end

    # Check expiration
    expires_at = Time.parse(row['expires_at']) rescue nil
    if expires_at && expires_at < Time.now.utc
      Database.connection.execute("DELETE FROM user_sessions WHERE token_hash = ? OR token = ?", [hashed, clean_token])
      return nil
    end

    {
      'id' => row['id'],
      'tenant_id' => row['tenant_id'],
      'first_name' => row['first_name'],
      'last_name' => row['last_name'],
      'email' => row['email'],
      'role' => row['role'] || 'user'
    }
  end

  # Seed a fresh starter case for new users
  def self.seed_user_case(user_id, first_name, last_name, tenant_id = nil)
    now = Time.now.utc.iso8601
    case_id = "case_#{user_id}_starter"

    t_id = tenant_id
    if t_id.nil? || t_id.to_s.strip.empty?
      u = Database.query_one("SELECT tenant_id FROM users WHERE id = ?", [user_id])
      t_id = u['tenant_id'] if u
    end
    t_id ||= "tnt_system_default"

    Database.connection.execute(
      <<-SQL,
        INSERT OR IGNORE INTO cases (
          id, tenant_id, user_id, name, case_number, court_name, objective,
          parties_info, hearing_date, tier, max_storage_bytes, max_files,
          has_unread_changes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
      SQL
      [
        case_id,
        t_id,
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
      sample_sha = first_sample['sha256_hash'] || Digest::SHA256.hexdigest(new_file_id)
      sample_key = "tenants/#{t_id}/cases/#{case_id}/evidence/#{new_file_id}/#{sample_sha}"
      Database.connection.execute(
        <<-SQL,
          INSERT OR IGNORE INTO evidence_files (
            id, tenant_id, case_id, filename, original_name, file_type, file_size, storage_path,
            storage_key, sha256_hash, status, progress, error_message, is_critical_evidence, uploaded_at, processed_at, transcript
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        [
          new_file_id,
          t_id,
          case_id,
          first_sample['filename'],
          first_sample['original_name'],
          first_sample['file_type'],
          first_sample['file_size'],
          first_sample['storage_path'],
          sample_key,
          sample_sha,
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
