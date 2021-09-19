#include "telescope.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>

// ENTRYMANAGER THINGS
static fzf_node_t *create_node(int item) {
  fzf_node_t *node = (fzf_node_t *)malloc(sizeof(fzf_node_t));
  node->item = item;
  node->next = NULL;
  node->prev = NULL;
  return node;
}

fzf_linked_list_t *fzf_list_create(size_t track_at) {
  fzf_linked_list_t *list =
      (fzf_linked_list_t *)malloc(sizeof(fzf_linked_list_t));
  list->len = 0;
  list->track_at = track_at;
  list->head = NULL;
  list->tail = NULL;
  list->_tracked_node = NULL;
  return list;
}

void fzf_list_free(fzf_linked_list_t *list) {
  if (list->head) {
    fzf_node_t *curr = list->head;
    while (curr != NULL) {
      fzf_node_t *tmp = curr->next;
      free(curr);
      curr = tmp;
    }
  }

  free(list);
}

fzf_node_t *fzf_list_append(fzf_linked_list_t *list, int item) {
  ++list->len;
  fzf_node_t *node = create_node(item);

  if (list->head == NULL) {
    list->head = node;
  }

  if (list->tail) {
    list->tail->next = node;
    node->prev = list->tail;
  }

  list->tail = node;
  if (list->len == list->track_at) {
    list->_tracked_node = node;
  }

  return node;
}

void fzf_list_prepend(fzf_linked_list_t *list, int item) {
  ++list->len;
  fzf_node_t *node = create_node(item);

  if (list->tail == NULL) {
    list->tail = node;
  }

  if (list->head) {
    list->head->prev = node;
    node->next = list->head;
  }
  list->head = node;
  if (list->len == list->track_at) {
    list->_tracked_node = list->tail;
  } else if (list->len > list->track_at) {
    list->_tracked_node = list->_tracked_node->prev;
  }
}

void fzf_list_place_after(fzf_linked_list_t *list, size_t index,
                          fzf_node_t *node, int item) {
  ++list->len;
  fzf_node_t *new_node = create_node(item);

  assert(node->prev != node);
  assert(node->next != node);

  if (list->tail == node) {
    list->tail = new_node;
  }

  new_node->prev = node;
  new_node->next = node->next;
  node->next = new_node;

  if (new_node->prev) {
    new_node->prev->next = new_node;
  }

  if (new_node->next) {
    new_node->next->prev = new_node;
  }

  if (index == list->track_at) {
    list->_tracked_node = new_node;
  } else if (index < list->track_at) {
    if (list->len == list->track_at) {
      list->_tracked_node = list->tail;
    } else if (list->len > list->track_at) {
      list->_tracked_node = list->_tracked_node->prev;
    }
  }
}

void fzf_list_place_before(fzf_linked_list_t *list, size_t index,
                           fzf_node_t *node, int item) {
  ++list->len;
  fzf_node_t *new_node = create_node(item);

  assert(node->prev != node);
  assert(node->next != node);

  if (list->head == node) {
    list->head = new_node;
  }

  new_node->prev = node->prev;
  new_node->next = node;
  node->prev = new_node;

  if (new_node->prev) {
    new_node->prev->next = new_node;
  }
  if (new_node->next) {
    new_node->next->prev = new_node;
  }

  if (index == list->track_at - 1) {
    list->_tracked_node = node;
  } else if (index < list->track_at) {
    if (list->len == list->track_at) {
      list->_tracked_node = list->tail;
    } else if (list->len > list->track_at) {
      list->_tracked_node = list->_tracked_node->prev;
    }
  }
}
