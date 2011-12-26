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

private class BuildToolDialog : Dialog
{
    private static BuildToolDialog instance = null;

    private Entry entry_label;
    private Entry entry_desc;
    private Entry entry_extensions;
    private ComboBox combobox_icon;
    private Entry entry_command;
    private Button button_add;
    private TreeView treeview_jobs;
    private Button button_delete;
    private Button button_up;
    private Button button_down;

    private ListStore jobs_store;

    struct IconColumn
    {
        public string stock_id;
        public string label;
    }

    private const IconColumn[] icons =
    {
        { Stock.EXECUTE, N_("Execute") },
        { "compile_dvi", "LaTeX → DVI" },
        { "compile_pdf", "LaTeX → PDF" },
        { "compile_ps", "LaTeX → PS" },
        { Stock.CONVERT, N_("Convert") },
        { Stock.FILE, N_("View File") },
        { "view_dvi", N_("View DVI") },
        { "view_pdf", N_("View PDF") },
        { "view_ps", N_("View PS") }
    };

    enum JobColumn
    {
        COMMAND,
        MUST_SUCCEED,
        POST_PROCESSOR,
        N_COLUMNS
    }

    private BuildToolDialog ()
    {
        add_button (Stock.CANCEL, ResponseType.CANCEL);
        add_button (Stock.OK, ResponseType.OK);
        title = _("Build Tool");
        destroy_with_parent = true;
        border_width = 5;

        try
        {
            string path = Path.build_filename (Config.DATA_DIR, "ui", "build_tool.ui");
            Builder builder = new Builder ();
            builder.add_from_file (path);

            // get objects
            Box main_vbox = builder.get_object ("main_vbox") as Box;
            main_vbox.unparent ();

            entry_label = (Entry) builder.get_object ("entry_label");
            entry_desc = (Entry) builder.get_object ("entry_desc");
            entry_extensions = (Entry) builder.get_object ("entry_extensions");
            combobox_icon = (ComboBox) builder.get_object ("combobox_icon");
            entry_command = (Entry) builder.get_object ("entry_command");
            button_add = (Button) builder.get_object ("button_add");
            treeview_jobs = (TreeView) builder.get_object ("treeview_jobs");
            button_delete = (Button) builder.get_object ("button_delete");
            button_up = (Button) builder.get_object ("button_up");
            button_down = (Button) builder.get_object ("button_down");

            // packing widget
            Box content_area = get_content_area () as Box;
            content_area.pack_start (main_vbox);
            content_area.show_all ();

            init_icon_treeview ();
            init_jobs_treeview ();
            init_actions ();
        }
        catch (Error e)
        {
            string message = "Error: %s".printf (e.message);
            warning ("%s", message);

            Label label_error = new Label (message);
            label_error.set_line_wrap (true);
            Box content_area = get_content_area () as Box;
            content_area.pack_start (label_error, true, true, 0);
            content_area.show_all ();
        }
    }

    public static bool show_me (Window parent, int num)
    {
        if (instance == null)
        {
            instance = new BuildToolDialog ();

            // FIXME how to connect Widget.destroyed?
            instance.destroy.connect (() =>
            {
                if (instance != null)
                    instance = null;
            });
        }

        if (parent != instance.get_transient_for ())
            instance.set_transient_for (parent);

        instance.present ();
        instance.init (num);
        return instance.run_me (num);
    }

    private void init_icon_treeview ()
    {
        ListStore icon_store = new ListStore (2, typeof (string), typeof (string));

        // fill icon store
        foreach (IconColumn icon in icons)
        {
            TreeIter iter;
            icon_store.append (out iter);
            icon_store.set (iter, 0, icon.stock_id, 1, _(icon.label), -1);
        }

        // init combobox
        combobox_icon.set_model (icon_store);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        combobox_icon.pack_start (pixbuf_renderer, false);
        combobox_icon.set_attributes (pixbuf_renderer, "stock-id", 0, null);

        CellRendererText text_renderer = new CellRendererText ();
        combobox_icon.pack_start (text_renderer, true);
        combobox_icon.set_attributes (text_renderer, "text", 1, null);
    }

    private void init_jobs_treeview ()
    {
        jobs_store = new ListStore (JobColumn.N_COLUMNS,
            typeof (string),    // command
            typeof (bool),      // must succeed
            typeof (string)     // post processor
            );

        treeview_jobs.set_model (jobs_store);

        /* post processor list store */

        ListStore post_processor_store = new ListStore (1, typeof (string));

        for (int type = 0 ; type < PostProcessorType.N_POST_PROCESSORS ; type++)
        {
            TreeIter iterpp;
            post_processor_store.append (out iterpp);
            post_processor_store.set (iterpp,
                0, BuildTools.get_post_processor_name_from_type (
                    (PostProcessorType) type),
                -1);
        }

        /* cell renderers */

        CellRendererText text_renderer = new CellRendererText ();
        text_renderer.editable = true;

        TreeViewColumn column = new TreeViewColumn.with_attributes (_("Commands"),
            text_renderer, "text", JobColumn.COMMAND, null);
        column.set_resizable (true);
        treeview_jobs.append_column (column);

        CellRendererToggle toggle_renderer = new CellRendererToggle ();
        toggle_renderer.activatable = true;
        treeview_jobs.insert_column_with_attributes (-1, _("Must Succeed"),
            toggle_renderer, "active", JobColumn.MUST_SUCCEED, null);

        CellRendererCombo combo_renderer = new CellRendererCombo ();
        combo_renderer.editable = true;
        combo_renderer.model = post_processor_store;
        combo_renderer.text_column = 0;
        combo_renderer.has_entry = false;
        treeview_jobs.insert_column_with_attributes (-1, _("Post Processor"),
            combo_renderer, "text", JobColumn.POST_PROCESSOR, null);

        /* callbacks */

        text_renderer.edited.connect ((path_string, new_text) =>
        {
            TreeIter iter;
            jobs_store.get_iter_from_string (out iter, path_string);
            jobs_store.set (iter, JobColumn.COMMAND, new_text, -1);
        });

        toggle_renderer.toggled.connect ((path_string) =>
        {
            TreeIter iter;
            jobs_store.get_iter_from_string (out iter, path_string);
            bool val;
            TreeModel model = (TreeModel) jobs_store;
            model.get (iter, JobColumn.MUST_SUCCEED, out val, -1);
            jobs_store.set (iter, JobColumn.MUST_SUCCEED, ! val, -1);
        });

        combo_renderer.edited.connect ((path_string, new_text) =>
        {
            TreeIter iter;
            jobs_store.get_iter_from_string (out iter, path_string);
            jobs_store.set (iter, JobColumn.POST_PROCESSOR, new_text, -1);
        });
    }

