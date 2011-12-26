/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2011 Sébastien Wilmet
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

namespace Utils
{
    /*************************************************************************/
    // String utilities

    public string str_middle_truncate (string str, uint max_length)
    {
        if (str.length <= max_length)
            return str;

        uint half_length = (max_length - 4) / 2;
        int l = str.length;
        return str[0:half_length] + "..." + str[l-half_length:l];
    }

    public bool char_is_escaped (string text, long char_index)
    {
        return_val_if_fail (char_index < text.length, false);

        int index = (int) char_index;
        if (! string_get_prev_char (text, ref index, null))
            return false;

        bool escaped = false;
        while (true)
        {
            unichar cur_char;
            bool first_char = ! string_get_prev_char (text, ref index, out cur_char);

            if (cur_char != '\\')
                break;

            escaped = ! escaped;

            if (first_char)
                break;
        }

        return escaped;
    }

    // The opposite of string.get_next_char ().
    // TODO remove this function when it is included upstream
    // See https://bugzilla.gnome.org/show_bug.cgi?id=655185
    private bool string_get_prev_char (string str, ref int index, out unichar c)
    {
        c = str.get_char (index);
        if (index <= 0 || c == '\0')
            return false;

        unowned string str_at_index = (string) ((char*) str + index);
        unowned string str_prev = str_at_index.prev_char ();
        index = (int) ((char*) str_prev - (char*) str);
        return true;
    }


    /*************************************************************************/
    // URI, File or Path utilities

    public string replace_home_dir_with_tilde (string uri)
    {
        return_val_if_fail (uri != null, null);
        string home = Environment.get_home_dir ();
        if (uri == home)
            return "~";
        if (uri.has_prefix (home))
            return "~" + uri[home.length:uri.length];
        return uri;
    }

    public string? uri_get_dirname (string uri)
    {
        return_val_if_fail (uri != null, null);
        string dir = Path.get_dirname (uri);
        if (dir == ".")
            return null;
        return replace_home_dir_with_tilde (dir);
    }

    /* Returns a string suitable to be displayed in the UI indicating
     * the name of the directory where the file is located.
     * For remote files it may also contain the hostname etc.
     * For local files it tries to replace the home dir with ~.
     */
    public string? get_dirname_for_display (File location)
    {
        try
        {
            Mount mount = location.find_enclosing_mount (null);
            string mount_name = mount.get_name ();
            string? dirname =
                uri_get_dirname (location.get_path () ?? location.get_uri ());

            if (dirname == null || dirname == ".")
                return mount_name;
            return mount_name + " " + dirname;
        }

        // local files or uri without mounts
        catch (Error e)
        {
            return uri_get_dirname (location.get_path () ?? location.get_uri ());
        }
    }

    // get filename without extension (without the dot)
    public string get_shortname (string path)
    {
        return path[0:get_extension_pos (path)];
    }

    // get file's extension (with the dot)
    public string get_extension (string path)
    {
        return path[get_extension_pos (path):path.length].down ();
    }

    private long get_extension_pos (string path)
    {
        long l = path.length;

        for (long i = l - 1 ; i >= 0 ; i--)
        {
            if (path[i] == '/')
                return l;
            else if (path[i] == '.')
                return i;
        }

        return l;
    }

    public void delete_file (File file)
    {
        try
        {
            file.delete ();
        }
        catch (Error e)
        {
            warning ("Delete file '%s' failed: %s", file.get_parse_name (), e.message);
        }
    }

    // origin can be equal to common_dir, but target must be different
    public string? get_relative_path (File origin, File target, File common_dir)
    {
        File? origin_dir;
        if (origin.equal (common_dir))
            origin_dir = origin;
        else
            origin_dir = origin.get_parent ();

        File? target_parent = target.get_parent ();

        return_val_if_fail (origin_dir != null, null);
        return_val_if_fail (target_parent != null, null);

        // The origin is in the same directory as the target.
        if (target_parent.equal (origin_dir))
            return target.get_basename ();

        // Get a list of parent directories. Stop at the common dir.
        List<File> target_dirs = new List<File> ();
        List<File> origin_dirs = new List<File> ();

        while (target_parent != null && ! target_parent.equal (common_dir))
        {
            target_dirs.prepend (target_parent);
            target_parent = target_parent.get_parent ();
        }

        while (origin_dir != null && ! origin_dir.equal (common_dir))
        {
            origin_dirs.prepend (origin_dir);
            origin_dir = origin_dir.get_parent ();
        }

        // Get number of common dirs
        uint dir_index = 0;
        while (dir_index < target_dirs.length () && dir_index < origin_dirs.length ())
        {
            File cur_target_dir = target_dirs.nth_data (dir_index);
            File cur_origin_dir = origin_dirs.nth_data (dir_index);
            if (! cur_target_dir.equal (cur_origin_dir))
                break;

            dir_index++;
        }

        uint nb_common_dirs = dir_index;

        /* Build the relative path */
        string relative_path = "";

        // go to the common dir
        uint nb_remaining_origin_dirs = origin_dirs.length () - nb_common_dirs;
        for (uint i = 0 ; i < nb_remaining_origin_dirs ; i++)
            relative_path += "../";

        // go to the target dir
        for (uint i = nb_common_dirs ; i < target_dirs.length () ; i++)
        {
            File cur_target_dir = target_dirs.nth_data (i);
            relative_path += cur_target_dir.get_basename () + "/";
        }

        // add the target basename
        relative_path += target.get_basename ();
        return relative_path;
    }


