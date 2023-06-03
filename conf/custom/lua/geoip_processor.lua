local _GP = {}

function _GP.get_asn_and_country()
    local cjson = require 'cjson'
    local geo = require 'resty.maxminddb'

    if not geo.initted() then
        geo.init({
            asn = "/var/lib/geoip/GeoLite2-ASN.mmdb",
            country = "/var/lib/geoip/GeoLite2-Country.mmdb"
        })
    end

    local res, err = geo.lookup("asn", ngx.var.arg_ip or ngx.var.remote_addr)
    local asn = "0 - Unknown"
    if res then
        asn = res.autonomous_system_number .. " - " .. res.autonomous_system_organization
    end

    local country_iso_code = "UNKNOWN"
    local res,err = geo.lookup("country", ngx.var.arg_ip or ngx.var.remote_addr)
    if res then
        country_iso_code = res.country.iso_code
    end
    return asn, country_iso_code
end

return _GP
