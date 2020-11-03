// source: https://github.com/jhawthorn/fzy/blob/master/src/match.c

#include <ctype.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <float.h>
#include <math.h>
#include <stdlib.h>

#include "match.h"
#include "bonus.h"

#include "config.h"

int has_match(const char *needle, const char *haystack, int is_case_sensitive) {
	while (*needle) {
		char nch = *needle++;

		const char accept[3] = {nch, is_case_sensitive ? 0 : toupper(nch), 0};

		if (!(haystack = strpbrk(haystack, accept))) {
			return 0;
		}
		haystack++;
	}
	return 1;
}

#define SWAP(x, y, T) do { T SWAP = x; x = y; y = SWAP; } while (0)

#define max(a, b) (((a) > (b)) ? (a) : (b))

struct match_struct {
	int needle_len;
	int haystack_len;

	const char *needle;
	const char *haystack;

	char lower_needle[MATCH_MAX_LEN];
	char lower_haystack[MATCH_MAX_LEN];

	score_t match_bonus[MATCH_MAX_LEN];
};

static void precompute_bonus(const char *haystack, score_t *match_bonus) {
	/* Which positions are beginning of words */
	char last_ch = '/';
	for (int i = 0; haystack[i]; i++) {
		char ch = haystack[i];
		match_bonus[i] = COMPUTE_BONUS(last_ch, ch);
		last_ch = ch;
	}
}

static void setup_match_struct(struct match_struct *match, const char *needle, const char *haystack, int is_case_sensitive) {
	match->needle_len = strlen(needle);
	match->haystack_len = strlen(haystack);

	if (match->haystack_len > MATCH_MAX_LEN || match->needle_len > match->haystack_len) {
		return;
	}

	if (is_case_sensitive) {
		match->needle = needle;
		match->haystack = haystack;
	} else {
		for (int i = 0; i < match->needle_len; i++)
			match->lower_needle[i] = tolower(needle[i]);

		for (int i = 0; i < match->haystack_len; i++)
			match->lower_haystack[i] = tolower(haystack[i]);

		match->needle = match->lower_needle;
		match->haystack = match->lower_haystack;
	}

	precompute_bonus(haystack, match->match_bonus);
}

static inline void match_row(const struct match_struct *match, int row, score_t *curr_D, score_t *curr_M, const score_t *last_D, const score_t *last_M) {
	int n = match->needle_len;
	int m = match->haystack_len;
	int i = row;

	const char *needle = match->needle;
	const char *haystack = match->haystack;
	const score_t *match_bonus = match->match_bonus;

	score_t prev_score = SCORE_MIN;
	score_t gap_score = i == n - 1 ? SCORE_GAP_TRAILING : SCORE_GAP_INNER;

	for (int j = 0; j < m; j++) {
		if (needle[i] == haystack[j]) {
			score_t score = SCORE_MIN;
			if (!i) {
				score = (j * SCORE_GAP_LEADING) + match_bonus[j];
			} else if (j) { /* i > 0 && j > 0*/
				score = max(
						last_M[j - 1] + match_bonus[j],

						/* consecutive match, doesn't stack with match_bonus */
						last_D[j - 1] + SCORE_MATCH_CONSECUTIVE);
			}
			curr_D[j] = score;
			curr_M[j] = prev_score = max(score, prev_score + gap_score);
		} else {
			curr_D[j] = SCORE_MIN;
			curr_M[j] = prev_score = prev_score + gap_score;
		}
	}
}

score_t match(const char *needle, const char *haystack, int is_case_sensitive) {
	if (!*needle)
		return SCORE_MIN;

	struct match_struct match;
	setup_match_struct(&match, needle, haystack, is_case_sensitive);

	int n = match.needle_len;
	int m = match.haystack_len;

	if (m > MATCH_MAX_LEN || n > m) {
		/*
		 * Unreasonably large candidate: return no score
		 * If it is a valid match it will still be returned, it will
		 * just be ranked below any reasonably sized candidates
		 */
		return SCORE_MIN;
	}
	// else if (n == m) {
	// 	/* Since this method can only be called with a haystack which
	// 	 * matches needle. If the lengths of the strings are equal the
	// 	 * strings themselves must also be equal (ignoring case).
	// 	 */
	// 	return SCORE_MAX;
	// }

	/*
	 * D[][] Stores the best score for this position ending with a match.
	 * M[][] Stores the best possible score at this position.
	 */
	score_t D[2][MATCH_MAX_LEN], M[2][MATCH_MAX_LEN];

	score_t *last_D, *last_M;
	score_t *curr_D, *curr_M;

	last_D = D[0];
	last_M = M[0];
	curr_D = D[1];
	curr_M = M[1];

	for (int i = 0; i < n; i++) {
		match_row(&match, i, curr_D, curr_M, last_D, last_M);

		SWAP(curr_D, last_D, score_t *);
		SWAP(curr_M, last_M, score_t *);
	}

	return last_M[m - 1];
}

score_t match_positions(const char *needle, const char *haystack, u_int32_t *positions, int is_case_sensitive) {
	if (!*needle)
		return SCORE_MIN;

	struct match_struct match;
	setup_match_struct(&match, needle, haystack, is_case_sensitive);

	int n = match.needle_len;
	int m = match.haystack_len;

	if (m > MATCH_MAX_LEN || n > m) {
		/*
		 * Unreasonably large candidate: return no score
		 * If it is a valid match it will still be returned, it will
		 * just be ranked below any reasonably sized candidates
		 */
		return SCORE_MIN;
	}
	// else if (n == m) {
	// 	/* Since this method can only be called with a haystack which
	// 	 * matches needle. If the lengths of the strings are equal the
	// 	 * strings themselves must also be equal (ignoring case).
	// 	 */
	// 	if (positions)
	// 		for (int i = 0; i < n; i++)
	// 			positions[i] = i;
	// 	return SCORE_MAX;
	// }

	/*
	 * D[][] Stores the best score for this position ending with a match.
	 * M[][] Stores the best possible score at this position.
	 */
	score_t (*D)[MATCH_MAX_LEN], (*M)[MATCH_MAX_LEN];
	M = malloc(sizeof(score_t) * MATCH_MAX_LEN * n);
	D = malloc(sizeof(score_t) * MATCH_MAX_LEN * n);

	score_t *last_D, *last_M;
	score_t *curr_D, *curr_M;

	for (int i = 0; i < n; i++) {
		curr_D = &D[i][0];
		curr_M = &M[i][0];

		match_row(&match, i, curr_D, curr_M, last_D, last_M);

		last_D = curr_D;
		last_M = curr_M;
	}

	/* backtrace to find the positions of optimal matching */
	if (positions) {
		int match_required = 0;
		for (int i = n - 1, j = m - 1; i >= 0; i--) {
			for (; j >= 0; j--) {
				/*
				 * There may be multiple paths which result in
				 * the optimal weight.
				 *
				 * For simplicity, we will pick the first one
				 * we encounter, the latest in the candidate
				 * string.
				 */
				if (D[i][j] != SCORE_MIN &&
				    (match_required || D[i][j] == M[i][j])) {
					/* If this score was determined using
					 * SCORE_MATCH_CONSECUTIVE, the
					 * previous character MUST be a match
					 */
					match_required =
					    i && j &&
					    M[i][j] == D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE;
					positions[i] = j--;
					break;
				}
			}
		}
	}

	score_t result = M[n - 1][m - 1];

	free(M);
	free(D);

	return result;
}
