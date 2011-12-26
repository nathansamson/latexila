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

public class Templates : GLib.Object
{
    private static Templates templates = null;
    private ListStore default_store;
    private ListStore personal_store;
    private int nb_personal_templates;
    private string rc_file;
    private string rc_dir;

    private enum TemplateColumn
    {
        PIXBUF,
        ICON_ID,
        NAME,
        CONTENTS,
        N_COLUMNS
    }

    /* Templates is a singleton */
    private Templates ()
    {
        /* default templates */
        default_store = new ListStore (TemplateColumn.N_COLUMNS, typeof (string),
            typeof (string), typeof (string), typeof (string));

        add_template_from_string (default_store, _("Empty"), "empty", "");

        add_default_template (_("Article"),         "article",  "article.tex");
        add_default_template (_("Report"),          "report",   "report.tex");
        add_default_template (_("Book"),            "book",     "book.tex");
        add_default_template (_("Letter"),          "letter",   "letter.tex");
        add_default_template (_("Presentation"),    "beamer",   "beamer.tex");

        /* personal templates */
        personal_store = new ListStore (TemplateColumn.N_COLUMNS, typeof (string),
            typeof (string), typeof (string), typeof (string));
        nb_personal_templates = 0;

        rc_file = Path.build_filename (Environment.get_user_data_dir (), "latexila",
            "templatesrc", null);
        rc_dir = Path.build_filename (Environment.get_user_data_dir (), "latexila", null);

        // if the rc file doesn't exist, there is no personal template
        if (! File.new_for_path (rc_file).query_exists ())
            return;

        try
        {
            // load the key file
            KeyFile key_file = new KeyFile ();
            key_file.load_from_file (rc_file, KeyFileFlags.NONE);

            // get names and icons
            string[] names = key_file.get_string_list (Config.APP_NAME, "names");
            string[] icons = key_file.get_string_list (Config.APP_NAME, "icons");

            nb_personal_templates = names.length;

            for (int i = 0 ; i < nb_personal_templates ; i++)
            {
                File file = File.new_for_path ("%s/%d.tex".printf (rc_dir, i));
                if (! file.query_exists ())
                    continue;

                add_template_from_file (personal_store, names[i], icons[i], file);
            }
        }
        catch (Error e)
        {
            warning ("Load templates failed: %s", e.message);
            return;
        }
    }

    public static Templates get_default ()
    {
        if (templates == null)
            templates = new Templates ();
        return templates;
    }

