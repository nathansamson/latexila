cmake_minimum_required (VERSION 2.6.4)

project ("latexila" C)

set (APP_NAME "LaTeXila")
set (APP_VERSION "2.3.1")

message (STATUS "*** Building ${APP_NAME} ${APP_VERSION} ***")

set (DATA_DIR "${CMAKE_INSTALL_PREFIX}/share/latexila"
	CACHE PATH "The directory where the data is")
set (BUILD_VALA ON CACHE BOOL "Generate the C code from Vala files")
set (WITH_GNOME OFF CACHE BOOL
	"Use gsettings-desktop-schemas for a better integration with GNOME")
set (COMPILE_SCHEMA ON CACHE BOOL "Compile the GSettings schema")
set (VALAC "" CACHE FILEPATH "The valac executable to use")

# Native Language Support
set (GETTEXT_PACKAGE "latexila")
set (LOCALE_DIR "${CMAKE_INSTALL_PREFIX}/share/locale")
find_package (Gettext REQUIRED)
list (APPEND CMAKE_MODULE_PATH "${latexila_SOURCE_DIR}/cmake")
find_package (Itstool REQUIRED)

set (SCHEMA_DIR "${CMAKE_INSTALL_PREFIX}/share")
set (ICONS_DIR "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor")

if (BUILD_VALA)
	include ("${latexila_SOURCE_DIR}/cmake/find_vala.cmake")
	include ("${latexila_SOURCE_DIR}/cmake/use_vala.cmake")

	set (_vala_main_version "0.16")
	set (_vala_min_version "0.15.0")

	if (VALAC)
		message (STATUS "Use custom valac: ${VALAC}")
		set (VALA_EXECUTABLE ${VALAC})
	else ()
		find_vala (${_vala_main_version})

		if ((NOT VALA_FOUND) OR
		    ("${VALA_VERSION}" VERSION_LESS "${_vala_min_version}"))
			message (FATAL_ERROR
				"Vala ${_vala_main_version}.x >= ${_vala_min_version} required")
		endif ()
	endif ()
endif ()

find_package (PkgConfig)
pkg_check_modules (GTK REQUIRED "gtk+-3.0 >= 3.2")
pkg_check_modules (GTKSOURCEVIEW REQUIRED "gtksourceview-3.0")
#pkg_check_modules (GTKSPELL REQUIRED "gtkspell-2.0")
pkg_check_modules (GEE REQUIRED "gee-1.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.28")
#pkg_check_modules (UNIQUE REQUIRED "unique-1.0")
pkg_check_modules (GDK-X11 REQUIRED "gdk-x11-3.0")
pkg_check_modules (X11 REQUIRED "x11")

if (WITH_GNOME)
	pkg_check_modules (DESKTOP-SCHEMAS REQUIRED "gsettings-desktop-schemas")
	set (DESKTOP_SCHEMAS "1")
else ()
	set (DESKTOP_SCHEMAS "0")
endif ()

configure_file (${latexila_SOURCE_DIR}/src/config.h.in
	${latexila_BINARY_DIR}/src/config.h)
add_definitions (-include config.h)

add_definitions (
	${GTK_CFLAGS}
	${GTKSOURCEVIEW_CFLAGS}
# 	${GTKSPELL_CFLAGS}
	${GEE_CFLAGS}
	${GIO_CFLAGS}
#	${UNIQUE_CFLAGS}
	${GDK-X11_CFLAGS}
	${X11_CFLAGS}
)

link_libraries (
	${GTK_LIBRARIES}
	${GTKSOURCEVIEW_LIBRARIES}
# 	${GTKSPELL_LIBRARIES}
	${GEE_LIBRARIES}
	${GIO_LIBRARIES}
#	${UNIQUE_LIBRARIES}
	${GDK-X11_LIBRARIES}
	${X11_LIBRARIES}
)

include ("${latexila_SOURCE_DIR}/cmake/itstool.cmake")

add_subdirectory (data)
add_subdirectory (help)
add_subdirectory (man)
add_subdirectory (po)
add_subdirectory (src/ui)

include_directories (vapi src/C ${latexila_BINARY_DIR}/src)
if (BUILD_VALA)
	add_subdirectory (src)
else ()
	add_subdirectory (src/C)
endif ()
