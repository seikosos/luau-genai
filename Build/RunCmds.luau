local process = require("@lune/process")
local LuneUtils = require("Lib/Libraries/LuneUtils")
local fs = require("@lune/fs")
local Run = LuneUtils.Run
local datetime = require("@lune/datetime")

print("Building: genai")

local projectFile = "genai.project.json"

local function fileExists(path)
    local ok, err = pcall(fs.readFile, path)
    return ok
end

if not fileExists(projectFile) then
    error("Project file not found: " .. projectFile)
end

print("Bundling genai...")
local spawn1 = Run("lune", {
    "run", "Build", "bundle",
    "input=" .. projectFile,
    "env-name=NF",
    "output=onemodule.lua"
}, false)

if not spawn1 then
    error("Bundle failed for genai")
end