    public void show_dialog_new (MainWindow parent)
    {
        Dialog dialog = new Dialog.with_buttons (_("New File..."), parent, 0,
            Stock.OK, ResponseType.ACCEPT,
            Stock.CANCEL, ResponseType.REJECT,
            null);

        // get and set previous size
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        int w, h;
        settings.get ("new-file-dialog-size", "(ii)", out w, out h);
        dialog.set_default_size (w, h);

        // without this, we can not shrink the dialog completely
        dialog.set_size_request (0, 0);

        Box content_area = (Box) dialog.get_content_area ();
        VPaned vpaned = new VPaned ();
        content_area.pack_start (vpaned);
        vpaned.position = settings.get_int ("new-file-dialog-paned-position");

        /* icon view for the default templates */
        IconView icon_view_default_templates = create_icon_view (default_store);
        Widget scrollbar = Utils.add_scrollbar (icon_view_default_templates);
        Widget component = Utils.get_dialog_component (_("Default templates"), scrollbar);
        vpaned.pack1 (component, true, true);

        /* icon view for the personal templates */
        IconView icon_view_personal_templates = create_icon_view (personal_store);
        scrollbar = Utils.add_scrollbar (icon_view_personal_templates);
        component = Utils.get_dialog_component (_("Your personal templates"), scrollbar);
        vpaned.pack2 (component, false, true);

        content_area.show_all ();

        icon_view_default_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (icon_view_default_templates,
                icon_view_personal_templates);
        });

        icon_view_personal_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (icon_view_personal_templates,
                icon_view_default_templates);
        });

        icon_view_default_templates.item_activated.connect ((path) =>
        {
            open_template (parent, default_store, path);
            close_dialog_new (dialog, vpaned);
        });

        icon_view_personal_templates.item_activated.connect ((path) =>
        {
            open_template (parent, personal_store, path);
            close_dialog_new (dialog, vpaned);
        });

        if (dialog.run () == ResponseType.ACCEPT)
        {
            List<TreePath> selected_items =
                icon_view_default_templates.get_selected_items ();
            TreeModel model = (TreeModel) default_store;

            // if no item is selected in the default templates, maybe one item is
            // selected in the personal templates
            if (selected_items.length () == 0)
            {
                selected_items = icon_view_personal_templates.get_selected_items ();
                model = (TreeModel) personal_store;
            }

            TreePath path = (TreePath) selected_items.nth_data (0);
            open_template (parent, model, path);
        }

        close_dialog_new (dialog, vpaned);
    }

    private void open_template (MainWindow main_window, TreeModel model, TreePath? path)
    {
        TreeIter iter = {};
        string contents = "";

        if (path != null && model.get_iter (out iter, path))
            model.get (iter, TemplateColumn.CONTENTS, out contents, -1);

        DocumentTab tab = main_window.create_tab (true);
        tab.document.set_contents (contents);
    }

    private void close_dialog_new (Dialog dialog, VPaned vpaned)
    {
        // save dialog size and paned position
        int w, h;
        dialog.get_size (out w, out h);
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        settings.set ("new-file-dialog-size", "(ii)", w, h);
        settings.set_int ("new-file-dialog-paned-position", vpaned.position);

        dialog.destroy ();
    }

    public void show_dialog_create (MainWindow parent)
    {
        return_if_fail (parent.active_tab != null);

        Dialog dialog = new Dialog.with_buttons (_("New Template..."), parent, 0,
            Stock.OK, ResponseType.ACCEPT,
            Stock.CANCEL, ResponseType.REJECT,
            null);

        dialog.set_default_size (420, 370);

        Box content_area = dialog.get_content_area () as Box;
        content_area.homogeneous = false;

        /* name */
        Entry entry = new Entry ();
        Widget component = Utils.get_dialog_component (_("Name of the new template"),
            entry);
        content_area.pack_start (component, false);

        /* icon */
        // we take the default store because it contains all the icons
        IconView icon_view = create_icon_view (default_store);
        Widget scrollbar = Utils.add_scrollbar (icon_view);
        component = Utils.get_dialog_component (_("Choose an icon"), scrollbar);
        content_area.pack_start (component);

        content_area.show_all ();

        while (dialog.run () == ResponseType.ACCEPT)
        {
            // if no name specified
            if (entry.text_length == 0)
                continue;

            List<TreePath> selected_items = icon_view.get_selected_items ();

            // if no icon selected
            if (selected_items.length () == 0)
                continue;

            nb_personal_templates++;

            // get the contents
            TextIter start, end;
            parent.active_document.get_bounds (out start, out end);
            string contents = parent.active_document.get_text (start, end, false);

            // get the icon id
            TreeModel model = (TreeModel) default_store;
            TreePath path = selected_items.nth_data (0);
            TreeIter iter;
            string icon_id;
            model.get_iter (out iter, path);
            model.get (iter, TemplateColumn.ICON_ID, out icon_id, -1);

            add_template_from_string (personal_store, entry.text, icon_id, contents);
            add_personal_template (contents);
            break;
        }

        dialog.destroy ();
    }

    public void show_dialog_delete (MainWindow parent)
    {
        Dialog dialog = new Dialog.with_buttons (_("Delete Template(s)..."), parent, 0,
            Stock.DELETE, ResponseType.ACCEPT,
            Stock.CLOSE, ResponseType.REJECT,
            null);

        dialog.set_default_size (400, 200);

        Box content_area = (Box) dialog.get_content_area ();

        /* icon view for the personal templates */
        IconView icon_view = create_icon_view (personal_store);
        icon_view.set_selection_mode (SelectionMode.MULTIPLE);
        Widget scrollbar = Utils.add_scrollbar (icon_view);
        Widget component = Utils.get_dialog_component (_("Personal templates"),
            scrollbar);
        content_area.pack_start (component);
        content_area.show_all ();

        int nb_personal_templates_before = nb_personal_templates;

        while (dialog.run () == ResponseType.ACCEPT)
        {
            List<TreePath> selected_items = icon_view.get_selected_items ();
            TreeModel model = (TreeModel) personal_store;

            uint nb_selected_items = selected_items.length ();

            for (int i = 0 ; i < nb_selected_items ; i++)
            {
                TreePath path = selected_items.nth_data (i);
                TreeIter iter;
                model.get_iter (out iter, path);
                personal_store.remove (iter);
            }

            nb_personal_templates -= (int) nb_selected_items;
        }

        if (nb_personal_templates != nb_personal_templates_before)
        {
            save_rc_file ();
            save_contents ();
        }

        dialog.destroy ();
    }

    private void add_template_from_string (ListStore store, string name, string icon_id,
        string contents)
    {
        TreeIter iter;
        store.append (out iter);
        store.set (iter,
            TemplateColumn.PIXBUF, get_theme_icon (icon_id),
            TemplateColumn.ICON_ID, icon_id,
            TemplateColumn.NAME, name,
            TemplateColumn.CONTENTS, contents,
            -1);
    }

    private void add_template_from_file (ListStore store, string name, string icon_id,
        File file)
    {
        try
        {
            uint8[] chars;
            file.load_contents (null, out chars);
            string contents = (string) (owned) chars;
            add_template_from_string (store, name, icon_id, contents);
        }
        catch (Error e)
        {
            warning ("Impossible to load the template '%s': %s", name, e.message);
        }
    }

    private void add_default_template (string name, string icon_id, string filename)
    {
        File[] files = {};

        unowned string[] language_names = Intl.get_language_names ();
        foreach (string language_name in language_names)
        {
            files += File.new_for_path (Path.build_filename (Config.DATA_DIR,
                "templates", language_name, filename));
        }

        foreach (File file in files)
        {
            if (! file.query_exists ())
                continue;

            add_template_from_file (default_store, name, icon_id, file);
            return;
        }

        warning ("Template '%s' not found.", name);
    }

    private IconView create_icon_view (ListStore store)
    {
        IconView icon_view = new IconView.with_model (store);
        icon_view.set_selection_mode (SelectionMode.SINGLE);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        pixbuf_renderer.stock_size = IconSize.DIALOG;
        pixbuf_renderer.xalign = (float) 0.5;
        pixbuf_renderer.yalign = (float) 1.0;
        icon_view.pack_start (pixbuf_renderer, false);
        icon_view.set_attributes (pixbuf_renderer,
            "icon-name", TemplateColumn.PIXBUF,
            null);

        // We also use a CellRenderer for the text column, because with set_text_column()
        // the text is not centered (when a CellRenderer is used for the pixbuf).
        CellRendererText text_renderer = new CellRendererText ();
        text_renderer.alignment = Pango.Alignment.CENTER;
        text_renderer.wrap_mode = Pango.WrapMode.WORD;
        text_renderer.xalign = (float) 0.5;
        text_renderer.yalign = (float) 0.0;
        icon_view.pack_end (text_renderer, false);
        icon_view.set_attributes (text_renderer,
            "text", TemplateColumn.NAME,
            null);

        return icon_view;
    }

    private void on_icon_view_selection_changed (IconView icon_view,
        IconView other_icon_view)
    {
        // only one item of the two icon views can be selected at once

        // we unselect all the items of the other icon view only if the current icon
        // view have an item selected, because when we unselect all the items the
        // "selection-changed" signal is emitted for the other icon view, so for the
        // other icon view this function is also called but no item is selected so
        // nothing is done and the item selected by the user keeps selected

        List<TreePath> selected_items = icon_view.get_selected_items ();
        if (selected_items.length () > 0)
            other_icon_view.unselect_all ();
    }

    private void add_personal_template (string contents)
    {
        save_rc_file ();

        File file = File.new_for_path ("%s/%d.tex".printf (rc_dir,
            nb_personal_templates - 1));
        try
        {
            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (contents, contents.length, null, false,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save the templates: %s", e.message);
        }
    }

    private void save_rc_file ()
    {
        if (nb_personal_templates == 0)
        {
            try
            {
                File.new_for_path (rc_file).delete ();
            }
            catch (Error e) {}
            return;
        }

        // the names and the icons of all personal templates
        string[] names = new string[nb_personal_templates];
        string[] icons = new string[nb_personal_templates];

        // traverse the list store
        TreeIter iter;
        TreeModel model = (TreeModel) personal_store;
        bool valid_iter = model.get_iter_first (out iter);
        int i = 0;
        while (valid_iter)
        {
            model.get (iter,
                TemplateColumn.NAME, out names[i],
                TemplateColumn.ICON_ID, out icons[i],
                -1);
            valid_iter = model.iter_next (ref iter);
            i++;
        }

        /* save the rc file */
        try
        {
            KeyFile key_file = new KeyFile ();
            key_file.set_string_list (Config.APP_NAME, "names", names);
            key_file.set_string_list (Config.APP_NAME, "icons", icons);

            string key_file_data = key_file.to_data ();
            File file = File.new_for_path (rc_file);

            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (key_file_data, key_file_data.length, null, false,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save the templates: %s", e.message);
        }
    }

    /* save the contents of the personal templates
     * the first personal template is saved in 0.tex, the second in 1.tex, etc */
    private void save_contents ()
    {
        // delete all the *.tex files
        Posix.system ("rm -f %s/*.tex".printf (rc_dir));

        // traverse the list store
        TreeIter iter;
        TreeModel model = (TreeModel) personal_store;
        bool valid_iter = model.get_iter_first (out iter);
        int i = 0;
        while (valid_iter)
        {
            string contents;
            model.get (iter, TemplateColumn.CONTENTS, out contents, -1);
            File file = File.new_for_path ("%s/%d.tex".printf (rc_dir, i));
            try
            {
                // check if parent directories exist, if not, create it
                File parent = file.get_parent ();
                if (parent != null && ! parent.query_exists ())
                    parent.make_directory_with_parents ();

                file.replace_contents (contents, contents.length, null, false,
                    FileCreateFlags.NONE, null, null);
            }
            catch (Error e)
            {
                warning ("Impossible to save the template: %s", e.message);
            }

            valid_iter = model.iter_next (ref iter);
            i++;
        }
    }

    // For compatibility reasons. 'icon_id' is the string stored in the rc file,
    // and the return value is the theme icon name used for the pixbuf.
    // If we store directly the theme icon names in the rc file, old rc files must be
    // modified via a script for example, but it's simpler like that.
    // TODO: for the 3.0 version, we can store directly theme icon names.
    private string? get_theme_icon (string icon_id)
    {
        switch (icon_id)
        {
            case "empty":
                return "text-x-preview";

            case "article":
                // Same as Stock.FILE (but it's the theme icon name)
                return "text-x-generic";

            case "report":
                return "x-office-document";

            case "book":
                return "accessories-dictionary";

            case "letter":
                return "emblem-mail";

            case "beamer":
                return "x-office-presentation";

            default:
                return_val_if_reached (null);
        }
    }
}
