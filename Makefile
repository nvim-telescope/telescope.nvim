CFLAGS = -Wall -Werror -fpic -std=gnu99
MODE ?= -O3

ifeq ($(OS),Windows_NT)
    MKD = -mkdir
    RM = cmd /C rmdir /Q /S
    CC = gcc
    TARGET := libtelescope.dll
else
    MKD = mkdir -p
    RM = rm -rf
    TARGET := libtelescope.so
endif

all: build/$(TARGET)

build/$(TARGET): src/telescope.c src/telescope.h
	$(MKD) build
	$(CC) $(MODE) $(CFLAGS) -shared src/telescope.c -o build/$(TARGET)

.PHONY: lint clangdhappy clean test docgen

ntest:
	nvim --headless --noplugin -u test/minrc.vim -c "PlenaryBustedDirectory test/ { minimal_init = './test/minrc.vim' }"

clangdhappy:
	compiledb make

clean:
	$(RM) build

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

lint:
	luacheck lua/telescope

docgen:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'
