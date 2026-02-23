cmake_minimum_required(VERSION 3.16.0)

set(PROJECT_VERSION "0.0.1")
string(REPLACE "." ";" VERSION_LIST ${PROJECT_VERSION})
list(GET VERSION_LIST 0 PROJECT_VERSION_MAJOR)
list(GET VERSION_LIST 1 PROJECT_VERSION_MINOR)
list(GET VERSION_LIST 2 PROJECT_VERSION_PATCH)

set(CMAKE_AUTOMOC ON) 

set(ECM_MIN_VERSION "6.21.0")

# set(CMAKE_CXX_CLANG_TIDY "clang-tidy;--extra-arg=-Wno-unknown-argument")

# find_package(Td 1.8.60 REQUIRED)
include(/usr/local/lib/cmake/Td/TdStaticTargets.cmake)
find_package(ECM ${ECM_MIN_VERSION} REQUIRED NO_MODULE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH})
include(ECMSetupVersion)

ecm_setup_version(${PROJECT_VERSION}
    VARIABLE_PREFIX PLAZMA
    VERSION_HEADER ${CMAKE_CURRENT_BINARY_DIR}/version.h
)

project(plazma)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 REQUIRED COMPONENTS Core Widgets Qml Quick)

qt_add_resources(RESOURCES src/resources.qrc)


file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.h")
add_executable(plazma ${SOURCES} ${RESOURCES})

target_include_directories(plazma PRIVATE ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})

target_link_libraries(plazma Qt6::Widgets Qt6::Core Qt6::Qml Qt6::Quick Td::TdStatic)