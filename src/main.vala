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

    Latexila latexila = Latexila.get_default();
    latexila.run(args);

    return 0;
}
