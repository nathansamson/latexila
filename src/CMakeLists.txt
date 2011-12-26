file (GLOB vala_sources RELATIVE "${latexila_SOURCE_DIR}/src/" "*.vala")
file (GLOB vapi_files "${latexila_SOURCE_DIR}/vapi/*.vapi")

vala_precompile (
	VALA_C
		${vala_sources}
	PACKAGES
		gtk+-3.0
		gtksourceview-3.0
		gee-1.0
#		unique-1.0
		gdk-x11-3.0
		x11
		posix

	CUSTOM_VAPIS
		${vapi_files}
	DIRECTORY
		"C"
)

add_executable (latexila ${VALA_C})
install (TARGETS latexila DESTINATION "bin")
