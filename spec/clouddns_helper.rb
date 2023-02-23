MockDnsZone = Struct.new(
  # https://github.com/googleapis/google-cloud-ruby/blob/main/google-cloud-dns/lib/google/cloud/dns/zone.rb
  :service, :gapi, :id, :name, :dns, :description, :name_servers, :name_server_set, :created_at
) do
  def add(name, type, ttl, data)
    change = MockDnsChange.new
    change.additions(name, type, ttl, data)
    # return name
  end
end

# --------------------
# Main GoogleCloudDnsProject Object
# --------------------
MockGoogleCloudDnsProjectConnection = Struct.new(
  # https://cloud.google.com/ruby/docs/reference/google-cloud-dns/latest/Google-Cloud#Google__Cloud_dns_instance_
  :scope, :retries, :timeout
) do
  def zone
    MockDnsZone.new
  end
end

def mock_Google_Cloud_Dns_Project_Connection(options = {})
  MockGoogleCloudDnsProjectConnection.new()
end