# -*- mode: cmake; -*-
# - osquery macro definitions
#
# Remove boilerplate code for linking the osquery core dependent libs
# compiling and handling static or dynamic (run time load) libs.

# osquery-specific helper macros
macro(LOG_PLATFORM NAME)
  set(LINK "https://github.com/facebook/osquery/issues/2169")
  LOG("Welcome to the redesigned v1.8.0 osquery build system!")
  LOG("For migration and details please see: ${ESC}[1m${LINK}${ESC}[m")
  LOG("Building for platform ${ESC}[36;1m${NAME} (${OSQUERY_BUILD_PLATFORM}, ${OSQUERY_BUILD_DISTRO})${ESC}[m")
  LOG("Building osquery version ${ESC}[36;1m ${OSQUERY_BUILD_VERSION} sdk ${OSQUERY_BUILD_SDK_VERSION}${ESC}[m")
endmacro(LOG_PLATFORM)

macro(LOG_LIBRARY NAME PATH)
  set(CACHE_NAME "LOG_LIBRARY_${NAME}")
  if(NOT DEFINED ${CACHE_NAME} OR NOT ${${CACHE_NAME}})
    set(${CACHE_NAME} TRUE CACHE BOOL "Write log line for ${NAME} library.")
    set(BUILD_POSITION -1)
    string(FIND "${PATH}" "${CMAKE_BINARY_DIR}" BUILD_POSITION)
    string(FIND "${PATH}" "NOTFOUND" NOTFOUND_POSITION)
    if(${NOTFOUND_POSITION} GREATER 0)
      WARNING_LOG("Could not find library: ${NAME}")
    else()
      if(${BUILD_POSITION} EQUAL 0)
        string(LENGTH "${CMAKE_BINARY_DIR}" BUILD_DIR_LENGTH)
        string(SUBSTRING "${PATH}" ${BUILD_DIR_LENGTH} -1 LIB_PATH)
        LOG("Found osquery-built library ${ESC}[32m${LIB_PATH}${ESC}[m")
      else()
        LOG("Found library ${ESC}[32m${PATH}${ESC}[m")
      endif()
    endif()
  endif()
endmacro(LOG_LIBRARY)

macro(SET_OSQUERY_COMPILE TARGET)
  set(OPTIONAL_FLAGS ${ARGN})
  list(LENGTH OPTIONAL_FLAGS NUM_OPTIONAL_FLAGS)
  if(${NUM_OPTIONAL_FLAGS} GREATER 0)
    set_target_properties(${TARGET} PROPERTIES COMPILE_FLAGS "${OPTIONAL_FLAGS}")
  endif()
endmacro(SET_OSQUERY_COMPILE)

macro(ADD_DEFAULT_LINKS TARGET ADDITIONAL)
  if(DEFINED ENV{OSQUERY_BUILD_SHARED})
    target_link_libraries(${TARGET} libosquery_shared)
    if(${ADDITIONAL})
      target_link_libraries(${TARGET} libosquery_additional_shared)
    endif()
    if(DEFINED ENV{FAST})
      target_link_libraries(${TARGET} "-Wl,-rpath,${CMAKE_BINARY_DIR}/osquery")
    endif()
  else()
    TARGET_OSQUERY_LINK_WHOLE(${TARGET} libosquery)
    if(${ADDITIONAL})
      TARGET_OSQUERY_LINK_WHOLE(${TARGET} libosquery_additional)
    endif()
  endif()
endmacro()

macro(ADD_OSQUERY_PYTHON_TEST TEST_NAME SOURCE)
  add_test(NAME python_${TEST_NAME}
    COMMAND ${PYTHON_EXECUTABLE} "${CMAKE_SOURCE_DIR}/tools/tests/${SOURCE}"
      --build "${CMAKE_BINARY_DIR}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/tools/tests/")
endmacro(ADD_OSQUERY_PYTHON_TEST)

# Add a static or dynamic link to libosquery.a (the core library)
macro(ADD_OSQUERY_LINK_CORE LINK)
  ADD_OSQUERY_LINK(TRUE ${LINK} ${ARGN})
