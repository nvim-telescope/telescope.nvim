
line = "hello"
prompt = "h"
print(vim.inspect(vim.fn.systemlist(string.format(
  "echo '%s' | ~/tmp/fuzzy_test/target/debug/fuzzy_test '%s'",
  line,
  prompt
))))
