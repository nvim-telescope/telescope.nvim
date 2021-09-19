#ifndef _TELESCOPE_H_
#define _TELESCOPE_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

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

#endif
