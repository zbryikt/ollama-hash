require! <[@plotdb/args os fs path]>

result = args meta: base: alias: \b, type: \string, desc: "homedir where .ollama locates in", required: false

home = result?options?b or os.homedir!

# 路徑設定
base-path = path.join home, '.ollama/models'
manifest-path = path.join base-path, 'manifests/registry.ollama.ai/library'
blobs-path = path.join base-path, 'blobs'

unless fs.exists-sync manifest-path
  console.log "❌ 找不到路徑: #{manifest-path}"
  process.exit 1

# 標題列
header = "#{( 'Model Name' + ' ' * 30 ).slice 0, 30} | #{( 'Size' + ' ' * 8 ).slice 0, 8} | #{( 'Param' + ' ' * 7 ).slice 0, 7} | #{( 'MoE' + ' ' * 5 ).slice 0, 5} | #{'Blob ID (First 30)'}"
console.log header
console.log "-" * 95

scan = (dir) ->
  items = fs.readdir-sync dir
  for item in items
    full-path = path.join dir, item
    if fs.stat-sync(full-path).is-directory!
      scan full-path
    else
      try
        data = JSON.parse fs.read-file-sync full-path, 'utf8'
        
        # 尋找模型主體 (GGUF)
        model-layer = data.layers?find (l) -> (l.mediaType?includes 'model') or (l.mediaType?includes 'layer.v1')
        config-layer = data.layers?find (l) -> l.mediaType?includes 'config'
        
        if model-layer
          rel-name = path.relative manifest-path, full-path
          name = rel-name.replace /\//g, ':'
          size = (model-layer.size / (1024^3)).toFixed(2) + "G"
          p-size = "N/A"; is-moe = "NO"

          if config-layer
            blob-path = path.join blobs-path, config-layer.digest.replace ':', '-'
            if fs.exists-sync blob-path
              config = JSON.parse fs.read-file-sync blob-path, 'utf8'
              info = config.model_info or {}
              params = info['general.parameter_count'] or config.parameters
              if params => p-size = if typeof params == 'number' then (params / 1e9).toFixed(1) + "B" else params
              if info['llama.expert_count'] or info['moe.expert_count'] => is-moe = "YES"

          # 取得檔案 ID 並截斷至 30 字元
          file-id = (model-layer.digest.replace ':', '-')
          short-id = file-id.slice 0, 30
          
          # 格式化輸出
          console.log "#{(name + ' ' * 30).slice 0, 30} | #{(size + ' ' * 8).slice 0, 8} | #{(p-size + ' ' * 7).slice 0, 7} | #{(is-moe + ' ' * 5).slice 0, 5} | #{short-id}"
      catch e
        continue

scan manifest-path
