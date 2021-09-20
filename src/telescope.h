#ifndef _TELESCOPE_H_
#define _TELESCOPE_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

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

tele_linked_list_t *tele_list_create(size_t track_at);
void tele_list_free(tele_linked_list_t *list);

tele_node_t *tele_list_append(tele_linked_list_t *list, int32_t item,
                              double score);
void tele_list_prepend(tele_linked_list_t *list, int32_t item, double score);

void tele_list_place_after(tele_linked_list_t *list, size_t index,
                           tele_node_t *node, int32_t item, double score);
void tele_list_place_before(tele_linked_list_t *list, size_t index,
                            tele_node_t *node, int32_t item, double score);

#endif