endmacro(ADD_OSQUERY_LINK_CORE)

# Add a static or dynamic link to libosquery_additional.a (the non-sdk library)
macro(ADD_OSQUERY_LINK_ADDITIONAL LINK)
  ADD_OSQUERY_LINK(FALSE ${LINK} ${ARGN})
endmacro(ADD_OSQUERY_LINK_ADDITIONAL)

# Core/non core link helping macros (tell the build to link ALL).
macro(ADD_OSQUERY_LINK IS_CORE LINK)
  if(${IS_CORE})
    ADD_OSQUERY_LINK_INTERNAL("${LINK}" "${ARGN}" OSQUERY_LINKS)
  elseif(NOT OSQUERY_BUILD_SDK_ONLY)
    ADD_OSQUERY_LINK_INTERNAL("${LINK}" "${ARGN}" OSQUERY_ADDITIONAL_LINKS)
  endif()
endmacro(ADD_OSQUERY_LINK)

macro(ADD_OSQUERY_LINK_INTERNAL LINK LINK_PATHS LINK_SET)
  set(LINK_PATHS_RELATIVE
    "${BUILD_DEPS}/lib"
    ${LINK_PATHS}
    ${OS_LIB_DIRS}
    "$ENV{HOME}"
  )
  set(LINK_PATHS_SYSTEM
    ${LINK_PATHS}
    "${BUILD_DEPS}/legacy/lib"
    # Allow the build to search the default deps include for libz.
    "${BUILD_DEPS}/lib"
    ${OS_LIB_DIRS}
  )

  if(NOT "${LINK}" MATCHES "(^[-/].*)")
    string(REPLACE " " ";" ITEMS "${LINK}")
    foreach(ITEM ${ITEMS})
      if(NOT DEFINED ${${ITEM}_library})
        if("${ITEM}" MATCHES "(^lib.*)" OR "${ITEM}" MATCHES "(.*lib$)" OR DEFINED ENV{BUILD_LINK_SHARED})
          # Use a system-provided library
          set(ITEM_SYSTEM TRUE)
        else()
          set(ITEM_SYSTEM FALSE)
        endif()
        if(NOT ${ITEM_SYSTEM})
          find_library("${ITEM}_library"
            NAMES "${ITEM}.lib" "lib${ITEM}.lib" "lib${ITEM}.a" "${ITEM}" HINTS ${LINK_PATHS_RELATIVE})
        else()
          find_library("${ITEM}_library"
            NAMES "${ITEM}.lib" "lib${ITEM}.lib" "lib${ITEM}.so" "lib${ITEM}.dylib" "${ITEM}.so" "${ITEM}.dylib" "${ITEM}"
            HINTS ${LINK_PATHS_SYSTEM})
        endif()
        LOG_LIBRARY(${ITEM} "${${ITEM}_library}")
        if("${${ITEM}_library}" STREQUAL "${ITEM}_library-NOTFOUND")
          WARNING_LOG("Dependent library '${ITEM}' not found")
          list(APPEND ${LINK_SET} ${ITEM})
        else()
          list(APPEND ${LINK_SET} "${${ITEM}_library}")
        endif()
      endif()
      if("${${ITEM}_library}" MATCHES "/usr/local/lib.*")
        WARNING_LOG("Dependent library '${ITEM}' installed locally (beware!)")
      endif()
    endforeach()
  else()
    list(APPEND ${LINK_SET} ${LINK})
  endif()
  set(${LINK_SET} "${${LINK_SET}}" PARENT_SCOPE)
endmacro(ADD_OSQUERY_LINK_INTERNAL)

# Add a test and sources for components in libosquery.a (the core library)
macro(ADD_OSQUERY_TEST_CORE)
  ADD_OSQUERY_TEST(TRUE ${ARGN})
endmacro(ADD_OSQUERY_TEST_CORE)

