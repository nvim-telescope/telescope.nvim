// source: https://raw.githubusercontent.com/jhawthorn/fzy/master/src/match.h
#ifndef MATCH_H
#define MATCH_H MATCH_H

#include <math.h>

typedef double score_t;
#define SCORE_MAX INFINITY
#define SCORE_MIN -INFINITY

#define MATCH_MAX_LEN 1024

int has_match(const char *needle, const char *haystack, int is_case_sensitive);
score_t match_positions(const char *needle, const char *haystack, u_int32_t *positions, int is_case_sensitive);
score_t match(const char *needle, const char *haystack, int is_case_sensitive);

#endif
