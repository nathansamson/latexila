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

using Gee;

public enum PostProcessorType
{
    // please keep these items sorted in alphabetical order (for the build tool dialog)
    ALL_OUTPUT = 0,
    LATEX,
    LATEXMK,
    NO_OUTPUT,
    RUBBER,
    N_POST_PROCESSORS
}

public struct BuildJob
{
    public bool must_succeed;
    public PostProcessorType post_processor;
    public string command;
}

public struct BuildTool
{
    public string description;
    public string extensions;
    public string label;
    public string icon;
    public bool show;
    public bool compilation;
    public ArrayList<BuildJob?> jobs;
}

public enum DocType
{
    DVI,
    PDF,
    PS,
    LAST
}

public class BuildTools
{
    private static BuildTools _instance = null;

    private static string[] _post_processor_names =
    {
        "all-output",
        "latex",
        "latexmk",
        "no-output",
        "rubber"
    };

    private LinkedList<BuildTool?> _build_tools;
    private BuildTool _cur_tool;
    private BuildJob _cur_job;

    private bool _modified = false;

    private BuildTools ()
    {
        load ();
    }

    public static BuildTools get_default ()
    {
        if (_instance == null)
            _instance = new BuildTools ();
        return _instance;
    }

    public BuildTool? get (int id)
    {
        return_val_if_fail (id >= 0 && id < _build_tools.size, null);
        return _build_tools[id];
    }

    public Iterator<BuildTool?> iterator ()
    {
        return (Iterator<BuildTool?>) _build_tools.iterator ();
    }

    public BuildTool? get_view_doc (DocType type)
    {
        string[] icon = new string[DocType.LAST];
        icon[DocType.DVI] = "view_dvi";
        icon[DocType.PDF] = "view_pdf";
        icon[DocType.PS] = "view_ps";

        // we take the first match
        foreach (BuildTool build_tool in _build_tools)
        {
            if (build_tool.icon == icon[type])
                return build_tool;
        }

        return null;
    }

    public bool is_empty ()
    {
        return _build_tools.size == 0;
    }

    public void move_up (int num)
    {
        return_if_fail (num > 0);
        swap (num, num - 1);
    }

    public void move_down (int num)
    {
        return_if_fail (num < _build_tools.size - 1);
        swap (num, num + 1);
    }

    private void swap (int num1, int num2)
    {
        return_if_fail (_build_tools != null);

        BuildTool tool = _build_tools.get (num1);
        _build_tools.remove_at (num1);
        _build_tools.insert (num2, tool);
        update_all_menus ();
    }

    public void delete (int num)
    {
        return_if_fail (_build_tools != null);

        return_if_fail (num >= 0 && num < _build_tools.size);
        _build_tools.remove_at (num);
        update_all_menus ();
    }

    public void add (BuildTool tool)
    {
        return_if_fail (_build_tools != null);

        insert (_build_tools.size, tool);
    }

    public void insert (int pos, BuildTool tool)
    {
        return_if_fail (_build_tools != null);
        return_if_fail (0 <= pos && pos <= _build_tools.size);

        tool.compilation = is_compilation (tool.icon);
        _build_tools.insert (pos, tool);
        update_all_menus ();
    }

    public void update (int num, BuildTool tool, bool keep_show = false)
    {
        return_if_fail (_build_tools != null);
        return_if_fail (num >= 0 && num < _build_tools.size);
        BuildTool current_tool = _build_tools.get (num);

        if (keep_show)
            tool.show = current_tool.show;

        if (! is_equal (current_tool, tool))
        {
            tool.compilation = is_compilation (tool.icon);
            _build_tools.remove_at (num);
            _build_tools.insert (num, tool);
            update_all_menus ();
        }
    }

    public void reset_all ()
    {
        File file = get_user_config_file ();
        if (file.query_exists ())
            Utils.delete_file (file);
        load ();
        update_all_menus ();
    }

    private bool is_equal (BuildTool tool1, BuildTool tool2)
    {
        if (tool1.show != tool2.show
            || tool1.label != tool2.label
            || tool1.description != tool2.description
            || tool1.extensions != tool2.extensions
            || tool1.icon != tool2.icon
            || tool1.jobs.size != tool2.jobs.size)
            return false;

        for (int job_num = 0 ; job_num < tool1.jobs.size ; job_num++)
        {
            BuildJob job1 = tool1.jobs[job_num];
            BuildJob job2 = tool2.jobs[job_num];

            if (job1.command != job2.command
                || job1.must_succeed != job2.must_succeed
                || job1.post_processor != job2.post_processor)
                return false;
        }

        return true;
    }

    /*
    private void print_summary ()
    {
        stdout.printf ("\n=== build tools summary ===\n");
        foreach (BuildTool tool in _build_tools)
            stdout.printf ("%s\n", tool.label);
    }
    */