# Add a test and sources for components in libosquery_additional.a (the non-sdk library)
macro(ADD_OSQUERY_TEST_ADDITIONAL)
  ADD_OSQUERY_TEST(FALSE ${ARGN})
endmacro(ADD_OSQUERY_TEST_ADDITIONAL)

# Core/non core test names and sources macros.
macro(ADD_OSQUERY_TEST IS_CORE)
  if(NOT DEFINED ENV{SKIP_TESTS} AND (${IS_CORE} OR NOT OSQUERY_BUILD_SDK_ONLY))
    if(${IS_CORE})
      list(APPEND OSQUERY_TESTS ${ARGN})
      set(OSQUERY_TESTS ${OSQUERY_TESTS} PARENT_SCOPE)
    else()
      list(APPEND OSQUERY_ADDITIONAL_TESTS ${ARGN})
      set(OSQUERY_ADDITIONAL_TESTS ${OSQUERY_ADDITIONAL_TESTS} PARENT_SCOPE)
    endif()
  endif()
endmacro(ADD_OSQUERY_TEST)

macro(ADD_OSQUERY_TABLE_TEST)
  if(NOT DEFINED ENV{SKIP_TESTS} AND NOT OSQUERY_BUILD_SDK_ONLY)
    list(APPEND OSQUERY_TABLES_TESTS ${ARGN})
    set(OSQUERY_TABLES_TESTS ${OSQUERY_TABLES_TESTS} PARENT_SCOPE)
  endif()
endmacro(ADD_OSQUERY_TABLE_TEST)

# Add kernel test macro.
macro(ADD_OSQUERY_KERNEL_TEST)
  if(NOT DEFINED ENV{SKIP_TESTS})
    list(APPEND OSQUERY_KERNEL_TESTS ${ARGN})
    set(OSQUERY_KERNEL_TESTS ${OSQUERY_KERNEL_TESTS} PARENT_SCOPE)
  endif()
endmacro(ADD_OSQUERY_KERNEL_TEST)

# Add benchmark macro.
macro(ADD_OSQUERY_BENCHMARK)
  if(NOT DEFINED ENV{SKIP_TESTS})
    list(APPEND OSQUERY_BENCHMARKS ${ARGN})
    set(OSQUERY_BENCHMARKS ${OSQUERY_BENCHMARKS} PARENT_SCOPE)
  endif()
endmacro(ADD_OSQUERY_BENCHMARK)

# Add kernel benchmark macro.
macro(ADD_OSQUERY_KERNEL_BENCHMARK)
  if(NOT DEFINED ENV{SKIP_TESTS})
    list(APPEND OSQUERY_KERNEL_BENCHMARKS ${ARGN})
    set(OSQUERY_KERNEL_BENCHMARKS ${OSQUERY_KERNEL_BENCHMARKS} PARENT_SCOPE)
  endif()
endmacro(ADD_OSQUERY_KERNEL_BENCHMARK)

# Add sources to libosquery.a (the core library)
macro(ADD_OSQUERY_LIBRARY_CORE TARGET)
  ADD_OSQUERY_LIBRARY(TRUE ${TARGET} ${ARGN})
endmacro(ADD_OSQUERY_LIBRARY_CORE)

# Add sources to libosquery_additional.a (the non-sdk library)
macro(ADD_OSQUERY_LIBRARY_ADDITIONAL TARGET)
  ADD_OSQUERY_LIBRARY(FALSE ${TARGET} ${ARGN})
endmacro(ADD_OSQUERY_LIBRARY_ADDITIONAL)

