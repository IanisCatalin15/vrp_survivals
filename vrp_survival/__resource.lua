resource_manifest_version "44febabe-d386-4d18-afbe-5e627f4af937"

dependency "vrp"

ui_page "UI/index.html"

server_script {
    "@vrp/lib/utils.lua",
	"vrp_s.lua"
}

client_script {
	"@vrp/lib/utils.lua",
	'client.lua'
}

files {
    "cfg.lua",
    "UI/index.html",
    "UI/script.js",
    "UI/styles.css"
}
