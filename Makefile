test:
	nvim --headless -c 'lua require("plenary.test_harness"):test_directory("busted", "./lua/tests/automated/")'

native: fzy_native

fzy_native: 
	mkdir -p build
	gcc -c -Wall -fpic -o ./build/fzy_match.o ./src/fzy/match.c
	gcc -shared -o build/libfzy.so ./build/fzy_match.o
