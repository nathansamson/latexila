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
using Gee;

public class PreferencesDialog : Dialog
{
    private static PreferencesDialog preferences_dialog = null;
    private ListStore build_tools_store;

    delegate unowned string Plural (ulong n);

    private PreferencesDialog ()
    {
        title = _("Preferences");
        destroy_with_parent = true;
        border_width = 5;

        // reset all button
        Button reset_button = new Button.with_label (_("Reset All"));
        Image image = new Image.from_stock (Stock.CLEAR, IconSize.MENU);
        reset_button.set_image (image);
        reset_button.set_tooltip_text (_("Reset all preferences"));
        reset_button.show_all ();
        add_action_widget (reset_button, ResponseType.APPLY);

        // close button
        add_button (Stock.CLOSE, ResponseType.CLOSE);

        response.connect ((response_id) =>
        {
            switch (response_id)
            {
                case ResponseType.CLOSE:
                    hide ();
                    return;
                case ResponseType.APPLY:
                    reset_all ();
                    return;
            }
        });

        /* load the UI */

        Builder builder = new Builder ();

        try
        {
            string ui_path = Path.build_filename (Config.DATA_DIR, "ui",
                "preferences_dialog.ui");
            builder.add_from_file (ui_path);
        }
        catch (Error e)
        {
            string message = "Error: %s".printf (e.message);
            warning ("%s", message);

            Label label_error = new Label (message);
            label_error.set_line_wrap (true);
            Box content_area = (Box) get_content_area ();
            content_area.pack_start (label_error);
            content_area.show_all ();
            return;
        }

        init_editor_tab (builder);
        init_font_and_colors_tab (builder);
        init_latex_tab (builder);
        init_other_tab (builder);

        // pack notebook
        Notebook notebook = builder.get_object ("notebook") as Notebook;
        notebook.unparent ();
        Box content_area = (Box) get_content_area ();
        content_area.pack_start (notebook);
    }

    public static void show_me (MainWindow parent)
    {
        if (preferences_dialog == null)
        {
            preferences_dialog = new PreferencesDialog ();

            // FIXME how to connect Widget.destroyed?
            preferences_dialog.destroy.connect (() =>
            {
                if (preferences_dialog != null)
                    preferences_dialog = null;
            });
        }

        if (parent != preferences_dialog.get_transient_for ())
            preferences_dialog.set_transient_for (parent);

        preferences_dialog.present ();
    }

    private void reset_all ()
    {
        // build tools are not reset, since there is another button for that

        Dialog dialog = get_reset_all_confirm_dialog (
            _("Do you really want to reset all preferences?"));
        int resp = dialog.run ();
        dialog.destroy ();
        if (resp != ResponseType.YES)
            return;

        string[] settings_str =
        {
            "org.gnome.latexila.preferences.editor",
            "org.gnome.latexila.preferences.latex",
            "org.gnome.latexila.preferences.file-browser"
        };

        foreach (string setting_str in settings_str)
        {
            GLib.Settings settings = new GLib.Settings (setting_str);
            string[] keys = settings.list_keys ();
            foreach (string key in keys)
                settings.reset (key);
        }
    }

    private void init_editor_tab (Builder builder)
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");

