# Creates or updates the "grimwilder" DigitalOcean Cloud Firewall:
#   - SSH (22) from anywhere: key-only login, and GitHub's deploy runners have no fixed IP
#   - HTTP/HTTPS (80, 443) only from Cloudflare's published ranges, so nobody can skip the WAF
#   - all outbound allowed
# and attaches it to the droplet behind DROPLET_IP. Safe to re-run whenever Cloudflare's ranges change.
#
# Usage (from the repo root on your Mac):
#   DIGITALOCEAN_TOKEN=dop_v1_... ruby script/digitalocean_firewall.rb
#
# The token needs read on droplet and reserved_ip, and read/create/update on firewall
# (DigitalOcean → API → Tokens → Custom scopes).

require "net/http"
require "json"
require "uri"

FIREWALL_NAME = "grimwilder"
DROPLET_IP = ENV.fetch("DROPLET_IP", "129.212.197.211")
TOKEN = ENV.fetch("DIGITALOCEAN_TOKEN") { abort "Set DIGITALOCEAN_TOKEN (DigitalOcean → API → Tokens)." }
API = "https://api.digitalocean.com/v2"

def fetch_text(url)
  res = Net::HTTP.get_response(URI(url))
  abort "Couldn't fetch #{url}: #{res.code}" unless res.is_a?(Net::HTTPSuccess)
  res.body.split.map(&:strip).reject(&:empty?)
end

def api(method, path, body = nil)
  uri = URI("#{API}#{path}")
  req = Net::HTTP.const_get(method.capitalize).new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  return nil if res.code == "404"
  abort "#{method.upcase} #{path} failed (#{res.code}): #{res.body}" unless res.is_a?(Net::HTTPSuccess)
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

# Find the droplet: DROPLET_IP may be a Reserved IP or the droplet's own address.
droplet_id =
  if (reserved = api(:get, "/reserved_ips/#{DROPLET_IP}"))
    reserved.dig("reserved_ip", "droplet", "id") or abort "Reserved IP #{DROPLET_IP} isn't assigned to a droplet."
  else
    droplets = api(:get, "/droplets?per_page=200")["droplets"]
    match = droplets.find do |d|
      d.dig("networks", "v4").any? { |n| n["ip_address"] == DROPLET_IP }
    end
    match&.fetch("id") or abort "No droplet or Reserved IP has the address #{DROPLET_IP}."
  end

cloudflare = fetch_text("https://www.cloudflare.com/ips-v4") + fetch_text("https://www.cloudflare.com/ips-v6")
anywhere = [ "0.0.0.0/0", "::/0" ]

rules = {
  name: FIREWALL_NAME,
  droplet_ids: [ droplet_id ],
  inbound_rules: [
    { protocol: "tcp", ports: "22", sources: { addresses: anywhere } },
    { protocol: "tcp", ports: "80", sources: { addresses: cloudflare } },
    { protocol: "tcp", ports: "443", sources: { addresses: cloudflare } }
  ],
  outbound_rules: [
    { protocol: "tcp", ports: "all", destinations: { addresses: anywhere } },
    { protocol: "udp", ports: "all", destinations: { addresses: anywhere } },
    { protocol: "icmp", destinations: { addresses: anywhere } }
  ]
}

existing = api(:get, "/firewalls?per_page=200")["firewalls"].find { |f| f["name"] == FIREWALL_NAME }

if existing
  api(:put, "/firewalls/#{existing["id"]}", rules)
  puts "Updated firewall #{FIREWALL_NAME} (#{existing["id"]})"
else
  created = api(:post, "/firewalls", rules)
  puts "Created firewall #{FIREWALL_NAME} (#{created.dig("firewall", "id")})"
end
puts "  droplet #{droplet_id}; 22 open; 80/443 from #{cloudflare.size} Cloudflare ranges"
