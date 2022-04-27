module Pkg::Sign::Msi
  module_function

  def sign(target_dir = 'pkg')
    require 'google/cloud/storage'
    require 'googleauth'
    require 'json'
    require 'net/http'
    require 'uri'

    service_account_credentials = '/var/lib/jenkins/.creds/gcp-service-account-credentials-windows-signer.json'
    service_url = 'https://serverless-sign-4k7em2ejkq-uc.a.run.app/signMSI'

    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(service_account_credentials),
      target_audience: service_url
    )

    gcp_auth_token = authorizer.fetch_access_token!['id_token']

    gcp_storage = Google::Cloud::Storage.new(
      project_id: 'puppet-release-engineering',
      credentials: service_account_credentials
    )
    tosign_bucket = gcp_storage.bucket('windows-tosign-bucket')
    signed_bucket = gcp_storage.bucket('windows-signed-bucket')

    service_uri = URI.parse(service_url)
    headers = { 'Content-Type': 'application/json', 'Authorization': "Bearer #{gcp_auth_token}" }
    http = Net::HTTP.new(service_uri.host, service_uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(service_uri.request_uri, headers)

    # Create hash to keep track of the signed msis
    signed_msis = {}

    msis = Dir.glob("#{target_dir}/windows*/**/*.msi")

    # Upload msis to GCP and sign them
    msis.each do |msi|
      begin
        tosign_bucket.create_file(msi, msi)
      rescue StandardError => e
        delete_tosign_msis(tosign_bucket, msis)
        fail "There was an error uploading #{msi} to the windows-tosign-bucket gcp bucket.\n#{e}"
      end
      msi_json = { 'Path': msi }
      request.body = msi_json.to_json
      begin
        response = http.request(request)
        response_body = JSON.parse(JSON.parse(response.body.to_json), :quirks_mode => true)
      rescue StandardError => e
        delete_tosign_msis(tosign_bucket, msis)
        delete_signed_msis(signed_bucket, signed_msis)
        fail "There was an error signing #{msi}.\n#{e}"
      end
      # Store location of signed msi
      signed_msi = response_body['Path']
      signed_msis[msi] = signed_msi
    end

    # Download the signed msis
    msis.each do |msi|
      begin
        signed_msi = signed_bucket.file(signed_msis[msi])
        signed_msi.download(msi)
      rescue StandardError => e
        delete_tosign_msis(tosign_bucket, msis)
        delete_signed_msis(signed_bucket, signed_msis)
        fail "There was an error retrieving the signed msi:#{msi}.\n#{e}"
      end
    end

    # Cleanup buckets
    delete_tosign_msis(tosign_bucket, msis)
    delete_signed_msis(signed_bucket, signed_msis)
  end

  def delete_tosign_msis(bucket, msis)
    msis.each do |msi|
      tosign_msi = bucket.file(msi)
      tosign_msi.delete unless tosign_msi.nil?
    end
  end

  def delete_signed_msis(bucket, signed_msis)
    signed_msis.each do |msi, temp_name|
      signed_msi = bucket.file(temp_name)
      signed_msi.delete unless signed_msi.nil?
    end
  end
end