# Core/non core lists of target source files.
macro(ADD_OSQUERY_LIBRARY IS_CORE TARGET)
  if(${IS_CORE} OR NOT OSQUERY_BUILD_SDK_ONLY)
    add_library(${TARGET} OBJECT ${ARGN})
    add_dependencies(${TARGET} osquery_extensions)
    # TODO(#1985): For Windows, ignore the -static compiler flag
    if(WINDOWS)
      SET_OSQUERY_COMPILE(${TARGET} "${CXX_COMPILE_FLAGS} /EHsc")
    else()
      SET_OSQUERY_COMPILE(${TARGET} "${CXX_COMPILE_FLAGS}") # -static
    endif()
    if(${IS_CORE})
      list(APPEND OSQUERY_SOURCES $<TARGET_OBJECTS:${TARGET}>)
      set(OSQUERY_SOURCES ${OSQUERY_SOURCES} PARENT_SCOPE)
    else()
      list(APPEND OSQUERY_ADDITIONAL_SOURCES $<TARGET_OBJECTS:${TARGET}>)
      set(OSQUERY_ADDITIONAL_SOURCES ${OSQUERY_ADDITIONAL_SOURCES} PARENT_SCOPE)
    endif()
  endif()
endmacro(ADD_OSQUERY_LIBRARY TARGET)

# Add sources to libosquery.a (the core library)
macro(ADD_OSQUERY_OBJCXX_LIBRARY_CORE TARGET)
  ADD_OSQUERY_OBJCXX_LIBRARY(TRUE ${TARGET} ${ARGN})
endmacro(ADD_OSQUERY_OBJCXX_LIBRARY_CORE)

# Add sources to libosquery_additional.a (the non-sdk library)
macro(ADD_OSQUERY_OBJCXX_LIBRARY_ADDITIONAL TARGET)
  ADD_OSQUERY_OBJCXX_LIBRARY(FALSE ${TARGET} ${ARGN})
endmacro(ADD_OSQUERY_OBJCXX_LIBRARY_ADDITIONAL)

# Core/non core lists of target source files compiled as ObjC++.
macro(ADD_OSQUERY_OBJCXX_LIBRARY IS_CORE TARGET)
  if(${IS_CORE} OR NOT OSQUERY_BUILD_SDK_ONLY)
    add_library(${TARGET} OBJECT ${ARGN})
    add_dependencies(${TARGET} osquery_extensions)
    # TODO(#1985): For Windows, ignore the -static compiler flag
    if(WINDOWS)
      SET_OSQUERY_COMPILE(${TARGET} "${CXX_COMPILE_FLAGS} ${OBJCXX_COMPILE_FLAGS} /EHsc")
    else()
      SET_OSQUERY_COMPILE(${TARGET} "${CXX_COMPILE_FLAGS} ${OBJCXX_COMPILE_FLAGS}")
    endif()
    if(${IS_CORE})
      list(APPEND OSQUERY_SOURCES $<TARGET_OBJECTS:${TARGET}>)
      set(OSQUERY_SOURCES ${OSQUERY_SOURCES} PARENT_SCOPE)
    else()
      list(APPEND OSQUERY_ADDITIONAL_SOURCES $<TARGET_OBJECTS:${TARGET}>)
      set(OSQUERY_ADDITIONAL_SOURCES ${OSQUERY_SOURCES} PARENT_SCOPE)
    endif()
  endif()
endmacro(ADD_OSQUERY_OBJCXX_LIBRARY TARGET)

macro(ADD_OSQUERY_EXTENSION TARGET)
  add_executable(${TARGET} ${ARGN})
  TARGET_OSQUERY_LINK_WHOLE(${TARGET} libosquery)
  set_target_properties(${TARGET} PROPERTIES COMPILE_FLAGS "${CXX_COMPILE_FLAGS}")
  set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME "${TARGET}.ext")
endmacro(ADD_OSQUERY_EXTENSION)

macro(ADD_OSQUERY_MODULE TARGET)
  add_library(${TARGET} SHARED ${ARGN})
  if(NOT FREEBSD AND NOT WINDOWS)
    target_link_libraries(${TARGET} dl)
  endif()

  add_dependencies(${TARGET} libosquery)
  if(APPLE)
    target_link_libraries(${TARGET} "-undefined dynamic_lookup")
  elseif(LINUX)
    # This could implement a similar LINK_MODULE for gcc, libc, and libstdc++.
    # However it is only provided as an example for unit testing.
    target_link_libraries(${TARGET} "-static-libstdc++")
  endif()
  set_target_properties(${TARGET} PROPERTIES COMPILE_FLAGS "${CXX_COMPILE_FLAGS}")
  set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME ${TARGET})
