CMAKE_COMMON_FLAGS ?= -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

CMAKE_DEBUG_FLAGS ?= -DUSERVER_SANITIZE='addr ub'
CMAKE_RELEASE_FLAGS ?=

CMAKE_RELEASE_FLAGS += -DCMAKE_BUILD_TYPE=Release $(CMAKE_COMMON_FLAGS)

CLANG_FORMAT ?= clang-format
DOCKER_COMPOSE ?= docker-compose

ifeq ($(KERNEL),Darwin)
CMAKE_COMMON_FLAGS += -DUSERVER_NO_WERROR=1 -DUSERVER_CHECK_PACKAGE_VERSIONS=0 \
  -DUSERVER_DOWNLOAD_PACKAGE_CRYPTOPP=1 \
  -DOPENSSL_ROOT_DIR=$(shell brew --prefix openssl) \
  -DUSERVER_PG_INCLUDE_DIR=$(shell pg_config --includedir) \
  -DUSERVER_PG_LIBRARY_DIR=$(shell pg_config --libdir) \
  -DUSERVER_PG_SERVER_LIBRARY_DIR=$(shell pg_config --pkglibdir) \
  -DUSERVER_PG_SERVER_INCLUDE_DIR=$(shell pg_config --includedir-server)
endif

.PHONY: format
format:
	find src -name '*pp' -type f | xargs $(CLANG_FORMAT) -i

.PHONY: --in-start
--in-start:
	cmake -B build $(CMAKE_RELEASE_FLAGS)
	cmake --build build -j$$(nproc) --target realmedium_sample
	cmake --install build -v --component realmedium_sample

	/home/user/.local/bin/realmedium_sample \
		--config /home/user/.local/etc/realmedium_sample/config.yaml \
		--config_vars /home/user/.local/etc/realmedium_sample/config_vars.docker.yaml


.PHONY: build
build:
	$(DOCKER_COMPOSE) build --no-cache

.PHONY: run
run:
	$(DOCKER_COMPOSE) up -d

.PHONY: start
start:
	$(DOCKER_COMPOSE) exec plazma-server make -- --in-start

.PHONY: restart
restart:
	$(DOCKER_COMPOSE) exec plazma-server pkill -f realmedium_sample || true
	$(DOCKER_COMPOSE) exec plazma-server make -- --in-start

#.PHONY: clean
#clean:
#	cmake --build build --target clean

.PHONY: dist-clean
dist-clean:
	rm -rf build
	rm -rf tests
	rm -rf tests/.pytest_cache

.PHONY: down
down:
	$(DOCKER_COMPOSE) down

