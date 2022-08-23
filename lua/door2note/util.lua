local U = {}

function U.echo(chunk)
  chunk[1][1] = ('[refresh.nvim] %s'):format(chunk[1][1])
  chunk[#chunk][1] = chunk[#chunk][1]:gsub('\n*$', '')
  vim.api.nvim_echo(chunk, true, {})
end

function U.msg(msg, ...)
  U.echo { { msg:format(...), 'None' } }
end

function U.err(msg, ...)
  U.echo { { msg:format(...), 'ErrorMsg' } }
end

return U