endmacro(ADD_OSQUERY_MODULE)

# Helper to abstract OS/Compiler whole linking.
if(WINDOWS)
macro(TARGET_OSQUERY_LINK_WHOLE TARGET OSQUERY_LIB)
  target_link_libraries(${TARGET} "${OS_WHOLELINK_PRE}$<TARGET_FILE_NAME:${OSQUERY_LIB}>")
  target_link_libraries(${TARGET} ${OSQUERY_LIB})
endmacro(TARGET_OSQUERY_LINK_WHOLE)
else()
macro(TARGET_OSQUERY_LINK_WHOLE TARGET OSQUERY_LIB)
  target_link_libraries(${TARGET} "${OS_WHOLELINK_PRE}")
  target_link_libraries(${TARGET} ${OSQUERY_LIB})
  target_link_libraries(${TARGET} "${OS_WHOLELINK_POST}")
endmacro(TARGET_OSQUERY_LINK_WHOLE)
endif()

set(GLOBAL PROPERTY AMALGAMATE_TARGETS "")
macro(GET_GENERATION_DEPS BASE_PATH)
  # Depend on the generation code.
  set(GENERATION_DEPENDENCIES "")
  file(GLOB TABLE_FILES_TEMPLATES "${BASE_PATH}/osquery/tables/templates/*.in")
  file(GLOB CODEGEN_PYTHON_FILES "${BASE_PATH}/tools/codegen/*.py")
  set(GENERATION_DEPENDENCIES
    "${CODEGEN_PYTHON_FILES}"
    "${BASE_PATH}/specs/blacklist"
  )
  list(APPEND GENERATION_DEPENDENCIES ${TABLE_FILES_TEMPLATES})
endmacro()

# Find and generate table plugins from .table syntax
macro(GENERATE_TABLES TABLES_PATH)
  # Get all matching files for all platforms.
  set(TABLES_SPECS "${TABLES_PATH}/specs")
  set(TABLE_CATEGORIES "")
  if(APPLE)
    list(APPEND TABLE_CATEGORIES "darwin" "posix")
  elseif(FREEBSD)
    list(APPEND TABLE_CATEGORIES "freebsd" "posix")
  elseif(LINUX)
    list(APPEND TABLE_CATEGORIES "linux" "posix")
    if(REDHAT_BASED)
      list(APPEND TABLE_CATEGORIES "centos")
    elseif(DEBIAN_BASED)
      list(APPEND TABLE_CATEGORIES "ubuntu")
    endif()
  elseif(WINDOWS)
    list(APPEND TABLE_CATEGORIES "windows")
  else()
    message( FATAL_ERROR "Unknown platform detected, cannot generate tables")
  endif()

  file(GLOB TABLE_FILES "${TABLES_SPECS}/*.table")
  set(TABLE_FILES_FOREIGN "")
  file(GLOB ALL_CATEGORIES RELATIVE "${TABLES_SPECS}" "${TABLES_SPECS}/*")
  foreach(CATEGORY ${ALL_CATEGORIES})
    if(IS_DIRECTORY "${TABLES_SPECS}/${CATEGORY}" AND NOT "${CATEGORY}" STREQUAL "utility")
      file(GLOB TABLE_FILES_PLATFORM "${TABLES_SPECS}/${CATEGORY}/*.table")
      list(FIND TABLE_CATEGORIES "${CATEGORY}" INDEX)
      if(${INDEX} EQUAL -1)
        # Append inner tables to foreign
        list(APPEND TABLE_FILES_FOREIGN ${TABLE_FILES_PLATFORM})
      else()
        # Append inner tables to TABLE_FILES.
        list(APPEND TABLE_FILES ${TABLE_FILES_PLATFORM})
      endif()
    endif()
  endforeach()

  # Generate a set of targets, comprised of table spec file.
  get_property(TARGETS GLOBAL PROPERTY AMALGAMATE_TARGETS)
  set(NEW_TARGETS "")
  foreach(TABLE_FILE ${TABLE_FILES})
    list(FIND TARGETS "${TABLE_FILE}" INDEX)
    if (${INDEX} EQUAL -1)
      # Do not set duplicate targets.
      list(APPEND NEW_TARGETS "${TABLE_FILE}")
    endif()
  endforeach()
  set_property(GLOBAL PROPERTY AMALGAMATE_TARGETS "${NEW_TARGETS}")
  set_property(GLOBAL PROPERTY AMALGAMATE_FOREIGN_TARGETS "${TABLE_FILES_FOREIGN}")
