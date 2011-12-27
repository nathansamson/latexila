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

/* Ugly use of global variables... */
private bool option_version = false;
private bool option_new_document = false;
private bool option_new_window = false;
private string[] remaining_args;

private const OptionEntry[] options =
{
    { "version", 'V', 0, OptionArg.NONE, ref option_version,
    N_("Show the application's version"), null },

    { "new-document", 'n', 0, OptionArg.NONE, ref option_new_document,
    N_("Create new document"), null },

    { "new-window", '\0', 0, OptionArg.NONE, ref option_new_window,
    N_("Create a new top-level window in an existing instance of LaTeXila"), null },

    { "", '\0', 0, OptionArg.FILENAME_ARRAY, ref remaining_args,
    null, "[FILE...]" },

    { null }
};

public class Latexila : Gtk.Application
{
    struct StockIcon
    {
        public string filename;
        public string stock_id;
    }

    private const StockIcon[] stock_icons =
    {
        { Config.DATA_DIR + "/images/icons/compile_dvi.png", "compile_dvi" },
        { Config.DATA_DIR + "/images/icons/compile_pdf.png", "compile_pdf" },
        { Config.DATA_DIR + "/images/icons/compile_ps.png", "compile_ps" },
        { Config.DATA_DIR + "/images/icons/view_dvi.png", "view_dvi" },
        { Config.DATA_DIR + "/images/icons/view_pdf.png", "view_pdf" },
        { Config.DATA_DIR + "/images/icons/view_ps.png", "view_ps" },
        { Config.DATA_DIR + "/images/icons/textbf.png", "bold" },
        { Config.DATA_DIR + "/images/icons/textit.png", "italic" },
        { Config.DATA_DIR + "/images/icons/texttt.png", "typewriter" },
        { Config.DATA_DIR + "/images/icons/textsl.png", "slanted" },
        { Config.DATA_DIR + "/images/icons/textsc.png", "small_caps" },
        { Config.DATA_DIR + "/images/icons/textsf.png", "sans_serif" },
        { Config.DATA_DIR + "/images/icons/roman.png", "roman" },
        { Config.DATA_DIR + "/images/icons/underline.png", "underline" },
        { Config.DATA_DIR + "/images/misc-math/set-R.png", "blackboard" },
        { Config.DATA_DIR + "/images/icons/sectioning-part.png", "sectioning-part" },
        { Config.DATA_DIR + "/images/icons/sectioning-chapter.png",
            "sectioning-chapter" },
        { Config.DATA_DIR + "/images/icons/sectioning-section.png",
            "sectioning-section" },
        { Config.DATA_DIR + "/images/icons/sectioning-subsection.png",
            "sectioning-subsection" },
        { Config.DATA_DIR + "/images/icons/sectioning-subsubsection.png",
            "sectioning-subsubsection" },
        { Config.DATA_DIR + "/images/icons/sectioning-paragraph.png",
            "sectioning-paragraph" },
        { Config.DATA_DIR + "/images/icons/character-size.png", "character-size" },
        { Config.DATA_DIR + "/images/icons/list-itemize.png", "list-itemize" },
        { Config.DATA_DIR + "/images/icons/list-enumerate.png", "list-enumerate" },
        { Config.DATA_DIR + "/images/icons/list-description.png", "list-description" },
        { Config.DATA_DIR + "/images/icons/list-item.png", "list-item" },
        { Config.DATA_DIR + "/images/icons/references.png", "references" },
        { Config.DATA_DIR + "/images/icons/math.png", "math" },
        { Config.DATA_DIR + "/images/icons/math-centered.png", "math-centered" },
        { Config.DATA_DIR + "/images/icons/math-numbered.png", "math-numbered" },
        { Config.DATA_DIR + "/images/icons/math-array.png", "math-array" },
        { Config.DATA_DIR + "/images/icons/math-numbered-array.png",
            "math-numbered-array" },
        { Config.DATA_DIR + "/images/icons/math-superscript.png", "math-superscript" },
        { Config.DATA_DIR + "/images/icons/math-subscript.png", "math-subscript" },
        { Config.DATA_DIR + "/images/icons/math-frac.png", "math-frac" },
        { Config.DATA_DIR + "/images/icons/math-square-root.png", "math-square-root" },
        { Config.DATA_DIR + "/images/icons/math-nth-root.png", "math-nth-root" },
        { Config.DATA_DIR + "/images/icons/mathcal.png", "mathcal" },
        { Config.DATA_DIR + "/images/icons/mathfrak.png", "mathfrak" },
        { Config.DATA_DIR + "/images/icons/delimiters-left.png", "delimiters-left" },
        { Config.DATA_DIR + "/images/icons/delimiters-right.png", "delimiters-right" },
        { Config.DATA_DIR + "/images/icons/badbox.png", "badbox" },
        { Config.DATA_DIR + "/images/icons/logviewer.png", "view_log" },
        { Config.DATA_DIR + "/images/greek/01.png", "symbol_alpha" },
        { Config.DATA_DIR + "/images/icons/accent0.png", "accent0" },
        { Config.DATA_DIR + "/images/icons/accent1.png", "accent1" },
        { Config.DATA_DIR + "/images/icons/accent2.png", "accent2" },
        { Config.DATA_DIR + "/images/icons/accent3.png", "accent3" },
        { Config.DATA_DIR + "/images/icons/accent4.png", "accent4" },
        { Config.DATA_DIR + "/images/icons/accent5.png", "accent5" },
        { Config.DATA_DIR + "/images/icons/accent6.png", "accent6" },
        { Config.DATA_DIR + "/images/icons/accent7.png", "accent7" },
        { Config.DATA_DIR + "/images/icons/accent8.png", "accent8" },
        { Config.DATA_DIR + "/images/icons/accent9.png", "accent9" },
        { Config.DATA_DIR + "/images/icons/accent10.png", "accent10" },
        { Config.DATA_DIR + "/images/icons/accent11.png", "accent11" },
        { Config.DATA_DIR + "/images/icons/accent12.png", "accent12" },
        { Config.DATA_DIR + "/images/icons/accent13.png", "accent13" },
        { Config.DATA_DIR + "/images/icons/accent14.png", "accent14" },
        { Config.DATA_DIR + "/images/icons/accent15.png", "accent15" },
        { Config.DATA_DIR + "/images/icons/mathaccent0.png", "mathaccent0" },
        { Config.DATA_DIR + "/images/icons/mathaccent1.png", "mathaccent1" },
        { Config.DATA_DIR + "/images/icons/mathaccent2.png", "mathaccent2" },
        { Config.DATA_DIR + "/images/icons/mathaccent3.png", "mathaccent3" },
        { Config.DATA_DIR + "/images/icons/mathaccent4.png", "mathaccent4" },
        { Config.DATA_DIR + "/images/icons/mathaccent5.png", "mathaccent5" },
        { Config.DATA_DIR + "/images/icons/mathaccent6.png", "mathaccent6" },
        { Config.DATA_DIR + "/images/icons/mathaccent7.png", "mathaccent7" },
        { Config.DATA_DIR + "/images/icons/mathaccent8.png", "mathaccent8" },
        { Config.DATA_DIR + "/images/icons/mathaccent9.png", "mathaccent9" },
        { Config.DATA_DIR + "/images/icons/mathaccent10.png", "mathaccent10" },
        { Config.DATA_DIR + "/images/icons/completion_choice.png", "completion_choice" },
        { Config.DATA_DIR + "/images/icons/completion_cmd.png", "completion_cmd" },
        { Config.DATA_DIR + "/images/icons/tree_part.png", "tree_part" },
        { Config.DATA_DIR + "/images/icons/tree_chapter.png", "tree_chapter" },
        { Config.DATA_DIR + "/images/icons/tree_section.png", "tree_section" },
        { Config.DATA_DIR + "/images/icons/tree_subsection.png", "tree_subsection" },
        { Config.DATA_DIR + "/images/icons/tree_subsubsection.png",
            "tree_subsubsection" },
        { Config.DATA_DIR + "/images/icons/tree_paragraph.png", "tree_paragraph" },
        { Config.DATA_DIR + "/images/icons/tree_todo.png", "tree_todo" },
        { Config.DATA_DIR + "/images/icons/tree_label.png", "tree_label" },
        { Config.DATA_DIR + "/images/icons/table.png", "table" }
    };

