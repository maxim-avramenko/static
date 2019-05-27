--
-- init nginx for static service
--

--
--init libvips
--
local vips_success, vips_error = pcall(function()
    vips = require "vips"
    -- libvips caching is not needed
    vips.cache_set_max(0)

end)

if not vips_success then
    ngx.log(ngx.ERR, "Failed to disable libvips operations cache ", vips_error)
end

--mobile-detect
--
local mobile_detect_success, mobile_detect_error = pcall(function()
    mobile_detect = require "mobile-detect"
end)

if not mobile_detect_success then
    ngx.log(ngx.ERR, "Failed to load nginx mobile-detect plugin ", mobile_detect_error)
end
