local punycode = require "weserv.helpers.punycode"
local ffi = require "ffi"
local tonumber = tonumber
local str_byte = string.byte
local str_format = string.format
local tbl_concat = table.concat
local ngx_re_match = ngx.re.match

-- Always call ffi.cdef() on the top-level scope of your own
-- Lua module files.
ffi.cdef [[
    int close(int fd);
    int mkstemp(char* template);
]]

--- Utils module
-- @module utils
local utils = {}

-- The orientation tag for this image. An int from 1 - 8 using the standard
-- exif/tiff meanings.
local VIPS_META_ORIENTATION = "orientation"

-- The name we use to attach an ICC profile. The file read and write
-- operations for TIFF, JPEG, PNG and others use this item of metadata to
-- attach and save ICC profiles. The profile is updated by the
-- vips_icc_transform() operations.
local VIPS_META_ICC_NAME = "icc-profile-data"

-- Only alphanumerics, the percent character (prevents us from encoding
-- already percent-encoded URIs), the special characters "-._~!$&'()*+,;=",
-- and reserved characters used for delimiters purposes may be used
-- unencoded within a URI. The regex (in accordance with the naming
-- convention of RFC 3986) is as follows:
-- *( unreserved / pct-encoded / gen-delims / sub-delims )
-- See: https://tools.ietf.org/html/rfc3986#section-2.2
local REGEX_DISALLOWED_CHARS = "[^%w%-%._~%%!%$&'%(%)%*%+,;=:/%?#@]"

--- Are pixel values in this image 16-bit integer?
-- @param interpretation The VipsInterpretation
-- @return Boolean indicating if the pixel values in this image are 16-bit
function utils.is_16_bit(interpretation)
    return interpretation == "rgb16" or interpretation == "grey16"
end

--- Does this image have an embedded profile?
-- @param image The source image.
-- @return Boolean indicating if this image have an embedded profile.
function utils.has_profile(image)
    return image:get_typeof(VIPS_META_ICC_NAME) ~= 0
end

--- Does this image have an alpha channel?
-- Uses colour space interpretation with number of channels to guess this.
-- @return Boolean indicating if this image has an alpha channel.
function utils.has_alpha(image)
    return image:bands() == 2 or
            (image:bands() == 4 and
                    image:interpretation() ~= "cmyk") or
            image:bands() > 4
end

--- Return the image alpha maximum. Useful for combining alpha bands. scRGB
-- images are 0 - 1 for image data, but the alpha is 0 - 255.
-- @param interpretation The VipsInterpretation.
-- @return The image alpha maximum.
function utils.maximum_image_alpha(interpretation)
    return utils.is_16_bit(interpretation) and 65535 or 255
end

--- Get EXIF Orientation of image, if any.
-- @param image The source image.
-- @return EXIF Orientation.
function utils.exif_orientation(image)
    return image:get_typeof(VIPS_META_ORIENTATION) ~= 0 and image:get(VIPS_META_ORIENTATION) or 0
end

