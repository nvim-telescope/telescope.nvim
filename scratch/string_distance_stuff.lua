
local string_distance = require('telescope.algos.string_distance')

print(string_distance("hello", "help"))
print(string_distance("hello", "hello"))
print(string_distance("hello", "asdf"))

