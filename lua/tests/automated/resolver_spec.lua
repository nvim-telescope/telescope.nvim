local eq = function(a, b)
  assert.are.same(a, b)
end

local resolve = require "telescope.config.resolve"

describe("telescope.config.resolve", function()
  describe("win_option", function()
    it("should resolve for percentages", function()
      local height_config = 0.8
      local opt = resolve.win_option(height_config)

      eq(height_config, opt.preview)
      eq(height_config, opt.prompt)
      eq(height_config, opt.results)
    end)

    it("should resolve for percetnages with default", function()
      local height_config = 0.8
      local opt = resolve.win_option(nil, height_config)

      eq(height_config, opt.preview)
      eq(height_config, opt.prompt)
      eq(height_config, opt.results)
    end)

    it("should resolve table values", function()
      local table_val = { "a" }
      local opt = resolve.win_option(nil, table_val)

      eq(table_val, opt.preview)
      eq(table_val, opt.prompt)
      eq(table_val, opt.results)
    end)

    it("should allow overrides for different wins", function()
      local prompt_override = { "a", prompt = "b" }
      local opt = resolve.win_option(prompt_override)
      eq("a", opt.preview)
      eq("a", opt.results)
      eq("b", opt.prompt)
    end)

    it("should allow overrides for all wins", function()
      local all_specified = { preview = "a", prompt = "b", results = "c" }
      local opt = resolve.win_option(all_specified)
      eq("a", opt.preview)
      eq("b", opt.prompt)
      eq("c", opt.results)
    end)

    it("should allow some specified with a simple default", function()
      local some_specified = { prompt = "b", results = "c" }
      local opt = resolve.win_option(some_specified, "a")
      eq("a", opt.preview)
      eq("b", opt.prompt)
      eq("c", opt.results)
    end)
  end)

  describe("resolve_height/width", function()
    eq(10, resolve.resolve_height(0.1)(nil, 24, 100))
    eq(2, resolve.resolve_width(0.1)(nil, 24, 100))

    eq(10, resolve.resolve_width(10)(nil, 24, 100))
    eq(24, resolve.resolve_width(50)(nil, 24, 100))
  end)
end)
