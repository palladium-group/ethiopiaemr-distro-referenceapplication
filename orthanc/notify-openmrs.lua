-- Notifies OpenMRS when a DICOM study becomes stable (all images received).
-- Reads endpoint/credentials from environment variables set in docker-compose.
--
-- Uses OnStableStudy rather than OnStoredInstance so the endpoint is called
-- once per study (after StableAge seconds of inactivity), not once per slice.

local endpoint = os.getenv("OPENMRS_NOTIFICATION_ENDPOINT")
local user     = os.getenv("OPENMRS_NOTIFICATION_USER")
local password = os.getenv("OPENMRS_NOTIFICATION_PASSWORD")

-- Minimal base64 encoder (equivalent of JS btoa) for building the
-- Authorization: Basic header.
local function btoa(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x)
    local r, byte = '', x:byte()
    for i = 8, 1, -1 do r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return b:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function OnStableStudy(studyId, tags, metadata)
  if not endpoint or endpoint == "" then
    print("Orthanc-OpenMRS: OPENMRS_NOTIFICATION_ENDPOINT not set, skipping")
    return
  end

  local accessionNumber = tags["AccessionNumber"]
  if not accessionNumber or accessionNumber == "" then
    print("Orthanc-OpenMRS: No AccessionNumber for study " .. studyId .. ", skipping")
    return
  end

  local url  = endpoint .. "/" .. accessionNumber .. "/fulfillerdetails"
  local body = DumpJson({ fulfillerStatus = "IN_PROGRESS", fulfillerComment = "Images acquired" })

  local headers = { ["Content-Type"] = "application/json" }
  if user and user ~= "" then
    headers["Authorization"] = "Basic " .. btoa((user or "") .. ":" .. (password or ""))
  end

  local ok, err = pcall(function()
    HttpPost(url, body, headers)
  end)

  if ok then
    print("Orthanc-OpenMRS: Notified OpenMRS — accessionNumber=" .. accessionNumber)
  else
    print("Orthanc-OpenMRS: Notification failed — accessionNumber=" .. accessionNumber .. " error=" .. tostring(err))
  end
end