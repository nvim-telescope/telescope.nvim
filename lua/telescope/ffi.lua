local ffi = require "ffi"

local library_path = (function()
  local dirname = string.sub(debug.getinfo(1).source, 2, #"/ffi.lua" * -1)
  if package.config:sub(1, 1) == "\\" then
    return dirname .. "../../build/libtelescope.dll"
  else
    return dirname .. "../../build/libtelescope.so"
  end
end)()
local native = ffi.load(library_path)

if not __Telescope_FFI_DEFINED then
  __Telescope_FFI_DEFINED = true
  ffi.cdef [[
typedef struct {
  int32_t idx;
  double score;
} tele_container;

typedef struct tele_node_s tele_node_t;
struct tele_node_s {
  tele_node_t *next;
  tele_node_t *prev;
  tele_container item;
};
typedef struct {
  tele_node_t *head;
  tele_node_t *tail;
  tele_node_t *_tracked_node;
  size_t len;
  size_t track_at;
} tele_linked_list_t;

tele_linked_list_t *tele_list_create(size_t);
void tele_list_free(tele_linked_list_t *);

tele_node_t *tele_list_append(tele_linked_list_t *, int32_t, double);
void tele_list_prepend(tele_linked_list_t *, int32_t, double);

void tele_list_place_after(tele_linked_list_t *, size_t, tele_node_t *, int32_t,
                           double);
void tele_list_place_before(tele_linked_list_t *, size_t, tele_node_t *,
                            int32_t, double);
]]
end

return native