    private void init_actions ()
    {
        button_add.clicked.connect (on_command_add);
        entry_command.activate.connect (on_command_add);

        button_delete.clicked.connect (() =>
        {
            TreeIter iter;
            int i = Utils.get_selected_row (treeview_jobs, out iter);
            if (i != -1)
                jobs_store.remove (iter);
        });

        button_up.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (treeview_jobs, out iter1);
            if (i != -1 && i > 0)
            {
                iter2 = iter1;
                if (Utils.tree_model_iter_prev (jobs_store, ref iter2))
                    jobs_store.swap (iter1, iter2);
            }
        });

        button_down.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (treeview_jobs, out iter1);
            if (i != -1)
            {
                iter2 = iter1;
                if (jobs_store.iter_next (ref iter2))
                    jobs_store.swap (iter1, iter2);
            }
        });
    }

    private void on_command_add ()
    {
        if (entry_command.text.strip () == "")
            return;

        TreeIter iter;
        jobs_store.append (out iter);
        jobs_store.set (iter,
            JobColumn.COMMAND, entry_command.text,
            JobColumn.MUST_SUCCEED, true,
            JobColumn.POST_PROCESSOR, BuildTools.get_post_processor_name_from_type (
                PostProcessorType.NO_OUTPUT),
            -1);
        entry_command.text = "";
    }

    private void init (int num)
    {
        entry_command.text = "";
        jobs_store.clear ();
        Utils.set_entry_error (entry_label, false);
        Utils.set_entry_error (entry_command, false);

        if (num == -1)
            instance.init_new_build_tool ();
        else
            instance.init_with_build_tool (BuildTools.get_default ()[num]);

        treeview_jobs.columns_autosize ();
    }

    private void init_new_build_tool ()
    {
        entry_label.text = "";
        entry_desc.text = "";
        entry_extensions.text = ".tex";
        combobox_icon.set_active (0);
    }

    private void init_with_build_tool (BuildTool tool)
    {
        entry_label.text = tool.label;
        entry_desc.text = tool.description;
        entry_extensions.text = tool.extensions;

        // set icon
        combobox_icon.set_active (0);
        for (int i = 0 ; i < icons.length ; i++)
        {
            if (icons[i].stock_id == tool.icon)
            {
                combobox_icon.set_active (i);
                break;
            }
        }

        // jobs
        jobs_store.clear ();
        foreach (BuildJob job in tool.jobs)
        {
            TreeIter iter;
            jobs_store.append (out iter);
            jobs_store.set (iter,
                JobColumn.COMMAND, job.command,
                JobColumn.MUST_SUCCEED, job.must_succeed,
                JobColumn.POST_PROCESSOR, BuildTools.get_post_processor_name_from_type (
                    job.post_processor),
                -1);
        }
    }

    private bool run_me (int num)
    {
        while (run () == ResponseType.OK)
        {
            /* check if the form is correctly filled */

            bool ok = true;

            // no label
            if (entry_label.text.strip () == "")
            {
                Utils.set_entry_error (entry_label, true);
                ok = false;
            }
            else
                Utils.set_entry_error (entry_label, false);

            // no job
            TreeIter iter;
            if (! jobs_store.get_iter_first (out iter))
            {
                Utils.set_entry_error (entry_command, true);
                ok = false;
            }
            else
                Utils.set_entry_error (entry_command, false);

            if (! ok)
                continue;

            /* generate a new build tool */

            BuildTool tool = BuildTool ();
            tool.label = entry_label.text.strip ();
            tool.description =
                entry_desc.text.strip () == "" ? tool.label : entry_desc.text.strip ();
            tool.extensions = entry_extensions.text.strip ();
            tool.jobs = new Gee.ArrayList<BuildJob?> ();

            combobox_icon.get_active_iter (out iter);
            TreeModel model = combobox_icon.get_model ();
            model.get (iter, 0, out tool.icon, -1);

            model = treeview_jobs.get_model ();
            bool valid = jobs_store.get_iter_first (out iter);
            while (valid)
            {
                BuildJob job = BuildJob ();

                string command;
                string post_processor_name;
                model.get (iter,
                    JobColumn.COMMAND, out command,
                    JobColumn.MUST_SUCCEED, out job.must_succeed,
                    JobColumn.POST_PROCESSOR, out post_processor_name,
                    -1);

                job.command = command.strip ();
                job.post_processor = BuildTools.get_post_processor_type_from_name (
                    post_processor_name);
                tool.jobs.add (job);

                valid = jobs_store.iter_next (ref iter);
            }

            /* update build tools settings */
            if (num == -1)
            {
                tool.show = true;
                BuildTools.get_default ().add (tool);
            }
            else
                BuildTools.get_default ().update (num, tool, true);

            hide ();
            return true;
        }

        hide ();
        return false;
    }
}