--- Creates a file with a unique filename, in the specified directory.
-- @param dir The directory where the temporary filename will be created.
-- @param prefix The prefix of the generated temporary filename.
-- @return The new temporary filename (with path), or nil on failure.
function utils.tempname(dir, prefix)
    local C = ffi.C

    local template = str_format("%s/%sXXXXXX", dir, prefix)
    -- Use length + 1 to reserve room for the zero terminator.
    local tempname = ffi.new("char[?]", #template + 1, template)
    local fd = C.mkstemp(tempname)
    if fd == -1 then
        return nil
    end

    local result = ffi.string(tempname)
    local rv = C.close(fd)

    return rv ~= 0 and nil or result
end

--- Clean URI.
-- @param uri The URI.
-- @return Cleaned URI.
function utils.clean_uri(uri)
    -- Check for HTTPS origin hosts
    if uri:sub(1, 4) == "ssl:" then
        uri = "https://" .. uri:sub(5):gsub("^/*", "")
    end

    -- If the URI is schemaless (i.e. //example.com), append 'https:'
    if uri:sub(1, 2) == "//" then
        uri = "https:" .. uri
    end

    -- If only host is given (i.e. example.com), append 'http://'
    if uri:sub(1, 5) ~= "http:" and
            uri:sub(1, 6) ~= "https:" then
        uri = "http://" .. uri:gsub("^/*", "")
    end

    -- Remove the 'errorredirect' GET variable, if any
    return uri:gsub("[?&]errorredirect=[^&]+", "")
end

--- Percent-encode characters from a URI path or query string.
-- @param char The char to percent-encode.
-- @return The percent-encoded char.
function utils.percent_encode(char)
    return str_format("%%%02X", str_byte(char))
end

--- Determines a "canonical" equivalent of a URI path.
-- Assumes that the URI path is already unescaped.
-- @param path The URI path to canonicalise.
-- @return The canonicalised path.
function utils.canonicalise_path(path)
    -- Should we ignore the query?
    local ignore_query = false

    local segments = {}
    for path_segment, fragment in path:gmatch("/([^/#]*)(#?)") do
        segments[#segments + 1] = path_segment:gsub(REGEX_DISALLOWED_CHARS, utils.percent_encode)
        -- Fragment identifier must be removed from the path.
        if fragment == "#" then
            ignore_query = true
            break
        end
    end
    local len = #segments
    if len == 0 then
        return "/"
    end
    segments[0] = ""
    segments = tbl_concat(segments, "/", 0, len)
    return segments, ignore_query
end

--- Determines a "canonical" equivalent of a query string.
-- Assumes that the query string is already unescaped.
-- @param path The query string to canonicalise.
-- @return The canonicalised query string.
function utils.canonicalise_query_string(query)
    local q = {}
    for key, val in query:gmatch("([^&=]+)=?([^&]*)") do
        key = key:gsub(REGEX_DISALLOWED_CHARS, utils.percent_encode)
        val = val:gsub(REGEX_DISALLOWED_CHARS, utils.percent_encode)
        q[#q + 1] = key .. "=" .. val
    end
    query = tbl_concat(q, "&")

    -- Fragment identifier must be removed from the query string.
    local frag_pos = query:find("#", 1, true)
    if frag_pos then
        query = query:sub(1, frag_pos - 1)
    end

    return query
end

--- Parse URI.
-- @param uri The URI.
-- @return Parsed URI.
function utils.parse_uri(uri)
    local m = ngx_re_match(utils.clean_uri(uri), [[^(http[s]?)://([^:/\?]+)(?::(\d+))?([^\?]*)\??(.*)]], "jo")

    if not m then
        return nil, "Unable to parse URL"
    else
        local punycode_idn, err = punycode.domain_encode(m[2])
        if not punycode_idn then
            return nil, err
        end

        m[2] = punycode_idn

        if m[3] then
            m[3] = tonumber(m[3])
        else
            if m[1] == "https" then
                m[3] = 443
            else
                m[3] = 80
            end
        end

        local path, ignore_query = utils.canonicalise_path(m[4])
        m[4] = path

        if ignore_query then
            m[5] = ""
        else
            m[5] = utils.canonicalise_query_string(m[5])
        end

        return m, nil
    end
end

--- Resolve an explicit angle.
-- If an angle is provided, it is converted to a valid 90/180/270deg rotation.
-- For example, `-450` will produce a 270deg rotation.
-- @param angle Angle of rotation, must be a multiple of 90.
-- @return The resolved rotation.
function utils.resolve_angle_rotation(angle)
    angle = tonumber(angle)

    if angle == nil then
        return 0
    end

    -- Check if is not a multiple of 90
    if angle % 90 ~= 0 then
        return 0
    end

    -- Calculate the rotation for the given angle that is a multiple of 90
    return angle % 360
end

--- Calculate the angle of rotation and need-to-flip for the given exif orientation
-- and parameters.
-- @param image The source image.
-- @param params Parameters array.
-- @return rotation, flip, flop
function utils.resolve_rotation_and_flip(image, params)
    local rotate = utils.resolve_angle_rotation(params["or"])
    local flip = params.flip ~= nil
    local flop = params.flop ~= nil

    local exif_orientation = utils.exif_orientation(image)
    if exif_orientation == 6 then
        rotate = rotate + 90
    elseif exif_orientation == 3 then
        rotate = rotate + 180
    elseif exif_orientation == 8 then
        rotate = rotate + 270
    elseif exif_orientation == 2 then -- flop 1
        flop = true
    elseif exif_orientation == 7 then -- flip 6
        flip = true
        rotate = rotate + 90
    elseif exif_orientation == 4 then -- flop 3
        flop = true
        rotate = rotate + 180
    elseif exif_orientation == 5 then -- flip 8
        flip = true
        rotate = rotate + 270
    end

    rotate = rotate % 360

    return rotate, flip, flop
end

--- Determine image extension from the name of the load operation.
-- @param loader The name of the load operation.
-- @return The image extension.
function utils.determine_image_extension(loader)
    local extension = "unknown"

    if loader == "VipsForeignLoadJpegFile" then
        extension = "jpg"
    elseif loader == "VipsForeignLoadPng" then
        extension = "png"
    elseif loader == "VipsForeignLoadWebpFile" then
        extension = "webp"
    elseif loader == "VipsForeignLoadTiffFile" then
        extension = "tiff"
    elseif loader == "VipsForeignLoadGifFile" then
        extension = "gif"
    elseif loader == "VipsForeignLoadSvgFile" then
        extension = "svg"
    end

    return extension
end

--- Convert bytes to human readable format.
-- @param bytes The number of bytes.
-- @return The readable format of the bytes.
function utils.format_bytes(bytes)
    local kilobyte = 1024
    local megabyte = kilobyte * 1024
    local gigabyte = megabyte * 1024
    local terabyte = gigabyte * 1024

    if bytes >= 0 and bytes < kilobyte then
        return bytes .. " B"
    elseif bytes >= kilobyte and bytes < megabyte then
        return str_format("%.2f", bytes / kilobyte):gsub("%.?0+$", "") .. " KB"
    elseif bytes >= megabyte and bytes < gigabyte then
        return str_format("%.2f", bytes / megabyte):gsub("%.?0+$", "") .. " MB"
    elseif bytes >= gigabyte and bytes < terabyte then
        return str_format("%.2f", bytes / gigabyte):gsub("%.?0+$", "") .. " GB"
    elseif bytes >= terabyte then
        return str_format("%.2f", bytes / terabyte):gsub("%.?0+$", "") .. " TB"
    end
end

--- Calculate the border of image and border size.
-- @param image The source image.
-- @param params Parameters array.
-- @return 
function utils.image_has_border(image, params)
  
end

return utils