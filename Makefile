.PHONY: all env build clean quick fresh format

PROJECT = plazma
BUILD_DIR = build

all: clean env build

env:
	unset QT_QPA_PLATFORMTHEME
	unset QT_STYLE_OVERRIDE  
	unset QT_QUICK_CONTROLS_STYLE

build:
	mkdir -p $(BUILD_DIR)
	cmake -B $(BUILD_DIR)
	cmake --build $(BUILD_DIR)

quick:
	cmake --build $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

fresh:
	rm -rf tdlib

format:
	find . -name "*.c" -o -name "*.h" -o -name "*.cpp" | xargs clang-format -i