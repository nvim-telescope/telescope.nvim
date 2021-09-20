#ifndef _TELESCOPE_H_
#define _TELESCOPE_H_

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

typedef struct {
  size_t max_results;
  double worst_acceptable_score;
  tele_linked_list_t *list;
} tele_manager_t;

tele_manager_t *tele_manager_create(size_t max_results);
void tele_manager_free(tele_manager_t *manager);
int32_t tele_manager_add(tele_manager_t *manager, int32_t item, double score);

#endif
