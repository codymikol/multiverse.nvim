local json = {}

function json.encode(val)
  return vim.fn.json_encode(val)
end

function json.decode(str)
  return vim.fn.json_decode(str)
end

return json
