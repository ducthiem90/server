# Determine build (target) platform
INCLUDE (PlatformIntrospection)
TEST_FOR_SUPPORTED_PLATFORM (SUPPORTED_PLATFORM)
_DETERMINE_PLATFORM (CONFIG_PLATFORM)
_DETERMINE_ARCH (CONFIG_ARCH)
_DETERMINE_CPU_COUNT (CONFIG_CPU_COUNT)
SET (PLATFORM_FOLDER_NAME "linux")

IF (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  MESSAGE (STATUS "Setting build type to 'Release' as none was specified.")
  SET (CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
  SET_PROPERTY (CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
ENDIF ()
MARK_AS_ADVANCED (CMAKE_INSTALL_PREFIX)

FIND_PACKAGE (Git)
SET (CONFIG_VERSION_GIT_REV "0")
SET (CONFIG_VERSION_GIT_HASH "N/A")
IF (GIT_FOUND)
	EXEC_PROGRAM ("${GIT_EXECUTABLE}" "${PROJECT_SOURCE_DIR}" ARGS rev-list --all --count OUTPUT_VARIABLE CONFIG_VERSION_GIT_REV)
	EXEC_PROGRAM ("${GIT_EXECUTABLE}" "${PROJECT_SOURCE_DIR}" ARGS rev-parse --verify --short HEAD OUTPUT_VARIABLE CONFIG_VERSION_GIT_HASH)
ENDIF ()
CONFIGURE_FILE ("${PROJECT_SOURCE_DIR}/version.tmpl" "${PROJECT_SOURCE_DIR}/version.h")

SET (BOOST_ROOT_PATH "/opt/boost" CACHE STRING "Path to Boost")
SET (ENV{BOOST_ROOT} "${BOOST_ROOT_PATH}")
SET (Boost_USE_DEBUG_LIBS ON)
SET (Boost_USE_RELEASE_LIBS OFF)
SET (Boost_USE_STATIC_LIBS ON)
FIND_PACKAGE (Boost 1.66.0 EXACT COMPONENTS system thread chrono filesystem log locale regex date_time coroutine REQUIRED)

SET (FFMPEG_ROOT_PATH "/opt/ffmpeg/lib/pkgconfig" CACHE STRING "Path to FFMPEG")
SET (ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:${FFMPEG_ROOT_PATH}")
FIND_PACKAGE (FFmpeg REQUIRED)
LINK_DIRECTORIES( ${FFMPEG_LIBRARY_DIRS} )

FIND_PACKAGE (OpenGL REQUIRED)
FIND_PACKAGE (JPEG REQUIRED)
FIND_PACKAGE (FreeImage REQUIRED)
FIND_PACKAGE (Freetype REQUIRED)
FIND_PACKAGE (GLEW REQUIRED)
FIND_PACKAGE (TBB REQUIRED)
FIND_PACKAGE (SndFile REQUIRED)
FIND_PACKAGE (OpenAL REQUIRED)
FIND_PACKAGE (GLFW REQUIRED)
FIND_PACKAGE (SFML 2 COMPONENTS graphics window system REQUIRED)

SET (BOOST_INCLUDE_PATH "${Boost_INCLUDE_DIRS}")
SET (TBB_INCLUDE_PATH "${TBB_INCLUDE_DIRS}")
SET (GLEW_INCLUDE_PATH "${GLEW_INCLUDE_DIRS}")
SET (SFML_INCLUDE_PATH "${SFML_INCLUDE_DIR}")
SET (FREETYPE_INCLUDE_PATH "${FREETYPE_INCLUDE_DIRS}")
SET (FFMPEG_INCLUDE_PATH "${FFMPEG_INCLUDE_DIRS}")
SET (ASMLIB_INCLUDE_PATH "${EXTERNAL_INCLUDE_PATH}")
SET (FREEIMAGE_INCLUDE_PATH "${FreeImage_INCLUDE_DIRS}")

SET_PROPERTY (GLOBAL PROPERTY USE_FOLDERS ON)

ADD_DEFINITIONS (-DSFML_STATIC)
ADD_DEFINITIONS (-DUNICODE)
ADD_DEFINITIONS (-D_UNICODE)
ADD_DEFINITIONS (-DGLEW_NO_GLU)
ADD_DEFINITIONS (-D__NO_INLINE__) # Needed for precompiled headers to work
ADD_DEFINITIONS (-DBOOST_NO_SWPRINTF) # swprintf on Linux seems to always use , as decimal point regardless of C-locale or C++-locale
ADD_DEFINITIONS (-DTBB_USE_CAPTURED_EXCEPTION=1)
ADD_DEFINITIONS (-DNDEBUG) # Needed for precompiled headers to work

ADD_COMPILE_OPTIONS (-std=c++14) # Needed for precompiled headers to work
ADD_COMPILE_OPTIONS (-O3) # Needed for precompiled headers to work
ADD_COMPILE_OPTIONS (-Wno-deprecated-declarations -Wno-write-strings -Wno-terminate -Wno-multichar -Wno-cpp)
ADD_COMPILE_OPTIONS (-msse3)
ADD_COMPILE_OPTIONS (-mssse3)
ADD_COMPILE_OPTIONS (-msse4.1)
ADD_COMPILE_OPTIONS (-fnon-call-exceptions) # Allow signal handler to throw exception

IF (POLICY CMP0045)
	CMAKE_POLICY (SET CMP0045 OLD)
ENDIF ()

SET (CASPARCG_MODULE_INCLUDE_STATEMENTS "" CACHE INTERNAL "")
SET (CASPARCG_MODULE_INIT_STATEMENTS "" CACHE INTERNAL "")
SET (CASPARCG_MODULE_UNINIT_STATEMENTS "" CACHE INTERNAL "")
SET (CASPARCG_MODULE_COMMAND_LINE_ARG_INTERCEPTORS_STATEMENTS "" CACHE INTERNAL "")
SET (CASPARCG_MODULE_PROJECTS "" CACHE INTERNAL "")
SET (CASPARCG_RUNTIME_DEPENDENCIES "" CACHE INTERNAL "")

INCLUDE (PrecompiledHeader)

FUNCTION (casparcg_add_include_statement HEADER_FILE_TO_INCLUDE)
	SET (CASPARCG_MODULE_INCLUDE_STATEMENTS "${CASPARCG_MODULE_INCLUDE_STATEMENTS}"
			"#include <${HEADER_FILE_TO_INCLUDE}>"
			CACHE INTERNAL ""
	)
ENDFUNCTION ()

FUNCTION (casparcg_add_init_statement INIT_FUNCTION_NAME NAME_TO_LOG)
	SET (CASPARCG_MODULE_INIT_STATEMENTS "${CASPARCG_MODULE_INIT_STATEMENTS}"
			"	${INIT_FUNCTION_NAME}(dependencies)\;"
			"	CASPAR_LOG(info) << L\"Initialized ${NAME_TO_LOG} module.\"\;"
			""
			CACHE INTERNAL ""
	)
ENDFUNCTION ()

FUNCTION (casparcg_add_uninit_statement UNINIT_FUNCTION_NAME)
	SET (CASPARCG_MODULE_UNINIT_STATEMENTS
			"	${UNINIT_FUNCTION_NAME}()\;"
			"${CASPARCG_MODULE_UNINIT_STATEMENTS}"
			CACHE INTERNAL ""
	)
ENDFUNCTION ()

FUNCTION (casparcg_add_command_line_arg_interceptor INTERCEPTOR_FUNCTION_NAME)
	set(CASPARCG_MODULE_COMMAND_LINE_ARG_INTERCEPTORS_STATEMENTS "${CASPARCG_MODULE_COMMAND_LINE_ARG_INTERCEPTORS_STATEMENTS}"
			"	if (${INTERCEPTOR_FUNCTION_NAME}(argc, argv))"
			"		return true\;"
			""
			CACHE INTERNAL ""
	)
ENDFUNCTION ()

FUNCTION (casparcg_add_module_project PROJECT)
	SET (CASPARCG_MODULE_PROJECTS "${CASPARCG_MODULE_PROJECTS}" "${PROJECT}" CACHE INTERNAL "")
ENDFUNCTION ()

# http://stackoverflow.com/questions/7172670/best-shortest-way-to-join-a-list-in-cmake
FUNCTION (join_list VALUES GLUE OUTPUT)
	STRING (REGEX REPLACE "([^\\]|^);" "\\1${GLUE}" _TMP_STR "${VALUES}")
	STRING (REGEX REPLACE "[\\](.)" "\\1" _TMP_STR "${_TMP_STR}") #fixes escaping
	SET (${OUTPUT} "${_TMP_STR}" PARENT_SCOPE)
ENDFUNCTION ()

FUNCTION (casparcg_add_runtime_dependency FILE_TO_COPY)
	SET (CASPARCG_RUNTIME_DEPENDENCIES "${CASPARCG_RUNTIME_DEPENDENCIES}" "${FILE_TO_COPY}" CACHE INTERNAL "")
ENDFUNCTION ()
