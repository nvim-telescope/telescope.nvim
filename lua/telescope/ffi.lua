local ffi = require "ffi"

local library_path = (function()
  local dirname = string.sub(debug.getinfo(1).source, 2, #"/fzf_telescope.lua" * -1)
  if package.config:sub(1, 1) == "\\" then
    return dirname .. "../build/libtelescope.dll"
  else
    return dirname .. "../build/libtelescope.so"
  end
end)()
local native = ffi.load(library_path)

if not __Telescope_FFI_DEFINED then
  __Telescope_FFI_DEFINED = true
  ffi.cdef [[
typedef struct fzf_node_s fzf_node_t;
struct fzf_node_s {
  fzf_node_t *next;
  fzf_node_t *prev;
  int item;
};
typedef struct {
  fzf_node_t *head;
  fzf_node_t *tail;
  fzf_node_t *_tracked_node;
  size_t len;
  size_t track_at;
} fzf_linked_list_t;

fzf_linked_list_t *fzf_list_create(size_t track_at);
void fzf_list_free(fzf_linked_list_t *list);

fzf_node_t *fzf_list_append(fzf_linked_list_t *list, int item);
void fzf_list_prepend(fzf_linked_list_t *list, int item);

void fzf_list_place_after(fzf_linked_list_t *list, size_t index,
                          fzf_node_t *node, int item);
void fzf_list_place_before(fzf_linked_list_t *list, size_t index,
                           fzf_node_t *node, int item);
]]
end

return native