        var display_line_nb_checkbutton =
            builder.get_object ("display_line_nb_checkbutton");
        settings.bind ("display-line-numbers", display_line_nb_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var tab_width_spinbutton =
            builder.get_object ("tab_width_spinbutton") as SpinButton;
        set_spin_button_range (tab_width_spinbutton, settings, "tabs-size");
        settings.bind ("tabs-size", tab_width_spinbutton, "value",
            SettingsBindFlags.DEFAULT);

        var insert_spaces_checkbutton = builder.get_object ("insert_spaces_checkbutton");
        settings.bind ("insert-spaces", insert_spaces_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        Widget forget_no_tabs = builder.get_object ("forget_no_tabs") as Widget;
        settings.bind ("forget-no-tabs", forget_no_tabs, "active",
            SettingsBindFlags.DEFAULT);
        set_sensitivity (settings, "insert-spaces", forget_no_tabs);

        var hl_current_line_checkbutton =
            builder.get_object ("hl_current_line_checkbutton");
        settings.bind ("highlight-current-line", hl_current_line_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var bracket_matching_checkbutton =
            builder.get_object ("bracket_matching_checkbutton");
        settings.bind ("bracket-matching", bracket_matching_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var backup_checkbutton = builder.get_object ("backup_checkbutton");
        settings.bind ("create-backup-copy", backup_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var autosave_checkbutton = builder.get_object ("autosave_checkbutton");
        settings.bind ("auto-save", autosave_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var autosave_spinbutton =
            builder.get_object ("autosave_spinbutton") as SpinButton;
        set_spin_button_range (autosave_spinbutton, settings, "auto-save-interval");
        settings.bind ("auto-save-interval", autosave_spinbutton, "value",
            SettingsBindFlags.DEFAULT);
        set_sensitivity (settings, "auto-save", autosave_spinbutton);

        Label autosave_label = builder.get_object ("autosave_label") as Label;
        set_plural (autosave_label, settings, "auto-save-interval",
            (n) => ngettext ("minute", "minutes", n));

        var reopen_checkbutton = builder.get_object ("reopen_checkbutton");
        settings.bind ("reopen-files", reopen_checkbutton, "active",
            SettingsBindFlags.DEFAULT);
    }

    private void init_font_and_colors_tab (Builder builder)
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");

        var default_font_checkbutton =
            builder.get_object ("default_font_checkbutton") as Button;
        settings.bind ("use-default-font", default_font_checkbutton, "active",
            SettingsBindFlags.DEFAULT);
        set_system_font_label (default_font_checkbutton);

        AppSettings app_settings = AppSettings.get_default ();
        app_settings.notify["system-font"].connect (() =>
        {
            set_system_font_label (default_font_checkbutton);
        });

        var font_button = builder.get_object ("font_button");
        settings.bind ("editor-font", font_button, "font-name",
            SettingsBindFlags.DEFAULT);

        var font_hbox = builder.get_object ("font_hbox") as Widget;
        set_sensitivity (settings, "use-default-font", font_hbox, false);

        TreeView schemes_treeview = builder.get_object ("schemes_treeview") as TreeView;
        string current_scheme_id = settings.get_string ("scheme");
        init_schemes_treeview (schemes_treeview, current_scheme_id);

        // the scheme has changed in the treeview -> update gsettings
        schemes_treeview.cursor_changed.connect ((treeview) =>
        {
            TreePath tree_path;
            TreeIter iter;
            schemes_treeview.get_cursor (out tree_path, null);

            TreeModel model = treeview.model;
            model.get_iter (out iter, tree_path);

            string id;
            model.get (iter, StyleSchemes.ID, out id, -1);

            settings.set_string ("scheme", id);
        });

        // the scheme has changed in gsettings -> update the treeview
        settings.changed["scheme"].connect ((setting, key) =>
        {
            string val = setting.get_string (key);

            TreeModel model = schemes_treeview.model;
            TreeIter iter;
            bool valid = model.get_iter_first (out iter);

            while (valid)
            {
                string scheme;
                model.get (iter, StyleSchemes.ID, out scheme, -1);
                if (scheme == val)
                {
                    TreeSelection select = schemes_treeview.get_selection ();
                    select.select_iter (iter);
                    return;
                }
                valid = model.iter_next (ref iter);
            }
        });
    }

    private void init_latex_tab (Builder builder)
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.latex");

        var interactive_comp_checkbutton =
            builder.get_object ("interactive_comp_checkbutton");
        settings.bind ("interactive-completion", interactive_comp_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var interactive_comp_spinbutton =
            builder.get_object ("interactive_comp_spinbutton") as SpinButton;
        set_spin_button_range (interactive_comp_spinbutton, settings,
            "interactive-completion-num");
        settings.bind ("interactive-completion-num", interactive_comp_spinbutton, "value",
            SettingsBindFlags.DEFAULT);
        set_sensitivity (settings, "interactive-completion",
            interactive_comp_spinbutton);

        Label interactive_comp_label =
            builder.get_object ("interactive_comp_label") as Label;
        set_plural (interactive_comp_label, settings, "interactive-completion-num",
            (n) => ngettext ("character", "characters", n));

        var document_view_program = builder.get_object ("document_view_program");
        settings.bind ("document-view-program", document_view_program, "text",
            SettingsBindFlags.DEFAULT);

        var latexmk_checkbutton = builder.get_object ("latexmk_checkbutton");
        settings.bind ("latexmk-always-show-all", latexmk_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        var build_tools_view = builder.get_object ("build_tools_treeview") as TreeView;
        init_build_tools_treeview (build_tools_view);

        Button bt_properties = builder.get_object ("build_tool_properties") as Button;
        bt_properties.clicked.connect (() =>
        {
            int num = Utils.get_selected_row (build_tools_view);
            if (0 <= num)
                run_build_tool_dialog (num);
        });

        Button bt_new = builder.get_object ("build_tool_new") as Button;
        bt_new.clicked.connect (() =>
        {
            run_build_tool_dialog (-1);
        });

        Button bt_copy = builder.get_object ("build_tool_copy") as Button;
        bt_copy.clicked.connect (() =>
        {
            int selected_row = Utils.get_selected_row (build_tools_view);
            if (selected_row < 0)
                return;

            BuildTools build_tools = BuildTools.get_default ();
            BuildTool? tool = build_tools.get (selected_row);
            return_if_fail (tool != null);

            tool.show = false;
            tool.label = _("%s [copy]").printf (tool.label);
            build_tools.insert (selected_row + 1, tool);

            update_build_tools_store ();
        });

        Button bt_up = builder.get_object ("build_tool_up") as Button;
        bt_up.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (build_tools_view, out iter1);
            if (i != -1 && i > 0)
            {
                iter2 = iter1;
                if (Utils.tree_model_iter_prev (build_tools_store, ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    BuildTools.get_default ().move_up (i);
                }
            }
        });

        Button bt_down = builder.get_object ("build_tool_down") as Button;
        bt_down.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (build_tools_view, out iter1);
            if (i != -1)
            {
                iter2 = iter1;
                if (build_tools_store.iter_next (ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    BuildTools.get_default ().move_down (i);
                }
            }
        });

        Button bt_delete = builder.get_object ("build_tool_delete") as Button;
        bt_delete.clicked.connect (() =>
        {
            TreeIter iter;
            int selected_row = Utils.get_selected_row (build_tools_view, out iter);
            if (selected_row == -1)
                return;

            string label;
            TreeModel model = (TreeModel) build_tools_store;
            model.get (iter, BuildToolColumn.LABEL, out label, -1);

            Dialog dialog = new MessageDialog (this, DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION, ButtonsType.NONE,
                _("Do you really want to delete the build tool \"%s\"?"),
                label);

            dialog.add_buttons (Stock.CANCEL, ResponseType.CANCEL,
                Stock.DELETE, ResponseType.YES);

            if (dialog.run () == ResponseType.YES)
            {
                build_tools_store.remove (iter);
                BuildTools.get_default ().delete (selected_row);
            }

            dialog.destroy ();
        });

        Button bt_reset = builder.get_object ("build_tool_reset") as Button;
        bt_reset.clicked.connect (() =>
        {
            Dialog dialog = get_reset_all_confirm_dialog (
                _("Do you really want to reset all build tools?"));

            if (dialog.run () == ResponseType.YES)
            {
                BuildTools.get_default ().reset_all ();
                update_build_tools_store ();
            }

            dialog.destroy ();
        });
    }

    private void init_other_tab (Builder builder)
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");
        GLib.Settings latex_settings =
            new GLib.Settings ("org.gnome.latexila.preferences.latex");
        GLib.Settings fb_settings =
            new GLib.Settings ("org.gnome.latexila.preferences.file-browser");

        var nb_most_used_symbols =
            builder.get_object ("nb_most_used_symbols") as SpinButton;
        set_spin_button_range (nb_most_used_symbols, settings, "nb-most-used-symbols");
        settings.bind ("nb-most-used-symbols", nb_most_used_symbols, "value",
            SettingsBindFlags.DEFAULT);

        var confirm_clean_up_checkbutton =
            builder.get_object ("confirm_clean_up_checkbutton");
        latex_settings.bind ("no-confirm-clean", confirm_clean_up_checkbutton, "active",
            SettingsBindFlags.DEFAULT);

        Widget auto_clean_up_checkbutton =
            builder.get_object ("auto_clean_up_checkbutton") as Widget;
        latex_settings.bind ("automatic-clean", auto_clean_up_checkbutton, "active",
            SettingsBindFlags.DEFAULT);
        set_sensitivity (latex_settings, "no-confirm-clean", auto_clean_up_checkbutton);

        var clean_up_entry = builder.get_object ("clean_up_entry");
        latex_settings.bind ("clean-extensions", clean_up_entry, "text",
            SettingsBindFlags.DEFAULT);

        var file_browser_show_all = builder.get_object ("file_browser_show_all");
        fb_settings.bind ("show-all-files", file_browser_show_all, "active",
            SettingsBindFlags.DEFAULT);

        Widget file_browser_except =
            builder.get_object ("file_browser_except") as Widget;
        fb_settings.bind ("show-all-files-except", file_browser_except, "active",
            SettingsBindFlags.DEFAULT);

        Widget file_browser_show_hidden =
            builder.get_object ("file_browser_show_hidden") as Widget;
        fb_settings.bind ("show-hidden-files", file_browser_show_hidden, "active",
            SettingsBindFlags.DEFAULT);

        set_sensitivity (fb_settings, "show-all-files", file_browser_except);
        set_sensitivity (fb_settings, "show-all-files", file_browser_show_hidden);

        Widget file_browser_entry =
            builder.get_object ("file_browser_entry") as Widget;
        fb_settings.bind ("file-extensions", file_browser_entry, "text",
            SettingsBindFlags.DEFAULT);
        set_sensitivity (fb_settings, "show-all-files", file_browser_entry, false);
    }

    private void set_sensitivity (GLib.Settings settings, string key, Widget widget,
        bool must_be_enabled = true)
    {
        bool val = settings.get_boolean (key);
        widget.set_sensitive (must_be_enabled ? val : ! val);

        settings.changed[key].connect ((setting, k) =>
        {
            bool v = setting.get_boolean (k);
            widget.set_sensitive (must_be_enabled ? v : ! v);
        });
    }

    private void set_system_font_label (Button button)
    {
        AppSettings app_settings = AppSettings.get_default ();
        string label = _("Use the system fixed width font (%s)")
            .printf (app_settings.system_font);
        button.set_label (label);
    }

    private void set_plural (Label label, GLib.Settings settings, string key,
        Plural plural)
    {
        uint val;
        settings.get (key, "u", out val);
        label.label = plural (val);

        settings.changed[key].connect ((setting, k) =>
        {
            uint v;
            setting.get (k, "u", out v);
            label.label = plural (v);
        });
    }

    private void set_spin_button_range (SpinButton spin_button, GLib.Settings settings,
        string key)
    {
        Variant range = settings.get_range (key);

        string range_type;
        Variant range_contents;
        range.get ("(sv)", out range_type, out range_contents);

        return_if_fail (range_type == "range");

        uint min;
        uint max;
        range_contents.get ("(uu)", out min, out max);

        uint cur_value;
        settings.get (key, "u", out cur_value);

        Adjustment adjustment = new Adjustment ((double) cur_value, (double) min,
            (double) max, 1.0, 0, 0);
        spin_button.set_adjustment (adjustment);
    }

    private enum StyleSchemes
    {
        ID,
        DESC,
        N_COLUMNS
    }

    private void init_schemes_treeview (TreeView treeview, string current_id)
    {
        ListStore list_store = new ListStore (StyleSchemes.N_COLUMNS, typeof (string),
            typeof (string));
        list_store.set_sort_column_id (StyleSchemes.ID, SortType.ASCENDING);
        treeview.set_model (list_store);

        CellRendererText renderer = new CellRendererText ();
        TreeViewColumn column = new TreeViewColumn.with_attributes (
            "Name and description", renderer,
            "markup", StyleSchemes.DESC, null);
        treeview.append_column (column);

        TreeSelection select = treeview.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        /* fill style scheme list store */
        SourceStyleSchemeManager manager = SourceStyleSchemeManager.get_default ();
        foreach (string id in manager.get_scheme_ids ())
        {
            SourceStyleScheme scheme = manager.get_scheme (id);
            string desc = "<b>%s</b> - %s".printf (scheme.name, scheme.description);
            TreeIter iter;
            list_store.append (out iter);
            list_store.set (iter,
                StyleSchemes.ID, scheme.id,
                StyleSchemes.DESC, desc,
                -1);

            if (id == current_id)
                select.select_iter (iter);
        }
    }

    private enum BuildToolColumn
    {
        SHOW,
        PIXBUF,
        LABEL,
        DESCRIPTION,
        N_COLUMNS
    }

    private void init_build_tools_treeview (TreeView build_tools_view)
    {
        build_tools_store = new ListStore (BuildToolColumn.N_COLUMNS, typeof (bool),
            typeof (string), typeof (string), typeof (string));
        build_tools_view.set_model (build_tools_store);

        TreeViewColumn active_column = new TreeViewColumn ();
        active_column.set_title (_("Active"));
        build_tools_view.append_column (active_column);

        CellRendererToggle toggle_renderer = new CellRendererToggle ();
        active_column.pack_start (toggle_renderer, false);
        active_column.set_attributes (toggle_renderer,
          "active", BuildToolColumn.SHOW,
          null);

        TreeViewColumn label_column = new TreeViewColumn ();
        label_column.set_title (_("Label"));
        build_tools_view.append_column (label_column);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        label_column.pack_start (pixbuf_renderer, false);
        label_column.set_attributes (pixbuf_renderer,
          "stock-id", BuildToolColumn.PIXBUF,
          null);

        CellRendererText text_renderer = new CellRendererText ();
        label_column.pack_start (text_renderer, true);
        label_column.set_attributes (text_renderer,
          "text", BuildToolColumn.LABEL,
          null);

        build_tools_view.set_tooltip_column (BuildToolColumn.DESCRIPTION);

        TreeSelection select = build_tools_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        /* fill list store */
        update_build_tools_store ();

        /* show/hide build tool */
        toggle_renderer.toggled.connect ((path_string) =>
        {
            TreeIter iter;
            build_tools_store.get_iter_from_string (out iter, path_string);
            bool val;
            TreeModel model = (TreeModel) build_tools_store;
            model.get (iter, BuildToolColumn.SHOW, out val, -1);

            val = ! val;
            build_tools_store.set (iter, BuildToolColumn.SHOW, val, -1);

            int num = int.parse (path_string);
            BuildTools build_tools = BuildTools.get_default ();
            BuildTool build_tool = build_tools[num];
            build_tool.show = val;

            build_tools.update (num, build_tool);
        });

        /* double-click */
        build_tools_view.row_activated.connect ((path, column) =>
        {
            if (column == label_column)
            {
                int num = path.get_indices ()[0];
                run_build_tool_dialog (num);
            }
        });
    }

    private void update_build_tools_store ()
    {
        build_tools_store.clear ();

        foreach (BuildTool tool in BuildTools.get_default ())
        {
            TreeIter iter;
            build_tools_store.append (out iter);
            build_tools_store.set (iter,
                BuildToolColumn.SHOW, tool.show,
                BuildToolColumn.PIXBUF, tool.icon,
                BuildToolColumn.LABEL, tool.label,
                BuildToolColumn.DESCRIPTION, Markup.escape_text (tool.description),
                -1);
        }
    }

    private Dialog get_reset_all_confirm_dialog (string msg)
    {
        Dialog dialog = new MessageDialog (this, DialogFlags.DESTROY_WITH_PARENT,
            MessageType.QUESTION, ButtonsType.NONE, "%s", msg);

        dialog.add_button (Stock.CANCEL, ResponseType.CANCEL);

        Button button = new Button.with_label (_("Reset All"));
        Image image = new Image.from_stock (Stock.CLEAR, IconSize.BUTTON);
        button.set_image (image);
        button.show_all ();
        dialog.add_action_widget (button, ResponseType.YES);

        return dialog;
    }

    private void run_build_tool_dialog (int num)
    {
        if (BuildToolDialog.show_me (get_transient_for (), num))
            update_build_tools_store ();
    }
}
