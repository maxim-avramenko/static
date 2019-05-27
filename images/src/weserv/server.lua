local utils = require "weserv.helpers.utils"
local response = require "weserv.helpers.response"
local tonumber = tonumber
local os_remove = os.remove
local ngx_encode_base64 = ngx.encode_base64
local math_floor = math.floor
local str_format = string.format
local str_len = string.len

--- Server module.
-- @module server
local server = {}

--- Is the extension allowed to pass on to the selected save operation?
-- @param extension The extension.
-- @return Boolean indicating the extension is allowed.
function server.is_extension_allowed(extension)
    return extension == "jpg" or
            extension == "tiff" or
            extension == "gif" or
            extension == "png" or
            extension == "webp" or
            extension == "ico"
end

--- Resolve the quality for the provided extension.
-- For a PNG image it returns the zlib compression level.
-- @param params Parameters array.
-- @param extension Image extension.
-- @return The resolved quality.
function server.resolve_quality(params, extension)
    local quality = 0

    if extension == "jpg" or extension == "webp" or extension == "tiff" then
        quality = 85

        local given_quality = tonumber(params.q)

        -- Quality may not be nil and needs to be in the range of 1 - 100
        if given_quality ~= nil and given_quality >= 1 and given_quality <= 100 then
            quality = math_floor(given_quality + 0.5)
        end
    end

    if extension == "png" then
        quality = 6

        local given_level = tonumber(params.level)

        -- zlib compression level may not be nil and needs to be in the range of 0 - 9
        if given_level ~= nil and given_level >= 0 and given_level <= 9 then
            quality = math_floor(given_level + 0.5)
        end
    end

    return quality
end

--- Get the options for a specified extension to pass on to
-- the selected save operation.
-- @param params Parameters array.
-- @param extension Image extension.
-- @return Any options to pass on to the selected save operation.
function server.get_buffer_options(params, extension)
    local buffer_options = {}

    if extension == "jpg" then
        -- Strip all metadata (EXIF, XMP, IPTC)
        buffer_options.strip = true
        -- Set quality (default is 85)
        buffer_options.Q = server.resolve_quality(params, extension)
        -- Use progressive (interlace) scan, if necessary
        buffer_options.interlace = params.il ~= nil
        -- Enable libjpeg's Huffman table optimiser
        buffer_options.optimize_coding = true
    elseif extension == "png" then
        -- Use progressive (interlace) scan, if necessary
        buffer_options.interlace = params.il ~= nil
        -- zlib compression level (default is 6)
        buffer_options.compression = server.resolve_quality(params, extension)
        -- Use adaptive row filtering (default is none)
        if params.filter ~= nil then
            -- VIPS_FOREIGN_PNG_FILTER_ALL
            buffer_options.filter = 0xF8
        else
            -- VIPS_FOREIGN_PNG_FILTER_NONE
            buffer_options.filter = 0x08
        end
    elseif extension == "webp" then
        -- Strip all metadata (EXIF, XMP, IPTC)
        buffer_options.strip = true
        -- Set quality (default is 85)
        buffer_options.Q = server.resolve_quality(params, extension)
        -- Set quality of alpha layer to 100
        buffer_options.alpha_q = 100
    elseif extension == "tiff" then
        -- Strip all metadata (EXIF, XMP, IPTC)
        buffer_options.strip = true
        -- Set quality (default is 85)
        buffer_options.Q = server.resolve_quality(params, extension)
        -- Set the tiff compression
        buffer_options.compression = "jpeg"
    elseif extension == "gif" then
        -- Set the format option to hint the file type.
        buffer_options.format = extension
    end

    return buffer_options
end

--- Determines the appropriate mime type (from list of hardcoded values)
-- using the provided extension.
-- @param extension Image extension.
-- @return The mime type.
function server.extension_to_mime_type(extension)
    local mime_types = {
        gif = "image/gif",
        jpg = "image/jpeg",
        png = "image/png",
        webp = "image/webp",
        tiff = "image/tiff",
    }

    return mime_types[extension]
end

--- Output the final image.
-- @param image The final image.
-- @param args The URL query arguments.
function server.output(image, args)
    -- Determine image extension from the libvips loader
    local extension = utils.determine_image_extension(args.loader)

    if args.output ~= nil and server.is_extension_allowed(args.output) then
        extension = args.output
    elseif (args.has_alpha and extension ~= "png" and extension ~= "webp" and extension ~= "gif")
            or not server.is_extension_allowed(extension) then
        -- We force the extension to PNG if:
        -- - The image has alpha and doesn't have the right extension to output alpha.
        --   (useful for masking and letterboxing)
        -- - The input extension is not allowed for output.
        extension = "png"
    end

    --  Write the image to a formatted string
    local buffer = image:write_to_buffer("." .. extension, server.get_buffer_options(args, extension))

    if args.path == nil or ngx.var.path == nil then
        os_remove(args.tmp_file_name)
    end

    local mime_type = server.extension_to_mime_type(extension)

    if args.encoding ~= nil and args.encoding == "base64" then
        local base64_str = str_format("data:%s;base64,%s", mime_type, ngx_encode_base64(buffer))

        return response.send_HTTP_OK(base64_str, {
            ["Content-Type"] = "text/plain",
        })
    else
        local file_name = "image." .. extension

        -- https://tools.ietf.org/html/rfc2183
        if args.filename ~= nil and
                args.filename ~= "" and
                not args.filename:match("%W") and
                str_len(args.filename .. "." .. extension) <= 78 then
            file_name = args.filename .. "." .. extension
        end

        local content_disposition = (args.download ~= nil and "attachment; " or "inline; ") .. "filename=" .. file_name

        return response.send_HTTP_OK(buffer, {
            ["Content-Type"] = mime_type,
            ["Content-Disposition"] = content_disposition,
        })
    end
end

return server