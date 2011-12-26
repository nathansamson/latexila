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

bool option_version;
bool option_new_document;
bool option_new_window;

[CCode (array_length = false, array_null_terminated = true)]
string[] remaining_args;

const OptionEntry[] options =
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

int main (string[] args)
{
    /* for GSettings: verify system data dirs */

    // We don't use Environment.get_system_data_dirs () because this function store the
    // value in a cache. If we change the value of the environment variable, the cache is
    // not modified...
    string? data_dirs_env = Environment.get_variable ("XDG_DATA_DIRS");
    if (data_dirs_env == null)
        data_dirs_env = "/usr/local/share:/usr/share";

    string[] data_dirs = data_dirs_env.split (":");
    if (! (Config.SCHEMA_DIR in data_dirs))
    {
        Environment.set_variable ("XDG_DATA_DIRS",
            Config.SCHEMA_DIR + ":" + data_dirs_env, true);
    }

    /* internationalisation */
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    Gtk.init (ref args);

    /* command line options */
    OptionContext context =
        new OptionContext (_("- Integrated LaTeX Environment for GNOME"));
    context.add_main_entries (options, Config.GETTEXT_PACKAGE);
    context.add_group (Gtk.get_option_group (false));

    try
    {
        context.parse (ref args);
    }
    catch (OptionError e)
    {
        warning ("%s", e.message);
        stderr.printf (_("Run '%s --help' to see a full list of available command line options.\n"),
            args[0]);
        return 1;
    }

    if (option_version)
    {
        stdout.printf ("%s %s\n", Config.APP_NAME, Config.APP_VERSION);
        return 0;
    }

    /* prepare commands */
//    bool command_open = false;
//    Unique.MessageData data = new Unique.MessageData ();
//
//    if (remaining_args.length != 0)
//    {
//        command_open = true;
//
//        // since remaining_args.length == 0, we use a dynamic array
//        string[] uris = {};
//        foreach (string arg in remaining_args)
//            // The command line argument can be absolute or relative.
//            // With URI's, that's always absolute, so no problem.
//            uris += File.new_for_path (arg).get_uri ();
//
//        data.set_uris (uris);
//    }
//
//    Unique.App app = new Unique.App ("org.gnome.latexila", null);
//    app.add_command ("new_window", Application.NEW_WINDOW);
//
//    if (app.is_running)
//    {
//        /* send commands */
//        bool ok = true;
//        if (option_new_window)
//        {
//            Unique.Response resp = app.send_message (Application.NEW_WINDOW, null);
//            ok = resp == Unique.Response.OK;
//        }
//        if (ok && command_open)
//        {
//            Unique.Response resp = app.send_message (Unique.Command.OPEN, data);
//            ok = resp == Unique.Response.OK;
//        }
//        if (ok && option_new_document)
//        {
//            Unique.Response resp = app.send_message (Unique.Command.NEW, null);
//            ok = resp == Unique.Response.OK;
//        }
//        if (! option_new_window && ! command_open && ! option_new_document)
//        {
//            Unique.Response resp = app.send_message (Unique.Command.ACTIVATE, null);
//            ok = resp == Unique.Response.OK;
//        }
//
//        if (! ok)
//            error ("Error: communication with first instance of LaTeXila failed\n");
//        return 0;
//    }

    /* start a new application */
    Application latexila = Application.get_default ();

    /* reopen files on startup */
    GLib.Settings editor_settings =
        new GLib.Settings ("org.gnome.latexila.preferences.editor");
    if (editor_settings.get_boolean ("reopen-files"))
    {
        GLib.Settings window_settings =
            new GLib.Settings ("org.gnome.latexila.state.window");

        string[] uris = window_settings.get_strv ("documents");
        latexila.open_documents (uris);
    }

    /* execute commands */
    // the --new-window option have no effect in this case
//    if (command_open)
//        latexila.open_documents (data.get_uris ());
    if (option_new_document)
        latexila.create_document ();

//    app.message_received.connect (latexila.message);
    Gtk.main ();

    return 0;
}