    /*************************************************************************/
    // UI stuff

    public Widget add_scrollbar (Widget child)
    {
        ScrolledWindow scrollbar = new ScrolledWindow (null, null);
        scrollbar.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scrollbar.add (child);
        return scrollbar;
    }

    public void set_entry_error (Widget entry, bool error)
    {
        if (error)
        {
            Gdk.Color red, white;
            Gdk.Color.parse ("#FF6666", out red);
            Gdk.Color.parse ("white", out white);
            entry.modify_base (StateType.NORMAL, red);
            entry.modify_text (StateType.NORMAL, white);
        }
        else
        {
            entry.modify_base (StateType.NORMAL, null);
            entry.modify_text (StateType.NORMAL, null);
        }
    }

    public bool tree_model_iter_prev (TreeModel model, ref TreeIter iter)
    {
        TreePath path = model.get_path (iter);
        if (path.prev ())
        {
            bool ret = model.get_iter (out iter, path);
            return ret;
        }
        return false;
    }

    // get indice of selected row in the treeview
    // returns -1 if no row is selected
    public int get_selected_row (TreeView view, out TreeIter iter = null)
    {
        TreeSelection select = view.get_selection ();
        if (select.get_selected (null, out iter))
        {
            TreeModel model = view.get_model ();
            TreePath path = model.get_path (iter);
            return path.get_indices ()[0];
        }
        return -1;
    }

    public Gdk.Pixbuf get_pixbuf_from_stock (string stock_id, Gtk.IconSize size)
    {
        Gtk.Invisible w = new Gtk.Invisible ();
        Gdk.Pixbuf pixbuf = w.render_icon (stock_id, size, "vala");
        return pixbuf;
    }

    public Button get_toolbar_button (string stock_id)
    {
        return _get_toolbar_button_impl (stock_id, false);
    }

    public ToggleButton get_toolbar_toggle_button (string stock_id)
    {
        return (ToggleButton) _get_toolbar_button_impl (stock_id, true);
    }

    private Button _get_toolbar_button_impl (string stock_id, bool toggle)
    {
        Button button;
        if (toggle)
            button = new ToggleButton ();
        else
            button = new Button ();

        Image image = new Image.from_stock (stock_id, IconSize.MENU);
        button.add (image);
        button.set_relief (ReliefStyle.NONE);
        return button;
    }

    public Widget get_dialog_component (string title, Widget widget)
    {
        Grid grid = new Grid ();
        grid.orientation = Orientation.VERTICAL;
        grid.set_row_spacing (6);
        grid.border_width = 6;

        // title in bold, left aligned
        Label label = new Label (null);
        label.set_markup ("<b>" + title + "</b>");
        label.set_halign (Align.START);
        grid.add (label);

        // left margin for the widget
        widget.set_margin_left (12);
        widget.set_hexpand (true);
        grid.add (widget);

        return grid;
    }


    /*************************************************************************/
    // Misc

    public void flush_queue ()
    {
        while (Gtk.events_pending ())
            Gtk.main_iteration ();
    }

    public const uint ALL_WORKSPACES = 0xffffff;

    /* Get the workspace the window is on
     *
     * This function gets the workspace that the #GtkWindow is visible on,
     * it returns ALL_WORKSPACES if the window is sticky, or if
     * the window manager doesn't support this function.
     */
    public uint get_window_workspace (Gtk.Window gtkwindow)
    {
        return_val_if_fail (gtkwindow.get_realized (), 0);

        uint ret = ALL_WORKSPACES;

        Gdk.Window window = gtkwindow.get_window ();
        Gdk.Display display = window.get_display ();
        unowned X.Display x_display = Gdk.X11Display.get_xdisplay (display);

        X.Atom type;
        int format;
        ulong nitems;
        ulong bytes_after;
        uint *workspace;

        Gdk.error_trap_push ();

        int result = x_display.get_window_property (Gdk.X11Window.get_xid (window),
            Gdk.x11_get_xatom_by_name_for_display (display, "_NET_WM_DESKTOP"),
            0, long.MAX, false, X.XA_CARDINAL, out type, out format, out nitems,
            out bytes_after, out workspace);

        int err = Gdk.error_trap_pop ();

        if (err != X.Success || result != X.Success)
            return ret;

        if (type == X.XA_CARDINAL && format == 32 && nitems > 0)
            ret = workspace[0];

        X.free (workspace);
        return ret;
    }

    public void print_build_tool (BuildTool build_tool)
    {
        stdout.printf ("\n=== Build Tool ===\n");
        stdout.printf ("desc: %s\n", build_tool.description);
        stdout.printf ("ext: %s\n", build_tool.extensions);
        stdout.printf ("label: %s\n", build_tool.label);
        stdout.printf ("icon: %s\n\n", build_tool.icon);

        foreach (BuildJob build_job in build_tool.jobs)
        {
            stdout.printf ("== Build Job ==\n");
            stdout.printf ("must succeed: %s\n", build_job.must_succeed.to_string ());
            stdout.printf ("post processor: %s\n",
                BuildTools.get_post_processor_name_from_type (build_job.post_processor));
            stdout.printf ("command: %s\n\n", build_job.command);
        }
    }
}
