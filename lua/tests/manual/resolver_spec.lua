RELOAD('telescope')

local resolve = require('telescope.config.resolve')

local eq = function(a, b)
  if a ~= b then
    error(string.format(
      "Expected a == b, got: %s and %s", vim.inspect(a), vim.inspect(b)
    ))
  end
end

local opt = nil

local height_config = 0.8
opt = resolve.win_option(height_config)

eq(height_config, opt.preview)
eq(height_config, opt.prompt)
eq(height_config, opt.results)

opt = resolve.win_option(nil, height_config)

eq(height_config, opt.preview)
eq(height_config, opt.prompt)
eq(height_config, opt.results)

local table_val = {'a'}
opt = resolve.win_option(nil, table_val)
eq(table_val, opt.preview)
eq(table_val, opt.prompt)
eq(table_val, opt.results)

local prompt_override = {'a', prompt = 'b'}
opt = resolve.win_option(prompt_override)
eq('a', opt.preview)
eq('a', opt.results)
eq('b', opt.prompt)

local all_specified = {preview = 'a', prompt = 'b', results = 'c'}
opt = resolve.win_option(all_specified)
eq('a', opt.preview)
eq('b', opt.prompt)
eq('c', opt.results)

local some_specified = {prompt = 'b', results = 'c'}
opt = resolve.win_option(some_specified, 'a')
eq('a', opt.preview)
eq('b', opt.prompt)
eq('c', opt.results)


eq(10, resolve.resolve_height(0.1)(nil, 24, 100))
eq(2, resolve.resolve_width(0.1)(nil, 24, 100))

eq(10, resolve.resolve_width(10)(nil, 24, 100))
eq(24, resolve.resolve_width(50)(nil, 24, 100))

-- local true_table = {true}
-- opt = resolve.win_option(some_specified, 'a')
-- eq('a', opt.preview)
-- eq('b', opt.prompt)
-- eq('c', opt.results)

print("DONE!")
