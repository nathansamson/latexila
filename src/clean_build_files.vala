/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2011 Sébastien Wilmet
 *
 * LaTeXila is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * LaTeXila is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LaTeXila.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class CleanBuildFiles : GLib.Object
{
    private enum CleanFileColumn
    {
        DELETE,
        NAME,
        FILE,
        N_COLUMNS
    }

    private unowned MainWindow  _main_window;
    private Document            _doc;
    private string[]            _extensions;
    private bool                _no_confirm;

    public CleanBuildFiles (MainWindow main_window, Document doc)
    {
        _main_window = main_window;
        _doc = doc;

        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.latex");
        string exts = settings.get_string ("clean-extensions");
        _extensions = exts.split (" ");

        _no_confirm = settings.get_boolean ("no-confirm-clean");
    }

    // return true if some files have been deleted
    public bool clean ()
    {
        if (! _doc.is_main_file_a_tex_file ())
            return false;

        Gee.ArrayList<File> files_to_delete;
        File directory;

        Project? project = _doc.get_project ();

        // the document is part of a project
        if (project != null)
        {
            directory = project.directory;
            files_to_delete = get_build_files_in_directory (directory);
        }
        else
        {
            directory = _doc.location.get_parent ();
            files_to_delete = get_build_files_simple ();
        }

        if (files_to_delete.size == 0)
        {
            if (! _no_confirm)
                show_info_no_file ();
            return false;
        }

        if (_no_confirm)
        {
            foreach (File file_to_delete in files_to_delete)
                Utils.delete_file (file_to_delete);

            return true;
        }

        return confirm_cleanup (files_to_delete, directory);
    }

    private Gee.ArrayList<File> get_build_files_simple ()
    {
        File location = _doc.location;
        File directory = location.get_parent ();
        string shortname = Utils.get_shortname (location.get_basename ());

        Gee.ArrayList<File> files_to_delete = new Gee.ArrayList<File> ();

        foreach (string extension in _extensions)
        {
            string basename = shortname + extension;
            File file = directory.get_child (basename);
            if (file.query_exists ())
                files_to_delete.add (file);
        }

        return files_to_delete;
    }

    private Gee.ArrayList<File> get_build_files_in_directory (File directory)
    {
        Gee.ArrayList<File> files_to_delete = new Gee.ArrayList<File> ();
        FileEnumerator enumerator;

        try
        {
            enumerator = directory.enumerate_children ("standard::type,standard::name",
                FileQueryInfoFlags.NONE);
        }
        catch (Error e)
        {
            warning ("Clean build files: %s", e.message);
            return files_to_delete;
        }

        while (true)
        {
            FileInfo? info = null;

            try
            {
                info = enumerator.next_file ();
            }
            catch (Error e)
            {
                warning ("Clean build files: %s", e.message);
                break;
            }

            if (info == null)
                break;

            string name = info.get_name ();

            // don't take into account hidden files and directories
            // example: Git have a *.idx file in the .git/ directory
            if (name[0] == '.')
                continue;

            File file = directory.get_child (name);

            FileType type = info.get_file_type ();
            if (type == FileType.DIRECTORY)
            {
                var files_to_delete_in_dir = get_build_files_in_directory (file);
                files_to_delete.add_all (files_to_delete_in_dir);
                continue;
            }

            string extension = Utils.get_extension (name);
            if (extension in _extensions)
                files_to_delete.add (file);
        }

        return files_to_delete;
    }

    private bool confirm_cleanup (Gee.ArrayList<File> files_to_delete, File directory)
    {
        return_val_if_fail (0 < files_to_delete.size, false);

        TreeView list_files = get_list_files (files_to_delete, directory);
        Dialog dialog = get_dialog (list_files);

        return run_dialog (dialog, list_files.get_model ());
    }

    private TreeView get_list_files (Gee.ArrayList<File> files_to_delete, File directory)
    {
        TreeView treeview = new TreeView ();
        treeview.set_size_request (260, 120);
        treeview.headers_visible = false;
        treeview.enable_search = false;

        ListStore store = new ListStore (CleanFileColumn.N_COLUMNS,
            typeof (bool), typeof (string), typeof (File));

        store.set_sort_func (0, on_sort_list_files);
        store.set_sort_column_id (0, SortType.ASCENDING);

        // fill the list
        foreach (File file_to_delete in files_to_delete)
        {
            string relative_path = Utils.get_relative_path (directory, file_to_delete,
                directory);
            TreeIter iter;
            store.append (out iter);
            store.set (iter,
                CleanFileColumn.DELETE, true,
                CleanFileColumn.NAME, relative_path,
                CleanFileColumn.FILE, file_to_delete,
                -1);
        }

        treeview.set_model (store);
        CellRendererToggle toggle_renderer = new CellRendererToggle ();

        toggle_renderer.toggled.connect ((path_str) =>
        {
            TreePath path = new TreePath.from_string (path_str);
            TreeIter iter;
            bool active;
            store.get_iter (out iter, path);
            store.get (iter, CleanFileColumn.DELETE, out active, -1);
            // inverse the value
            store.set (iter, CleanFileColumn.DELETE, ! active, -1);
        });

        TreeViewColumn column = new TreeViewColumn.with_attributes ("Delete?",
            toggle_renderer, "active", CleanFileColumn.DELETE, null);
        treeview.append_column (column);

        CellRendererText text_renderer = new CellRendererText ();
        column = new TreeViewColumn.with_attributes ("Name", text_renderer,
            "text", CleanFileColumn.NAME, null);
        treeview.append_column (column);

        return treeview;
    }

    private Dialog get_dialog (TreeView list_files)
    {
        Dialog dialog = new Dialog.with_buttons (null,
            _main_window,
            DialogFlags.DESTROY_WITH_PARENT,
            Stock.CANCEL, ResponseType.CANCEL,
            Stock.DELETE, ResponseType.ACCEPT,
            null);

        Grid grid = new Grid ();
        grid.set_column_spacing (12);
        grid.set_row_spacing (8);
        grid.border_width = 5;

        Box content_area = dialog.get_content_area () as Box;
        content_area.pack_start (grid);

        /* image */
        Image image = new Image.from_stock (Stock.DIALOG_WARNING, IconSize.DIALOG);
        image.set_valign (Align.START);
        grid.attach (image, 0, 0, 1, 3);

        /* primary label */
        Label primary_label = new Label (null);
        primary_label.set_line_wrap (true);
        primary_label.set_use_markup (true);
        primary_label.set_halign (Align.START);
        primary_label.set_selectable (true);
        primary_label.margin_bottom = 4;
        primary_label.set_markup ("<span weight=\"bold\" size=\"larger\">"
            + _("Do you really want to delete these files?") + "</span>");

        grid.attach (primary_label, 1, 0, 1, 1);

        /* secondary label */
        Label select_label = new Label (_("Select the files you want to delete:"));
        select_label.set_line_wrap (true);
        select_label.set_halign (Align.START);
        grid.attach (select_label, 1, 1, 1, 1);

        /* list of files with a scrollbar */
        ScrolledWindow sw = Utils.add_scrollbar (list_files) as ScrolledWindow;
        sw.set_shadow_type (ShadowType.IN);
        sw.expand = true;
        grid.attach (sw, 1, 2, 1, 1);

        grid.show_all ();

        return dialog;
    }

    private bool run_dialog (Dialog dialog, TreeModel list_store)
    {
        bool ret = false;
        if (dialog.run () == ResponseType.ACCEPT)
        {
            // get files to delete
            File[] selected_files = {};
            TreeIter iter;
            bool valid = list_store.get_iter_first (out iter);
            while (valid)
            {
                bool selected;
                File file_to_delete;

                list_store.get (iter,
                    CleanFileColumn.DELETE, out selected,
                    CleanFileColumn.FILE, out file_to_delete,
                    -1);

                if (selected)
                    selected_files += file_to_delete;

                valid = list_store.iter_next (ref iter);
            }

            ret = 0 < selected_files.length;

            foreach (File file_to_delete in selected_files)
                Utils.delete_file (file_to_delete);
        }

        dialog.destroy ();
        return ret;
    }

    private int on_sort_list_files (TreeModel model, TreeIter a, TreeIter b)
    {
        string name_a;
        string name_b;

        model.get (a, CleanFileColumn.NAME, out name_a, -1);
        model.get (b, CleanFileColumn.NAME, out name_b, -1);

        return name_a.collate (name_b);
    }

    private void show_info_no_file ()
    {
        Dialog dialog = new MessageDialog (_main_window,
            DialogFlags.DESTROY_WITH_PARENT,
            MessageType.INFO,
            ButtonsType.OK,
            "%s", _("No build file to clean up."));

        dialog.run ();
        dialog.destroy ();
    }
}