endmacro()

macro(GENERATE_UTILITIES TABLES_PATH)
  file(GLOB TABLE_FILES_UTILITY "${TABLES_PATH}/specs/utility/*.table")
  set_property(GLOBAL APPEND PROPERTY AMALGAMATE_TARGETS "${TABLE_FILES_UTILITY}")
endmacro(GENERATE_UTILITIES)

macro(GENERATE_TABLE TABLE_FILE FOREIGN NAME BASE_PATH OUTPUT)
  GET_GENERATION_DEPS(${BASE_PATH})
  set(TABLE_FILE_GEN "${TABLE_FILE}")
  string(REGEX REPLACE
    ".*/specs.*/(.*)\\.table"
    "${CMAKE_BINARY_DIR}/generated/tables_${NAME}/\\1.cpp"
    TABLE_FILE_GEN
    ${TABLE_FILE_GEN}
  )

  add_custom_command(
    OUTPUT "${TABLE_FILE_GEN}"
    COMMAND "${PYTHON_EXECUTABLE}"
      "${BASE_PATH}/tools/codegen/gentable.py"
      "${FOREIGN}"
      "${TABLE_FILE}"
      "${TABLE_FILE_GEN}"
    DEPENDS ${TABLE_FILE} ${GENERATION_DEPENDENCIES}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )

  list(APPEND ${OUTPUT} "${TABLE_FILE_GEN}")
endmacro(GENERATE_TABLE)

macro(AMALGAMATE BASE_PATH NAME OUTPUT)
  GET_GENERATION_DEPS(${BASE_PATH})
  if("${NAME}" STREQUAL "foreign")
    get_property(TARGETS GLOBAL PROPERTY AMALGAMATE_FOREIGN_TARGETS)
    set(FOREIGN "--foreign")
  else()
    get_property(TARGETS GLOBAL PROPERTY AMALGAMATE_TARGETS)
  endif()

  set(GENERATED_TARGETS "")
  
  foreach(TARGET ${TARGETS})
    GENERATE_TABLE("${TARGET}" "${FOREIGN}" "${NAME}" "${BASE_PATH}" GENERATED_TARGETS)
  endforeach()

  # Include the generated folder in make clean.
  set_directory_properties(PROPERTY
    ADDITIONAL_MAKE_CLEAN_FILES "${CMAKE_BINARY_DIR}/generated")

  # Append all of the code to a single amalgamation.
  set(AMALGAMATION_FILE_GEN "${CMAKE_BINARY_DIR}/generated/${NAME}_amalgamation.cpp")
  add_custom_command(
    OUTPUT ${AMALGAMATION_FILE_GEN}
    COMMAND "${PYTHON_EXECUTABLE}"
      "${BASE_PATH}/tools/codegen/amalgamate.py"
      "${FOREIGN}"
      "${BASE_PATH}/tools/codegen/"
      "${CMAKE_BINARY_DIR}/generated"
      "${NAME}"
    DEPENDS ${GENERATED_TARGETS} ${GENERATION_DEPENDENCIES}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )

  set(${OUTPUT} ${AMALGAMATION_FILE_GEN})
endmacro(AMALGAMATE)

function(JOIN VALUES GLUE OUTPUT)
  string(REPLACE ";" "${GLUE}" _TMP_STR "${VALUES}")
  set(${OUTPUT} "${_TMP_STR}" PARENT_SCOPE)
endfunction(JOIN)
