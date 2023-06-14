local config = {}

config.support_email = "helpdesk@mipt.ru"
config.cookie_name = "mipt_prx_sid"
config.priv_key = "FUfuWec5BSbVdWujym00hl3_EXW9M2TTRbCTGuLTv3_KWLN672663zPEuCATo_zfXLVoMiM1YyVvY0jvSNPDrQ"

config.ddos_rules = {
    -- This is a dict, where key means location, and values - parameters for this location
    -- ddos checks will be applied against "most matching" location according to nginx docs 
    -- (https://nginx.org/en/docs/http/ngx_http_core_module.html#location)

    -- Parameters:
    -- - loc_type: type of location
    --             Can be "exact" for exact matching, 
    --                    "prefix" - for entire prefix matching
    --                    "regex" - for regular expression matching 
    --                    "ci_regex" - for regular expression (case insensitive) matching
    -- - limit (number, optional): how many requests per "period" will trigger ban (default = 60)
    -- - period (number, optional): how long period for requests will be used for counting, in seconds (default = 60)
    -- - bantime (number, optional): how long user will be banned for (default = 60)

    -- Example:
    --
    -- This item will handle ddos exactly on root path "/" (including any GET params)
    -- If user makes 45 requests against "/" per 60 seconds - he will be banned for 60 seconds
    -- ["/"] = {
    --    loc_type = "exact",  
    --    limit = 45,
    --    period = 60,
    --    bantime = 60
    -- }
    -- 
    -- This item will handle all requests matching "/api/*" and ban user for 60 (default) seconds, 
    -- if he/she takes >= 35 requests per 60 (default) seconds
    -- ["/api"] = {
    --     loc_type = "prefix",
    --     limit = 35,
    -- }


    ["/"] = {
        loc_type = "exact",  
        limit = 45,
        bantime = 60
    },

    ["/abiturient"] = {
        loc_type = "prefix",
        limit = 60
    },

    ["/notification-widget"] = {
        loc_type = "prefix",
        limit = 120
    },
}

return config
