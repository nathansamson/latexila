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

public enum PartitionState
{
    RUNNING,
    SUCCEEDED,
    FAILED,
    ABORTED
}

public enum BuildMsgType
{
    ERROR,
    WARNING,
    BADBOX,
    OTHER
}

public struct BuildMsg
{
    public string text;
    public BuildMsgType type;
    public string? filename;

    public bool lines_set;
    public int start_line;

    // if -1, takes the same value as start_line
    public int end_line;

    // if the message have children, show them?
    public bool expand;
}

public class BuildView : Grid
{
    private enum BuildInfo
    {
        ICON,
        MESSAGE,
        MESSAGE_TYPE,
        WEIGHT,
        BASENAME,
        PATH,
        FILE,
        START_LINE,
        END_LINE,
        LINE,
        N_COLUMNS
    }

    public bool show_errors { get; set; }
    public bool show_warnings { get; set; }
    public bool show_badboxes { get; set; }

    private unowned MainWindow _main_window;
    private TreeStore _store;
    private TreeModelFilter _filtered_model;
    private TreeView _view;
    private unowned ToggleAction _action_view_bottom_panel;

    public BuildView (MainWindow main_window, Toolbar toolbar,
        ToggleAction view_bottom_panel)
    {
        orientation = Orientation.HORIZONTAL;
        _main_window = main_window;
        _action_view_bottom_panel = view_bottom_panel;

        _store = new TreeStore (BuildInfo.N_COLUMNS,
            typeof (string),    // icon (stock-id)
            typeof (string),    // message
            typeof (BuildMsgType),
            typeof (int),       // weight (normal or bold)
            typeof (string),    // basename
            typeof (string),    // path
            typeof (File),      // file
            typeof (int),       // start line
            typeof (int),       // end line
            typeof (string)     // line (same as start line but for display)
        );

        /* filter errors/warnings/badboxes */
        _filtered_model = new TreeModelFilter (_store, null);
        _filtered_model.set_visible_func ((model, iter) =>
        {
            BuildMsgType msg_type;
            model.get (iter, BuildInfo.MESSAGE_TYPE, out msg_type, -1);

            switch (msg_type)
            {
                case BuildMsgType.ERROR:
                    return show_errors;
                case BuildMsgType.WARNING:
                    return show_warnings;
                case BuildMsgType.BADBOX:
                    return show_badboxes;
                default:
                    return true;
            }
        });

        this.notify["show-errors"].connect (() => _filtered_model.refilter ());
        this.notify["show-warnings"].connect (() => _filtered_model.refilter ());
        this.notify["show-badboxes"].connect (() => _filtered_model.refilter ());

        /* create tree view */
        _view = new TreeView.with_model (_filtered_model);

        TreeViewColumn column_job = new TreeViewColumn ();
        column_job.title = _("Job");

        CellRendererPixbuf renderer_pixbuf = new CellRendererPixbuf ();
        column_job.pack_start (renderer_pixbuf, false);
        column_job.add_attribute (renderer_pixbuf, "stock-id", BuildInfo.ICON);

        CellRendererText renderer_text = new CellRendererText ();
        renderer_text.weight_set = true;
        renderer_text.editable = true;
        renderer_text.editable_set = true;
        column_job.pack_start (renderer_text, true);
        column_job.add_attribute (renderer_text, "text", BuildInfo.MESSAGE);
        column_job.add_attribute (renderer_text, "weight", BuildInfo.WEIGHT);

        _view.append_column (column_job);

        _view.insert_column_with_attributes (-1, _("File"), new CellRendererText (),
            "text", BuildInfo.BASENAME);
        _view.insert_column_with_attributes (-1, _("Line"), new CellRendererText (),
            "text", BuildInfo.LINE);

        _view.set_tooltip_column (BuildInfo.PATH);

        // selection
        TreeSelection select = _view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function ((select, model, path, path_currently_selected) =>
        {
            // always allow deselect
            if (path_currently_selected)
                return true;

            return select_row (model, path);
        });

        // double-click
        _view.row_activated.connect ((path) => select_row (_filtered_model, path));

        // with a scrollbar
        Widget sw = Utils.add_scrollbar (_view);
        sw.expand = true;
        add (sw);

        // close button
        Button close_button = new Button ();
        close_button.relief = ReliefStyle.NONE;
        close_button.focus_on_click = false;
        close_button.tooltip_text = _("Hide panel");
        close_button.add (new Image.from_stock (Stock.CLOSE, IconSize.MENU));
        close_button.clicked.connect (() =>
        {
            this.hide ();
            _action_view_bottom_panel.active = false;
        });

        Grid grid = new Grid ();
        grid.orientation = Orientation.VERTICAL;
        grid.add (close_button);
        toolbar.set_vexpand (true);
        grid.add (toolbar);
        add (grid);
    }

