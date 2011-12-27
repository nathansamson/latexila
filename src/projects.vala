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

public struct Project
{
    public File directory;
    public File main_file;
}

public class Projects
{
    private static Projects instance = null;

    private LinkedList<Project?> projects;
    private bool modified = false;

    private Projects ()
    {
        projects = new LinkedList<Project?> ();

        /* load projects from the XML file */
        File file = get_xml_file ();
        if (! file.query_exists ())
            return;

        try
        {
            uint8[] chars;
            file.load_contents (null, out chars);
            string contents = (string) (owned) chars;

            MarkupParser parser = { parser_start, null, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);

            update_all_documents ();
            update_all_menus ();
        }
        catch (GLib.Error e)
        {
            warning ("Impossible to load the projects: %s", e.message);
        }
    }

    public static Projects get_default ()
    {
        if (instance == null)
            instance = new Projects ();
        return instance;
    }

    public Project? get (int id)
    {
        return_val_if_fail (id >= 0 && id < projects.size, null);
        return projects[id];
    }

    public Iterator<Project?> iterator ()
    {
        return (Iterator<Project?>) projects.iterator ();
    }

    private void update_all_menus ()
    {
        foreach (MainWindow window in Latexila.get_default ().windows)
            window.update_config_project_sensitivity ();
    }

    // returns true if project successfully added
    public bool add (Project new_project, out File conflict_file)
    {
        conflict_file = null;

        foreach (Project project in projects)
        {
            if (conflict (project.directory, new_project.directory))
            {
                conflict_file = project.directory;
                return false;
            }
        }

        projects.add (new_project);
        modified = true;

        // find if some opened documents are belonging to the new project
        GLib.List<Document> docs = Latexila.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id != -1)
                continue;

            if (doc.location.has_prefix (new_project.directory))
                doc.project_id = projects.size - 1;
        }

        update_all_menus ();

        return true;
    }

    // returns true if main file changed
    public bool change_main_file (int num, File new_main_file)
    {
        return_val_if_fail (num >= 0 && num < projects.size, false);
        Project project = projects[num];

        if (new_main_file.equal (project.main_file))
            return false;

        return_if_fail (new_main_file.has_prefix (project.directory));

        project.main_file = new_main_file;
        projects[num] = project;
        modified = true;

        // refresh docs
        GLib.List<Document> docs = Latexila.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id == num)
                doc.project_id = num;
        }

        return true;
    }

    public void delete (int num)
    {
        return_if_fail (num >= 0 && num < projects.size);
        projects.remove_at (num);
        modified = true;

        // refresh docs
        GLib.List<Document> docs = Latexila.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id == num)
                doc.project_id = -1;
            else if (doc.project_id > num)
                doc.project_id--;
        }

        update_all_menus ();
    }

    public void clear_all ()
    {
        projects.clear ();
        modified = true;
        update_all_documents ();
        update_all_menus ();
    }

    private void update_all_documents ()
    {
        GLib.List<Document> docs = Latexila.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            doc.project_id = -1;

            for (int i = 0 ; i < projects.size ; i++)
            {
                if (doc.location.has_prefix (projects[i].directory))
                {
                    doc.project_id = i;
                    break;
                }
            }
        }
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "projects":
                return;

            case "project":
                Project project = Project ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "directory":
                            project.directory = File.new_for_uri (attr_values[i]);
                            break;
                        case "main_file":
                            project.main_file = File.new_for_uri (attr_values[i]);
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                projects.add (project);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private File get_xml_file ()
    {
        string path = Path.build_filename (Environment.get_user_data_dir (),
            "latexila", "projects.xml", null);
        return File.new_for_path (path);
    }

    public void save ()
    {
        if (! modified)
            return;

        File file = get_xml_file ();

        // if empty, delete the file
        if (projects.size == 0)
        {
            Utils.delete_file (file);
            return;
        }

        string content = "<projects>\n";
        foreach (Project project in projects)
        {
            content += "  <project directory=\"%s\" main_file=\"%s\" />\n".printf (
                project.directory.get_uri (), project.main_file.get_uri ());
        }
        content += "</projects>\n";

        try
        {
            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (content, content.length, null, false,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save the projects: %s", e.message);
        }
    }

    // returns true if dir1 is a subdirectory of dir2, or inversely
    private bool conflict (File dir1, File dir2)
    {
        return dir1.has_prefix (dir2) || dir2.has_prefix (dir1) || dir1.equal (dir2);
    }

//    private void print_summary ()
//    {
//        stdout.printf ("\n=== PROJECTS ===\n");
//        foreach (Project project in projects)
//        {
//            stdout.printf ("\n= PROJECT =\n");
//            stdout.printf ("directory: %s\n", project.directory.get_parse_name ());
//            stdout.printf ("main file: %s\n", project.main_file.get_parse_name ());
//        }
//    }
}
