from pathlib import Path
import subprocess

something = subprocess.run(["rg", "--files"], capture_output=True)
files = something.stdout.decode('utf-8').split('\n')
files.sort()

user_input = "lua finders/async"

REJECTED = -1.0
GOOD = 2.0

def is_subset(item, prompt) -> float:
    prompt_chars = set()
    for c in prompt:
        prompt_chars.add(c)

    item_chars = set()
    for c in item:
        item_chars.add(c)

    return prompt_chars.issubset(item_chars)

def proportion_of_contained_letters(prompt, item) -> float:
    prompt_chars = set()
    for c in prompt:
        prompt_chars.add(c)

    item_chars = set()
    for c in item:
        item_chars.add(c)

    contained = 0
    for prompt_char in prompt_chars:
        if prompt_char in item_chars:
            contained += 1

    return contained / len(prompt_chars)

def jerry_match(prompt: str, item) -> float:
    p = Path(item)

    split = prompt.split(" ", maxsplit=2)
    language = split[0]
    filter = split[1]

    if p.suffix != "." + language:
        return REJECTED

    if filter in item:
        return GOOD

    proprotion = proportion_of_contained_letters(filter, item)
    if proprotion < 0.75:
        return REJECTED

    return proprotion

def score_results(prompt, files):
    results = []
    for f in files:
        score = jerry_match(prompt, f)
        if score == REJECTED:
            continue

        results.append({'score': score, 'item': f})


    results.sort(key=lambda x: x["score"], reverse=True)
    return results

while True:
    i = input("Filter Phrase > ")
    if not i:
        break

    results = score_results(i, files)
    for result in results[:10]:
        print(result["item"])

# x = [1, 2, 3, 4, 4, 2, 1, 3]
# print(x)
# print(set(x))

# x = {1, 2, 3}
# y = {1}
#
# print("x.issubset(y)", x.issubset(y))
# print("y.issubset(x)", y.issubset(x))
