function (itstool target_name src_dir tmp_dir install_dir)
	install (DIRECTORY "${src_dir}/C" DESTINATION ${install_dir})

	# Get list of XML files
	file (GLOB path_files "${src_dir}/C/*")
	set (list_files)
	foreach (path_file ${path_files})
		get_filename_component (file ${path_file} NAME)
		set (list_files ${list_files} ${file})
	endforeach ()

	set (all_new_files)

	# Foreach language
	file (GLOB_RECURSE po_files "${src_dir}/*.po")
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
			COMMAND mkdir -p ${tmp_dir}/${lang}
			COMMAND ${ITSTOOL_EXECUTABLE} -m ${mo_file} -o ${tmp_dir}/${lang}/ ${path_files}
			DEPENDS ${po_file}
		)

		# Install the directory (which contains only the XML files)
		install (DIRECTORY ${tmp_dir}/${lang} DESTINATION ${install_dir})

		set (all_new_files ${all_new_files} ${lang_files})
	endforeach ()

	add_custom_target (${target_name} ALL DEPENDS ${all_new_files})
endfunction ()
