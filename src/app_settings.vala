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

public class AppSettings : GLib.Settings
{
    private static AppSettings instance = null;

    private Settings editor;
    private Settings desktop_interface;
    private uint timeout_id = 0;

    public string system_font { get; private set; }

    /* AppSettings is a singleton */
    private AppSettings ()
    {
        Object (schema: "org.gnome.latexila");
        initialize ();
    }

    public static AppSettings get_default ()
    {
        if (instance == null)
            instance = new AppSettings ();
        return instance;
    }

    private void initialize ()
    {
        Settings prefs = get_child ("preferences");
        editor = prefs.get_child ("editor");

        // the desktop schemas are optional
        if (! Config.DESKTOP_SCHEMAS)
            system_font = "Monospace 10";
        else
        {
            desktop_interface = new Settings ("org.gnome.desktop.interface");
            system_font = desktop_interface.get_string ("monospace-font-name");

            desktop_interface.changed["monospace-font-name"].connect ((setting, key) =>
            {
                system_font = setting.get_string (key);
                if (editor.get_boolean ("use-default-font"))
                    set_font (system_font);
            });
        }

        editor.changed["use-default-font"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);
            string font = val ? system_font : editor.get_string ("editor-font");
            set_font (font);
        });

        editor.changed["editor-font"].connect ((setting, key) =>
        {
            if (editor.get_boolean ("use-default-font"))
                return;
            set_font (setting.get_string (key));
        });

        editor.changed["scheme"].connect ((setting, key) =>
        {
            string scheme_id = setting.get_string (key);

            Gtk.SourceStyleSchemeManager manager =
                Gtk.SourceStyleSchemeManager.get_default ();
            Gtk.SourceStyleScheme scheme = manager.get_scheme (scheme_id);

            foreach (Document doc in Latexila.get_default ().get_documents ())
                doc.style_scheme = scheme;

            // we don't use doc.set_style_scheme_from_string() for performance reason
        });

        editor.changed["tabs-size"].connect ((setting, key) =>
        {
            uint val;
            setting.get (key, "u", out val);

            foreach (DocumentView view in Latexila.get_default ().get_views ())
                view.tab_width = val;
        });

        editor.changed["insert-spaces"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);

            foreach (DocumentView view in Latexila.get_default ().get_views ())
                view.insert_spaces_instead_of_tabs = val;
        });

        editor.changed["display-line-numbers"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);

            foreach (DocumentView view in Latexila.get_default ().get_views ())
                view.show_line_numbers = val;
        });

        editor.changed["highlight-current-line"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);

            foreach (DocumentView view in Latexila.get_default ().get_views ())
                view.highlight_current_line = val;
        });

        editor.changed["bracket-matching"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);

            foreach (Document doc in Latexila.get_default ().get_documents ())
                doc.highlight_matching_brackets = val;
        });

        editor.changed["auto-save"].connect ((setting, key) =>
        {
            bool val = setting.get_boolean (key);

            foreach (Document doc in Latexila.get_default ().get_documents ())
                doc.tab.auto_save = val;
        });

        editor.changed["auto-save-interval"].connect ((setting, key) =>
        {
            uint val;
            setting.get (key, "u", out val);

            foreach (Document doc in Latexila.get_default ().get_documents ())
                doc.tab.auto_save_interval = val;
        });

        editor.changed["nb-most-used-symbols"].connect ((setting, key) =>
        {
            if (timeout_id != 0)
                Source.remove (timeout_id);
            timeout_id = Timeout.add_seconds (1, () =>
            {
                timeout_id = 0;
                Symbols.reload_most_used_symbols ();
                return false;
            });
        });
    }

    private void set_font (string font)
    {
        foreach (DocumentView view in Latexila.get_default ().get_views ())
            view.set_font_from_string (font);
    }
}