    private bool select_row (TreeModel model, TreePath path)
    {
        TreeIter iter;
        if (! model.get_iter (out iter, path))
            // the row is not selected
            return false;

        BuildMsgType msg_type;
        File file;
        int start_line, end_line;

        model.get (iter,
            BuildInfo.MESSAGE_TYPE, out msg_type,
            BuildInfo.FILE, out file,
            BuildInfo.START_LINE, out start_line,
            BuildInfo.END_LINE, out end_line,
            -1);

        if (msg_type != BuildMsgType.OTHER && file != null)
        {
            jump_to_file (file, start_line, end_line);

            // the row is selected
            return true;
        }

        // maybe it's a parent, so we can show or hide its children
        else if (msg_type == BuildMsgType.OTHER)
        {
            if (model.iter_has_child (iter))
            {
                if (_view.is_row_expanded (path))
                    _view.collapse_row (path);
                else
                    _view.expand_to_path (path);

                // the row is not selected
                return false;
            }
        }

        // the row is selected, so we can copy/paste its content
        return true;
    }

    private void jump_to_file (File file, int start_line, int end_line)
    {
        DocumentTab tab = _main_window.open_document (file);

        // If the file was not yet opened, it takes some time. If we try to select the
        // lines when the file is not fully charged, the lines are simply not selected.
        Utils.flush_queue ();

        if (start_line != -1)
        {
            // start_line and end_line begins at 1, but select_lines() begins at 0
            int end = end_line != -1 ? end_line - 1 : start_line;
            tab.document.select_lines (start_line - 1, end);
        }
    }

    public void clear ()
    {
        _store.clear ();
        _view.columns_autosize ();
    }

    public TreeIter add_partition (string msg, PartitionState state, TreeIter? parent,
        bool bold = false)
    {
        TreeIter iter;
        _store.append (out iter, parent);
        _store.set (iter,
            BuildInfo.ICON,         get_icon_from_state (state),
            BuildInfo.MESSAGE,      msg,
            BuildInfo.MESSAGE_TYPE, BuildMsgType.OTHER,
            BuildInfo.WEIGHT,       bold ? 800 : 400,
            -1);

        _view.expand_to_path (_store.get_path (iter));

        return iter;
    }

    public void set_partition_state (TreeIter partition_id, PartitionState state)
    {
        _store.set (partition_id, BuildInfo.ICON, get_icon_from_state (state), -1);
    }

    public void append_messages (TreeIter parent, Node<BuildMsg?> messages,
        bool parent_is_partition = true)
    {
        unowned Node<BuildMsg?> cur_node = messages.first_child ();
        while (cur_node != null)
        {
            TreeIter child = append_single_message (parent, cur_node.data);

            // the node contains children
            if (cur_node.children != null)
            {
                _store.set (child, BuildInfo.ICON, "completion_choice", -1);
                append_messages (child, cur_node, false);

                if (cur_node.data.expand)
                    _view.expand_to_path (_store.get_path (child));
            }

            cur_node = cur_node.next_sibling ();
        }

        // All partitions are expanded, but we must do that when the partition have
        // children.
        if (parent_is_partition)
            _view.expand_row (_store.get_path (parent), false);
    }

    public TreeIter append_single_message (TreeIter partition_id, BuildMsg message)
    {
        File file = null;
        string path = null;

        if (message.filename != null)
        {
            file = File.new_for_path (message.filename);
            path = Utils.replace_home_dir_with_tilde (message.filename);

            // the path is displayed in a tooltip
            path = Markup.escape_text (path);
        }

        int start_line = -1;
        int end_line = -1;
        string line_str = null;
        if (message.lines_set)
        {
            start_line = message.start_line;
            end_line = message.end_line;
            line_str = start_line.to_string ();
        }

        TreeIter iter;
        _store.append (out iter, partition_id);
        _store.set (iter,
            BuildInfo.ICON,         get_icon_from_msg_type (message.type),
            BuildInfo.MESSAGE,      message.text,
            BuildInfo.MESSAGE_TYPE, message.type,
            BuildInfo.WEIGHT,       400,
            BuildInfo.BASENAME,     file != null ? file.get_basename () : null,
            BuildInfo.FILE,         file,
            BuildInfo.PATH,         path,
            BuildInfo.START_LINE,   start_line,
            BuildInfo.END_LINE,     end_line,
            BuildInfo.LINE,         line_str,
            -1);

        return iter;
    }

    private string? get_icon_from_state (PartitionState state)
    {
        switch (state)
        {
            case PartitionState.RUNNING:
                return Stock.EXECUTE;
            case PartitionState.SUCCEEDED:
                return Stock.APPLY;
            case PartitionState.FAILED:
                return Stock.DIALOG_ERROR;
            case PartitionState.ABORTED:
                return Stock.STOP;
            default:
                return_val_if_reached (null);
        }
    }

    private string? get_icon_from_msg_type (BuildMsgType type)
    {
        switch (type)
        {
            case BuildMsgType.ERROR:
                return Stock.DIALOG_ERROR;
            case BuildMsgType.WARNING:
                return Stock.DIALOG_WARNING;
            case BuildMsgType.BADBOX:
                return "badbox";
            case BuildMsgType.OTHER:
                return null;
            default:
                return_val_if_reached (null);
        }
    }

    public new void show ()
    {
        base.show ();
        _action_view_bottom_panel.active = true;
    }
}
