cmake_minimum_required (VERSION 2.6.4)

project ("latexila" C)

set (APP_NAME "LaTeXila")
set (APP_VERSION "2.1.1")

message (STATUS "*** Building ${APP_NAME} ${APP_VERSION} ***")

set (DATA_DIR "${CMAKE_INSTALL_PREFIX}/share/latexila"
	CACHE PATH "The directory where the data is")
set (BUILD_VALA ON CACHE BOOL "Generate the C code from Vala files")

# Native Language Support
set (GETTEXT_PACKAGE "latexila")
set (LOCALE_DIR "${CMAKE_INSTALL_PREFIX}/share/locale")
find_package (Gettext REQUIRED)
list (APPEND CMAKE_MODULE_PATH "${latexila_SOURCE_DIR}/cmake")
find_package (Itstool REQUIRED)

set (SCHEMA_DIR "${CMAKE_INSTALL_PREFIX}/share")
set (ICONS_DIR "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor")

if (BUILD_VALA)
	list (APPEND CMAKE_MODULE_PATH "${latexila_SOURCE_DIR}/cmake/vala")
	find_package (Vala "0.12.1" REQUIRED)
	include (${VALA_USE_FILE})
endif ()

find_package (PkgConfig)
pkg_check_modules (GTK REQUIRED "gtk+-2.0 >= 2.16")
pkg_check_modules (GTKSOURCEVIEW REQUIRED "gtksourceview-2.0 >= 2.10")
pkg_check_modules (GEE REQUIRED "gee-1.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26")
pkg_check_modules (UNIQUE REQUIRED "unique-1.0")
pkg_check_modules (GDK-X11 REQUIRED "gdk-x11-2.0")
pkg_check_modules (X11 REQUIRED "x11")
pkg_check_modules (DESKTOP-SCHEMAS "gsettings-desktop-schemas")

# is there an easier way?
if (DESKTOP-SCHEMAS_FOUND)
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
	${GEE_CFLAGS}
	${GIO_CFLAGS}
	${UNIQUE_CFLAGS}
	${GDK-X11_CFLAGS}
	${X11_CFLAGS}
)

link_libraries (
	${GTK_LIBRARIES}
	${GTKSOURCEVIEW_LIBRARIES}
	${GEE_LIBRARIES}
	${GIO_LIBRARIES}
	${UNIQUE_LIBRARIES}
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
