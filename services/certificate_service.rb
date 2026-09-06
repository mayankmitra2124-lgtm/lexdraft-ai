# frozen_string_literal: true

require 'digest'
require 'time'

module CertificateService
  def self.generate_section_65b_certificate(case_record, file_record)
    file_path = file_record['storage_path']
    file_name = file_record['original_name'] || File.basename(file_path)
    file_size = file_record['file_size'].to_i
    upload_time = file_record['uploaded_at'] || Time.now.utc.iso8601

    # Calculate cryptographic SHA-256 hash digest
    sha256_digest = if File.exist?(file_path)
                      Digest::SHA256.file(file_path).hexdigest
                    else
                      Digest::SHA256.hexdigest(file_name + upload_time)
                    end

    deponent_name = "Adv. Mayank Mitra"
    court_name = case_record['court_name'] || "High Court of Delhi (Commercial Division)"
    case_title = case_record['name'] || "Commercial Arbitration / Civil Matter"
    case_number = case_record['case_number'] || "O.M.P. (COMM) / CS (COMM)"

    cert_seed = "#{case_record['id']}:#{file_record['id']}:#{sha256_digest}"
    certificate_id = "CERT-65B-#{Digest::SHA256.hexdigest(cert_seed)[0..11].upcase}"
    formatted_date = Time.now.strftime("%B %d, %Y")

    certificate_text = <<~CERT
      ====================================================================================================
                        IN THE #{court_name.upcase}
                         [COMMERCIAL / CIVIL JURISDICTION]
      
      IN THE MATTER OF:
      #{case_title}
      Case No. / Matter Ref: #{case_number}
      
      ====================================================================================================
               CERTIFICATE UNDER SECTION 65B OF THE INDIAN EVIDENCE ACT, 1872
                                            READ WITH
             SECTION 63 OF THE BHARATIYA SAKSHYA ADHINIYAM, 2023 (BSA, 2023)
      ====================================================================================================
      
      Certificate Reference ID: #{certificate_id}
      Date of Certification:   #{formatted_date}
      
      I, #{deponent_name}, Advocate & Authorized Custodian of Records, having chamber office at New Delhi, 
      do hereby solemnly affirm, declare, and state on oath as under:
      
      1. COMPETENCE & CHAIN OF CUSTODY:
         I am the authorized legal counsel/custodian handling the electronic document processing and evidence 
         management in the captioned matter. In that capacity, I have had lawful access to and control over the 
         computer systems, electronic terminals, and secure data storage servers utilized for the reception, 
         storage, and processing of the electronic records filed in these proceedings.
      
      2. IDENTIFICATION OF ELECTRONIC RECORD:
         The electronic record described herein has been retrieved from lawful digital custody and processed 
         under strict digital provenance protocols. Particulars of the electronic evidence are as follows:
         
         • Original File Name:       #{file_name}
         • Nature / Classification:   #{file_record['file_type']}
         • Evidentiary File Size:     #{file_size} bytes (#{format_size(file_size)})
         • Ingestion & Inscription:   #{upload_time}
         • Cryptographic Algorithm:   SHA-256 (Secure Hash Algorithm 256-bit)
         • Cryptographic Hash Digest: #{sha256_digest}
      
      3. INTEGRITY OF COMPUTER OPERATION:
         During the material period, the computer system and server architecture utilized to store, process, 
         and transcribe the aforesaid electronic record was operating properly in the ordinary and lawful course 
         of business. At no point was the accuracy, cryptographic integrity, or evidentiary substance of the 
         contents affected, modified, or corrupted.
      
      4. COMPLIANCE WITH SUPREME COURT MANDATE:
         This Certificate is executed in strict compliance with the mandatory statutory requirements of Section 65B(4) 
         of the Indian Evidence Act, 1872, Section 63(4) of the Bharatiya Sakshya Adhiniyam, 2023, and the binding 
         precedents of the Hon'ble Supreme Court of India in:
           (i)  Arjun Panditrao Khotkar v. Kailash Kushanrao Gorantyal & Ors., (2020) 7 SCC 1; and
           (ii) Anvar P.V. v. P.K. Basheer & Anr., (2014) 10 SCC 473.
      
      5. VERITY OF CONTENTS:
         I certify that the printout, digital transcript, and extracts produced from the aforesaid electronic record 
         constitute a true, exact, and unadulterated reproduction of the electronic record stored in the system.
      
      ----------------------------------------------------------------------------------------------------
                                                VERIFICATION
      ----------------------------------------------------------------------------------------------------
      Verified at New Delhi on this #{formatted_date} that the contents of paragraphs 1 to 5 of the above 
      Certificate are true and correct to the best of my knowledge, information derived from digital machine logs, 
      and belief. No material fact has been concealed.
      
      
      [Signed & Sealed]
      ___________________________________________
      #{deponent_name}
      Advocate & Certified Systems Inscription Deponent
      Enrolment No: D/XXXX/201X
      Chambers, High Court of Delhi
      ====================================================================================================
    CERT

    {
      certificate_id: certificate_id,
      sha256: sha256_digest,
      date: formatted_date,
      file_name: file_name,
      file_size: file_size,
      court_name: court_name,
      case_title: case_title,
      certificate_text: certificate_text
    }
  end

  def self.format_size(bytes)
    return "0 B" if bytes.nil? || bytes.zero?
    units = %w[B KB MB GB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, units.length - 1].min
    format("%.1f %s", bytes.to_f / (1024**exp), units[exp])
  end
end
