#include "telescope.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

// ENTRYMANAGER THINGS
static tele_node_t *create_node(int32_t item, double score) {
  tele_node_t *node = (tele_node_t *)malloc(sizeof(tele_node_t));
  node->item = (tele_container){.idx = item, .score = score};
  node->next = NULL;
  node->prev = NULL;
  return node;
}

static tele_linked_list_t *tele_list_create(size_t track_at) {
  tele_linked_list_t *list =
      (tele_linked_list_t *)malloc(sizeof(tele_linked_list_t));
  list->len = 0;
  list->track_at = track_at;
  list->head = NULL;
  list->tail = NULL;
  list->_tracked_node = NULL;
  return list;
}

static void tele_list_free(tele_linked_list_t *list) {
  if (list->head) {
    tele_node_t *curr = list->head;
    while (curr != NULL) {
      tele_node_t *tmp = curr->next;
      free(curr);
      curr = tmp;
    }
  }

  free(list);
}

static tele_node_t *tele_list_append(tele_linked_list_t *list, int32_t item,
                                     double score) {
  ++list->len;
  tele_node_t *node = create_node(item, score);

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

static void tele_list_prepend(tele_linked_list_t *list, int32_t item,
                              double score) {
  ++list->len;
  tele_node_t *node = create_node(item, score);

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

static void tele_list_place_after(tele_linked_list_t *list, size_t index,
                                  tele_node_t *node, int32_t item,
                                  double score) {
  ++list->len;
  tele_node_t *new_node = create_node(item, score);

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

static void tele_list_place_before(tele_linked_list_t *list, size_t index,
                                   tele_node_t *node, int32_t item,
                                   double score) {
  ++list->len;
  tele_node_t *new_node = create_node(item, score);

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

tele_manager_t *tele_manager_create(size_t max_results) {
  tele_manager_t *manager = (tele_manager_t *)malloc(sizeof(tele_manager_t));
  manager->worst_acceptable_score = DBL_MAX;
  manager->max_results = max_results;
  manager->list = tele_list_create(max_results);
  return manager;
}

void tele_manager_free(tele_manager_t *manager) {
  tele_list_free(manager->list);
  free(manager);
}

int32_t tele_manager_add(tele_manager_t *manager, int32_t item, double score) {
  if (score >= manager->worst_acceptable_score) {
    tele_list_append(manager->list, item, score);
    return -1;
  }

  if (manager->list->len == 0) {
    tele_list_prepend(manager->list, item, score);
    // set_entry(picker, 1, entry, score)
    return 1;
  }

  size_t index = 1;
  for (tele_node_t *curr = manager->list->head; curr != NULL;
       curr = curr->next) {
    // TODO(conni2461): TIEBREAKER (we need ordinal lens)
    // TODO(conni2461): double == double is not correct
    if (curr->item.score > score) {
      tele_list_place_before(manager->list, index, curr, item, score);
      if (manager->list->_tracked_node) {
        manager->worst_acceptable_score =
            fmin(manager->worst_acceptable_score,
                 manager->list->_tracked_node->item.score);
      }
      // set_entry(picker, index, entry, score, true);
      return index;
    }

    if (index >= manager->max_results) {
      tele_list_append(manager->list, item, score);
      manager->worst_acceptable_score =
          fmin(manager->worst_acceptable_score, score);
      return -1;
    }

    ++index;
  }

  if (manager->list->len >= manager->max_results) {
    manager->worst_acceptable_score =
        fmin(manager->worst_acceptable_score, score);
  }

  tele_list_place_after(manager->list, manager->list->len + 1,
                        manager->list->tail, item, score);
  if (manager->list->_tracked_node) {
    manager->worst_acceptable_score =
        fmin(manager->worst_acceptable_score,
             manager->list->_tracked_node->item.score);
  }
  // set_entry(picker, index, entry, score, true);
  return manager->list->len;
}