    private void update_all_menus ()
    {
        _modified = true;
        foreach (MainWindow window in Latexila.get_default ().windows)
            window.update_build_tools_menu ();
    }

    private bool is_compilation (string icon)
    {
        // If it's a compilation, the file browser is refreshed after the execution.
        return icon.contains ("compile")
            || icon == Gtk.Stock.EXECUTE
            || icon == Gtk.Stock.CONVERT;
    }

    private void load ()
    {
        _build_tools = new LinkedList<BuildTool?> ();

        // First, try to load the user config file if it exists.
        // Otherwise try to load the default file (from most desirable to least desirable,
        // depending of the current locale).

        File[] files = {};
        files += get_user_config_file ();

        unowned string[] language_names = Intl.get_language_names ();
        foreach (string language_name in language_names)
        {
            files += File.new_for_path (Path.build_filename (Config.DATA_DIR,
                "build_tools", language_name, "build_tools.xml"));
        }

        foreach (File file in files)
        {
            try
            {
                if (! file.query_exists ())
                    continue;

                uint8[] chars;
                file.load_contents (null, out chars);
                string contents = (string) (owned) chars;

                MarkupParser parser =
                    { parser_start, parser_end, parser_text, null, null };
                MarkupParseContext context =
                    new MarkupParseContext (parser, 0, this, null);
                context.parse (contents, -1);
                break;
            }
            catch (GLib.Error e)
            {
                warning ("Impossible to load build tools: %s", e.message);
            }
        }
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "tools":
            case "label":
            case "description":
                return;

            case "tool":
                _cur_tool = BuildTool ();
                _cur_tool.compilation = false;
                _cur_tool.jobs = new ArrayList<BuildJob?> ();

                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "show":
                            _cur_tool.show = bool.parse (attr_values[i]);
                            break;
                        case "extensions":
                            _cur_tool.extensions = attr_values[i];
                            break;
                        case "icon":
                            _cur_tool.icon = attr_values[i];
                            _cur_tool.compilation = is_compilation (attr_values[i]);
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "job":
                _cur_job = BuildJob ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "mustSucceed":
                            _cur_job.must_succeed = bool.parse (attr_values[i]);
                            break;
                        case "postProcessor":
                            _cur_job.post_processor = get_post_processor_type_from_name (
                                attr_values[i]);
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_end (MarkupParseContext context, string name) throws MarkupError
    {
        switch (name)
        {
            case "tools":
            case "label":
            case "description":
                return;

            case "tool":
                // the description is optional
                if (_cur_tool.description == null)
                    _cur_tool.description = _cur_tool.label;
                _build_tools.add (_cur_tool);
                break;

            case "job":
                _cur_tool.jobs.add (_cur_job);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_text (MarkupParseContext context, string text, size_t text_len)
        throws MarkupError
    {
        switch (context.get_element ())
        {
            case "job":
                _cur_job.command = text.strip ();
                break;
            case "label":
                _cur_tool.label = text.strip ();
                break;
            case "description":
                _cur_tool.description = text.strip ();
                break;
        }
    }

    public void save ()
    {
        return_if_fail (_build_tools != null);

        if (! _modified)
            return;

        string content = "<tools>";
        foreach (BuildTool tool in _build_tools)
        {
            content += "\n  <tool show=\"%s\" extensions=\"%s\" icon=\"%s\">\n".printf (
                tool.show.to_string (), tool.extensions, tool.icon);

            content += Markup.printf_escaped ("    <label>%s</label>\n", tool.label);
            content += Markup.printf_escaped ("    <description>%s</description>\n",
                tool.description);

            foreach (BuildJob job in tool.jobs)
            {
                content += "    <job mustSucceed=\"%s\" postProcessor=\"%s\">".printf (
                    job.must_succeed.to_string (),
                    get_post_processor_name_from_type (job.post_processor));

                content += Markup.printf_escaped ("%s</job>\n", job.command);
            }
            content += "  </tool>\n";
        }
        content += "</tools>\n";

        try
        {
            File file = get_user_config_file ();

            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            // a backup is made
            file.replace_contents (content, content.length, null, true,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save build tools: %s", e.message);
        }
    }

    private File get_user_config_file ()
    {
        string path = Path.build_filename (Environment.get_user_config_dir (),
            "latexila", "build_tools.xml", null);
        return File.new_for_path (path);
    }

    public static PostProcessorType? get_post_processor_type_from_name (string name)
    {
        for (int type = 0 ; type < PostProcessorType.N_POST_PROCESSORS ; type++)
        {
            if (_post_processor_names[type] == name)
                return (PostProcessorType) type;
        }

        return_val_if_reached (null);
    }

    public static string? get_post_processor_name_from_type (PostProcessorType type)
    {
        return_val_if_fail (type != PostProcessorType.N_POST_PROCESSORS, null);
        return _post_processor_names[type];
    }
}
