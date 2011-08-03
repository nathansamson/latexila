set (src_dir "${latexila_SOURCE_DIR}/data/templates")
set (tmp_dir "${latexila_BINARY_DIR}/data/templates")
set (install_dir "${DATA_DIR}/templates")

# Get list of XML files
file (GLOB path_files "${src_dir}/C/*")
set (list_files)
foreach (path_file ${path_files})
	get_filename_component (file ${path_file} NAME_WE)
	set (list_files ${list_files} "${file}.tex")
endforeach ()

###
# Generate default *.tex
###

# Get the paths of the new files
set (lang "C")
set (lang_files)
foreach (file ${list_files})
	set (lang_files ${lang_files} "${tmp_dir}/${lang}/${file}")
endforeach ()

# Generate the *.tex files from the *.xml
add_custom_command (
	OUTPUT ${lang_files}
	COMMAND mkdir -p ${tmp_dir}/${lang}
	COMMAND ${src_dir}/gen_tex.sh ${src_dir}/${lang} ${tmp_dir}/${lang}
	DEPENDS ${path_files}
)

# Install the directory (which contains only the *.tex files)
install (DIRECTORY ${tmp_dir}/${lang} DESTINATION ${install_dir})

set (all_new_files ${lang_files})

###
# Generate *.tex foreach language
###

file (GLOB po_files "${src_dir}/*.po")
foreach (po_file ${po_files})
	# Get the language name
	get_filename_component (lang ${po_file} NAME_WE)

	# Get the paths of the new files
	set (lang_files)
	foreach (file ${list_files})
		set (lang_files ${lang_files} "${tmp_dir}/${lang}/${file}")
	endforeach ()

	# Generate the new files from the .po
	set (mo_file "${tmp_dir}/${lang}.mo")
	add_custom_command (
		OUTPUT ${lang_files}
		COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} -o ${mo_file} ${po_file}
		COMMAND mkdir -p ${tmp_dir}/${lang}-xml ${tmp_dir}/${lang}
		COMMAND ${ITSTOOL_EXECUTABLE} -i ${src_dir}/templates.its -m ${mo_file} -o ${tmp_dir}/${lang}-xml/ ${path_files}
		COMMAND ${src_dir}/gen_tex.sh ${tmp_dir}/${lang}-xml ${tmp_dir}/${lang}
		DEPENDS ${po_file}
	)

	# Install the directory (which contains only the *.tex files)
	install (DIRECTORY ${tmp_dir}/${lang} DESTINATION ${install_dir})

	set (all_new_files ${all_new_files} ${lang_files})
endforeach ()

add_custom_target ("templates" ALL DEPENDS ${all_new_files})