    public static int NEW_WINDOW = 1;
    private static Latexila instance = null;
    public unowned List<MainWindow> windows {get; private set; }
    public MainWindow active_window { get; private set; }

    /* Latexila is a singleton
     * We must use Latexila.get_default ()
     */
    private Latexila ()
    {
        Object(application_id: "org.gnome.latexilla",
               flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
        command_line.connect(receive_command_line);
        startup.connect(on_startup);
        activate.connect(on_activate);
    }

    public static Latexila get_default ()
    {
        if (instance == null)
            instance = new Latexila ();
        return instance;
    }

    // get all the documents currently opened
    public List<Document> get_documents ()
    {
        List<Document> res = null;
        foreach (MainWindow w in windows)
            res.concat (w.get_documents ());
        return res;
    }

    // get all the document views
    public List<DocumentView> get_views ()
    {
        List<DocumentView> res = null;
        foreach (MainWindow w in windows)
            res.concat (w.get_views ());
        return res;
    }

    public void on_activate()
    {
        /*uint workspace = data.get_workspace ();
        Gdk.Screen screen = data.get_screen ();

        // if active_window not on current workspace, try to find an other window on the
        // current workspace.
        if (! active_window.is_on_workspace_screen (screen, workspace))
        {
            bool found = false;
            foreach (MainWindow w in windows)
            {
                if (w == active_window)
                    continue;
                if (w.is_on_workspace_screen (screen, workspace))
                {
                    found = true;
                    active_window = w;
                    break;
                }
            }

            if (! found)
                create_window (screen);
        }*/
        active_window.present ();
    }

    public MainWindow create_window (Gdk.Screen? screen = null)
    {
        if (active_window != null)
            active_window.save_state (true);

        MainWindow window = new MainWindow ();
        add_window(window);
        windows.append(window);
        active_window = window;
        notify_property ("active-window");

        if (screen != null)
            window.set_screen (screen);

        window.destroy.connect (() =>
        {
            remove_window(window);
            windows.remove (window);
            if (windows.length () == 0)
            {
                Projects.get_default ().save ();
                BuildTools.get_default ().save ();
                MostUsedSymbols.get_default ().save ();
            }
            else if (window == active_window)
            {
                active_window = (MainWindow) windows.data;
                notify_property ("active-window");
            }
        });

        window.focus_in_event.connect (() =>
        {
            active_window = window;
            notify_property ("active-window");
            return false;
        });

        window.show ();
        return window;
    }

    public void create_document ()
    {
        active_window.create_tab (true);
    }

    public void open_documents (
        [CCode (array_length = false, array_null_terminated = true)] string[] uris)
    {
        bool jump_to = true;
        foreach (string uri in uris)
        {
            if (uri.length == 0)
                continue;
            File location = File.new_for_uri (uri);
            active_window.open_document (location, jump_to);
            jump_to = false;
        }
    }
    
    public int receive_command_line(GLib.ApplicationCommandLine command_line)
    {
        OptionContext context =
            new OptionContext (_("- Integrated LaTeX Environment for GNOME"));
        context.add_main_entries (options, Config.GETTEXT_PACKAGE);
        context.add_group (Gtk.get_option_group (false));
        // Enabling help will close the primary instance...
        context.set_help_enabled (false);

        try
        {
            string[] args = command_line.get_arguments();
            unowned string[] args_mock = args;
            context.parse (ref args_mock);
        }
        catch (OptionError e)
        {
            warning ("%s", e.message);
            command_line.printerr(_("Run '%s --help' to see a full list of available command line options.\n"),
                command_line.get_arguments()[0]);
            return 1;
        }

        if (option_version)
        {
            command_line.print ("%s %s\n", Config.APP_NAME, Config.APP_VERSION);
            return 0;
        }

        // When running locally we are the first instance, and we ignore
        // --new-window.
        if (option_new_window && !get_is_remote())
        {
            create_window();
        }

        if (remaining_args.length != 0)
        {
            GLib.File[] files_to_open = {};
            // since remaining_args.length == 0, we use a dynamic array
            foreach (string arg in remaining_args)
            {
                // The command line argument can be absolute or relative.
                // With URI's, that's always absolute, so no problem.
                files_to_open += File.new_for_path (arg);
            }
            open(files_to_open, "");
        }
        
        if (option_new_document)
        {
            create_document();
        }
        activate();
        return 0;
    }
    
    public void on_startup() {
        /* personal style */
        // make the close buttons in tabs smaller
        Gtk.rc_parse_string ("""
            style "my-button-style"
            {
                GtkWidget::focus-padding = 0
                GtkWidget::focus-line-width = 0
                xthickness = 0
                ythickness = 0
            }
            widget "*.my-close-button" style "my-button-style"
        """);

        /* application icons */
        string[] filenames =
        {
            Config.ICONS_DIR + "/16x16/apps/latexila.png",
            Config.ICONS_DIR + "/22x22/apps/latexila.png",
            Config.ICONS_DIR + "/24x24/apps/latexila.png",
            Config.ICONS_DIR + "/32x32/apps/latexila.png",
            Config.ICONS_DIR + "/48x48/apps/latexila.png"
        };

        List<Gdk.Pixbuf> list = null;
        foreach (string filename in filenames)
        {
            try
            {
                list.append (new Gdk.Pixbuf.from_file (filename));
            }
            catch (Error e)
            {
                warning ("Error with an icon: %s", e.message);
            }
        }

        Gtk.Window.set_default_icon_list (list);

        register_my_stock_icons ();
        add_theme_icon_to_stock ("image-x-generic", "image");

        AppSettings.get_default ();
        create_window ();
        
        /* reopen files on startup */
        GLib.Settings editor_settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");
        if (editor_settings.get_boolean ("reopen-files"))
        {
            GLib.Settings window_settings =
                new GLib.Settings ("org.gnome.latexila.state.window");

            string[] uris = window_settings.get_strv ("documents");
            open_documents (uris);
        }
    }

    private void register_my_stock_icons ()
    {
        Gtk.IconFactory icon_factory = new Gtk.IconFactory ();

        foreach (StockIcon icon in stock_icons)
        {
            Gtk.IconSet icon_set = new Gtk.IconSet ();
            Gtk.IconSource icon_source = new Gtk.IconSource ();
            icon_source.set_filename (icon.filename);
            icon_set.add_source (icon_source);
            icon_factory.add (icon.stock_id, icon_set);
        }

        icon_factory.add_default ();
    }

    private void add_theme_icon_to_stock (string icon_name, string stock_id)
    {
        Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        Gtk.IconSet icon_set = new Gtk.IconSet ();

        Gtk.IconSize[] sizes =
        {
            Gtk.IconSize.MENU,
            Gtk.IconSize.SMALL_TOOLBAR,
            Gtk.IconSize.LARGE_TOOLBAR,
            Gtk.IconSize.BUTTON,
            Gtk.IconSize.DND,
            Gtk.IconSize.DIALOG
        };

        foreach (Gtk.IconSize size in sizes)
        {
            int nb_pixels;
            Gtk.icon_size_lookup (size, out nb_pixels, null);

            Gdk.Pixbuf pixbuf = null;
            try
            {
                pixbuf = theme.load_icon (icon_name, nb_pixels, 0);
            }
            catch (Error e)
            {
                warning ("Get theme icon failed: %s", e.message);
                continue;
            }

            Gtk.IconSource icon_source = new Gtk.IconSource ();
            icon_source.set_pixbuf (pixbuf);
            icon_source.set_size (size);
            icon_set.add_source (icon_source);
        }

        Gtk.IconFactory icon_factory = new Gtk.IconFactory ();
        icon_factory.add (stock_id, icon_set);
        icon_factory.add_default ();
    }
}
