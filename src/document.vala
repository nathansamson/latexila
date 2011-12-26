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

public enum SelectionType
{
    NO_SELECTION,
    ONE_LINE,
    MULTIPLE_LINES
}

public class Document : Gtk.SourceBuffer
{
    public File location { get; set; }
    public bool readonly { get; set; default = false; }
    public DocumentTab tab;
    public uint _unsaved_doc_num = 0;
    public int project_id { get; set; default = -1; }
    private bool backup_made = false;
    private string _etag;
    private string? encoding = null;
    private bool new_file = true;

    private DocumentStructure _structure = null;

    private TextTag found_tag;
    private TextTag found_tag_selected;
    public signal void search_info_updated (bool selected, uint nb_matches,
        uint num_match);
    private string search_text;
    private uint search_nb_matches;
    private uint search_num_match;
    private bool search_case_sensitive;
    private bool search_entire_word;

    private bool stop_cursor_moved_emission = false;
    public signal void cursor_moved ();

    public Document ()
    {
        // syntax highlighting: LaTeX by default
        var lm = Gtk.SourceLanguageManager.get_default ();
        set_language (lm.get_language ("latex"));

        notify["location"].connect (() =>
        {
            update_syntax_highlighting ();
            update_project_id ();
        });
        mark_set.connect ((location, mark) =>
        {
            if (mark == get_insert ())
                emit_cursor_moved ();
        });
        changed.connect (() =>
        {
            new_file = false;
            emit_cursor_moved ();
        });

        found_tag = new TextTag ("found");
        found_tag_selected = new TextTag ("found_selected");
        sync_found_tags ();
        TextTagTable tag_table = get_tag_table ();
        tag_table.add (found_tag);
        tag_table.add (found_tag_selected);
        notify["style-scheme"].connect (sync_found_tags);

        TextIter iter;
        get_iter_at_line (out iter, 0);
        create_mark ("search_selected_start", iter, true);
        create_mark ("search_selected_end", iter, true);
    }

    public new bool get_modified ()
    {
        if (new_file)
            return false;

        return base.get_modified ();
    }

    public new void insert (ref TextIter iter, string text, int len)
    {
        Gtk.SourceCompletion completion = tab.view.completion;
        completion.block_interactive ();

        base.insert (ref iter, text, len);

        // HACK: wait one second before delocking completion, it's better than doing a
        // Utils.flush_queue ().
        Timeout.add_seconds (1, () =>
        {
            completion.unblock_interactive ();
            return false;
        });
    }

    public void load (File location)
    {
        this.location = location;

        try
        {
            uint8[] chars;
            location.load_contents (null, out chars, out _etag);
            string text = (string) (owned) chars;

            if (text.validate ())
                set_contents (text);

            // convert to UTF-8
            else
            {
                string utf8_text = to_utf8 (text);
                set_contents (utf8_text);
            }

            update_syntax_highlighting ();

            RecentManager.get_default ().add_item (location.get_uri ());
        }
        catch (Error e)
        {
            warning ("%s", e.message);

            string primary_msg = _("Impossible to load the file '%s'.")
                .printf (location.get_parse_name ());
            tab.add_message (primary_msg, e.message, MessageType.ERROR);
        }
    }

    public void set_contents (string contents)
    {
        // if last character is a new line, don't display it
        string? contents2 = null;
        if (contents[contents.length - 1] == '\n')
            contents2 = contents[0:-1];

        begin_not_undoable_action ();
        set_text (contents2 ?? contents, -1);
        new_file = true;
        set_modified (false);
        end_not_undoable_action ();

        // move the cursor at the first line
        TextIter iter;
        get_start_iter (out iter);
        place_cursor (iter);
    }

    public void save (bool check_file_changed_on_disk = true, bool force = false)
    {
        return_if_fail (location != null);

        // if not modified, don't save
        if (! force && ! new_file && ! get_modified ())
            return;

        // we use get_text () to exclude undisplayed text
        TextIter start, end;
        get_bounds (out start, out end);
        string text = get_text (start, end, false);

        // the last character must be \n
        if (text[text.length - 1] != '\n')
            text = @"$text\n";

        try
        {
            GLib.Settings settings =
                new GLib.Settings ("org.gnome.latexila.preferences.editor");
            bool make_backup = ! backup_made
                && settings.get_boolean ("create-backup-copy");

            string? etag = check_file_changed_on_disk ? _etag : null;

            // if encoding specified, convert to this encoding
            if (encoding != null)
                text = convert (text, (ssize_t) text.length, encoding, "UTF-8");

            // else, convert to the system default encoding
            else
                text = Filename.from_utf8 (text, (ssize_t) text.length, null, null);

            // check if parent directories exist, if not, create it
            File parent = location.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            location.replace_contents (text, text.length, etag, make_backup,
                FileCreateFlags.NONE, out _etag, null);

            set_modified (false);

            RecentManager.get_default ().add_item (location.get_uri ());
            backup_made = true;
        }
        catch (Error e)
        {
            if (e is IOError.WRONG_ETAG)
            {
                string primary_msg = _("The file %s has been modified since reading it.")
                    .printf (location.get_parse_name ());
                string secondary_msg =
                    _("If you save it, all the external changes could be lost. Save it anyway?");
                TabInfoBar infobar = tab.add_message (primary_msg, secondary_msg,
                    MessageType.WARNING);
                infobar.add_stock_button_with_text (_("Save Anyway"), Stock.SAVE,
                    ResponseType.YES);
                infobar.add_button (_("Don't Save"), ResponseType.CANCEL);
                infobar.response.connect ((response_id) =>
                {
                    if (response_id == ResponseType.YES)
                        save (false);
                    infobar.destroy ();
                });
            }
            else
            {
                warning ("%s", e.message);

                string primary_msg = _("Impossible to save the file.");
                TabInfoBar infobar = tab.add_message (primary_msg, e.message,
                    MessageType.ERROR);
                infobar.add_ok_button ();
            }
        }
    }

    private string to_utf8 (string text) throws ConvertError
    {
        foreach (string charset in Encodings.CHARSETS)
        {
            try
            {
                string utf8_text = convert (text, (ssize_t) text.length, "UTF-8",
                    charset);
                encoding = charset;
                return utf8_text;
            }
            catch (ConvertError e)
            {
                continue;
            }
        }
        throw new GLib.ConvertError.FAILED (
            _("Error trying to convert the document to UTF-8"));
    }

    private void update_syntax_highlighting ()
    {
        Gtk.SourceLanguageManager lm = Gtk.SourceLanguageManager.get_default ();
        string content_type = null;
        try
        {
            FileInfo info = location.query_info (FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
                FileQueryInfoFlags.NONE, null);
            content_type = info.get_content_type ();
        }
        catch (Error e) {}

        var lang = lm.guess_language (location.get_parse_name (), content_type);
        set_language (lang);
    }

    private void update_project_id ()
    {
        int i = 0;
        foreach (Project project in Projects.get_default ())
        {
            if (location.has_prefix (project.directory))
            {
                project_id = i;
                return;
            }
            i++;
        }

        project_id = -1;
    }

    public string get_uri_for_display ()
    {
        if (location == null)
            return get_unsaved_document_name ();

        return Utils.replace_home_dir_with_tilde (location.get_parse_name ());
    }

    public string get_short_name_for_display ()
    {
        if (location == null)
            return get_unsaved_document_name ();

        return location.get_basename ();
    }

    private string get_unsaved_document_name ()
    {
        uint num = get_unsaved_document_num ();
        return _("Unsaved Document") + @" $num";
    }

    private uint get_unsaved_document_num ()
    {
        return_val_if_fail (location == null, 0);

        if (_unsaved_doc_num > 0)
            return _unsaved_doc_num;

        // get all unsaved document numbers
        uint[] all_nums = {};
        foreach (Document doc in Application.get_default ().get_documents ())
        {
            // avoid infinite loop
            if (doc == this)
                continue;

            if (doc.location == null)
                all_nums += doc.get_unsaved_document_num ();
        }

        // take the first free num
        uint num;
        for (num = 1 ; num in all_nums ; num++);

        _unsaved_doc_num = num;
        return num;
    }

    public bool is_local ()
    {
        if (location == null)
            return false;
        return location.has_uri_scheme ("file");
    }

    public bool is_externally_modified ()
    {
        if (location == null)
            return false;

        string current_etag = null;
        try
        {
            FileInfo file_info = location.query_info (FILE_ATTRIBUTE_ETAG_VALUE,
                FileQueryInfoFlags.NONE, null);
            current_etag = file_info.get_etag ();
        }
        catch (GLib.Error e)
        {
            return false;
        }

        return current_etag != null && current_etag != _etag;
    }

    public void set_style_scheme_from_string (string scheme_id)
    {
        SourceStyleSchemeManager manager = SourceStyleSchemeManager.get_default ();
        style_scheme = manager.get_scheme (scheme_id);
    }

    private void emit_cursor_moved ()
    {
        if (! stop_cursor_moved_emission)
            cursor_moved ();
    }

    public void comment_selected_lines ()
    {
        TextIter start;
        TextIter end;
        get_selection_bounds (out start, out end);

        comment_between (start, end);
    }

    // comment the lines between start_iter and end_iter included
    public void comment_between (TextIter start_iter, TextIter? end_iter)
    {
        int start_line = start_iter.get_line ();
        int end_line = start_line;

        if (end_iter != null)
            end_line = end_iter.get_line ();

        TextIter cur_iter;
        get_iter_at_line (out cur_iter, start_line);

        begin_user_action ();
        for (int i = start_line ; i <= end_line ; i++, cur_iter.forward_line ())
        {
            // do not comment empty lines
            if (cur_iter.ends_line ())
                continue;

            TextIter end_line_iter = cur_iter;
            end_line_iter.forward_to_line_end ();

            string line_contents = get_text (cur_iter, end_line_iter, false);

            // do not comment lines containing only spaces
            if (line_contents.strip () != "")
                insert (ref cur_iter, "% ", -1);
        }
        end_user_action ();
    }

    public void uncomment_selected_lines ()
    {
        TextIter start, end;
        get_selection_bounds (out start, out end);

        int start_line = start.get_line ();
        int end_line = end.get_line ();
        int line_count = get_line_count ();

        begin_user_action ();

        for (int i = start_line ; i <= end_line ; i++)
        {
            get_iter_at_line (out start, i);

            // if last line
            if (i == line_count - 1)
                get_end_iter (out end);
            else
                get_iter_at_line (out end, i + 1);

            string line = get_text (start, end, false);

            /* find the first '%' character */
            int j = 0;
            int start_delete = -1;
            int stop_delete = -1;
            while (line[j] != '\0')
            {
                if (line[j] == '%')
                {
                    start_delete = j;
                    stop_delete = j + 1;
                    if (line[j + 1] == ' ')
                        stop_delete++;
                    break;
                }

                else if (line[j] != ' ' && line[j] != '\t')
                    break;

                j++;
            }

            if (start_delete == -1)
                continue;

            get_iter_at_line_offset (out start, i, start_delete);
            get_iter_at_line_offset (out end, i, stop_delete);
            this.delete (ref start, ref end);
        }

        end_user_action ();
    }

    public void select_lines (int start, int end)
    {
        TextIter start_iter, end_iter;
        get_iter_at_line (out start_iter, start);
        get_iter_at_line (out end_iter, end);
        select_range (start_iter, end_iter);
        tab.view.scroll_to_cursor ();
    }

    public SelectionType get_selection_type ()
    {
        if (! has_selection)
            return SelectionType.NO_SELECTION;

        TextIter start, end;
        get_selection_bounds (out start, out end);
        if (start.get_line () == end.get_line ())
            return SelectionType.ONE_LINE;

        return SelectionType.MULTIPLE_LINES;
    }

    // If line is bigger than the number of lines of the document, the cursor is moved
    // to the last line and false is returned.
    public bool goto_line (int line)
    {
        return_val_if_fail (line >= -1, false);

        bool ret = true;
        TextIter iter;

        if (line >= get_line_count ())
        {
            ret = false;
            get_end_iter (out iter);
        }
        else
            get_iter_at_line (out iter, line);

        place_cursor (iter);
        return ret;
    }

    public Project? get_project ()
    {
        if (project_id == -1)
            return null;

        return Projects.get_default ().get (project_id);
    }

    public File? get_main_file ()
    {
        if (location == null)
            return null;

        Project? project = get_project ();
        if (project == null)
            return location;

        return project.main_file;
    }

    public bool is_main_file_a_tex_file ()
    {
        File? main_file = get_main_file ();
        if (main_file == null)
            return false;

        string path = main_file.get_parse_name ();
        return path.has_suffix (".tex");
    }

    public string get_current_indentation (int line)
    {
        TextIter start_iter, end_iter;
        get_iter_at_line (out start_iter, line);
        get_iter_at_line (out end_iter, line + 1);

        string text = get_text (start_iter, end_iter, false);

        string current_indent = "";
        for (long i = 0 ; i < text.length ; i++)
        {
            if (text[i] == ' ' || text[i] == '\t')
                current_indent += text[i].to_string ();
            else
                break;
        }

        return current_indent;
    }

    public DocumentStructure get_structure ()
    {
        if (_structure == null)
        {
            _structure = new DocumentStructure (this);
            _structure.parse ();
        }
        return _structure;
    }


    /***************
     *    SEARCH
     ***************/

    public void set_search_text (string text, bool case_sensitive, bool entire_word,
        out uint nb_matches, out uint num_match, bool select = true)
    {
        num_match = 0;

        // connect signals
        if (search_text == null)
        {
            cursor_moved.connect (search_cursor_moved_handler);
            delete_range.connect (search_delete_range_before_handler);
            delete_range.connect_after (search_delete_range_after_handler);
            insert_text.connect (search_insert_text_before_handler);
            insert_text.connect_after (search_insert_text_after_handler);
        }

        // if nothing has changed
        if (search_text == text
            && search_case_sensitive == case_sensitive
            && search_entire_word == entire_word)
        {
            nb_matches = search_nb_matches;
            num_match = search_num_match;
            return;
        }

        invalidate_search_selected_marks ();
        clear_search (false);
        search_text = text;
        search_case_sensitive = case_sensitive;
        search_entire_word = entire_word;

        TextIter start = {};
        TextIter match_start = {};
        TextIter match_end = {};
        TextIter insert = {};
        TextIter try_match_start = {};
        TextIter try_match_end = {};

        get_start_iter (out start);
        get_iter_at_mark (out insert, get_insert ());
        bool next_match_after_cursor_found = ! select;
        uint i = 0;

        while (iter_forward_search (start, null, out try_match_start, out try_match_end))
        {
            match_start = try_match_start;
            match_end = try_match_end;

            if (! next_match_after_cursor_found && insert.compare (match_end) <= 0)
            {
                next_match_after_cursor_found = true;
                search_num_match = num_match = i;
                move_search_marks (match_start, match_end, true);
            }
            else
                apply_tag (found_tag, match_start, match_end);

            start = match_end;
            i++;
        }

        // if the cursor was after the last match, take the last match
        // (if we want to select one)
        if (! next_match_after_cursor_found && i > 0)
        {
            search_num_match = num_match = i;
            move_search_marks (match_start, match_end, true);
        }

        search_nb_matches = nb_matches = i;

        if (search_nb_matches == 0)
            clear_search_tags ();
    }

    public void select_selected_search_text ()
    {
        TextIter start, end;
        get_iter_at_mark (out start, get_mark ("search_selected_start"));
        get_iter_at_mark (out end, get_mark ("search_selected_end"));
        place_cursor (start);
        move_mark (get_mark ("selection_bound"), end);
    }

    public void search_forward ()
    {
        return_if_fail (search_text != null);

        if (search_nb_matches == 0)
            return;

        TextIter start_search, start, match_start, match_end;
        get_iter_at_mark (out start_search, get_insert ());
        get_start_iter (out start);

        bool increment = false;
        if (start_search.has_tag (found_tag_selected))
        {
            get_iter_at_mark (out start_search, get_mark ("search_selected_end"));
            increment = true;
        }

        replace_found_tag_selected ();

        // search forward
        if (iter_forward_search (start_search, null, out match_start, out match_end))
        {
            move_search_marks (match_start, match_end, true);

            if (increment)
            {
                search_num_match++;
                search_info_updated (true, search_nb_matches, search_num_match);
                return;
            }
        }

        else if (iter_forward_search (start, null, out match_start, out match_end))
        {
            move_search_marks (match_start, match_end, true);

            search_num_match = 1;
            search_info_updated (true, search_nb_matches, search_num_match);
            return;
        }

        find_num_match ();
    }

    public void search_backward ()
    {
        return_if_fail (search_text != null);

        if (search_nb_matches == 0)
            return;

        TextIter start_search, end, match_start, match_end;
        get_iter_at_mark (out start_search, get_insert ());
        get_end_iter (out end);

        bool decrement = false;
        bool move_cursor = true;

        TextIter start_prev = start_search;
        start_prev.backward_char ();

        // the cursor is on a match
        if (start_search.has_tag (found_tag_selected) ||
            start_prev.has_tag (found_tag_selected))
        {
            get_iter_at_mark (out start_search, get_mark ("search_selected_start"));
            decrement = true;
        }

        // the user has clicked in the middle or at the beginning of a match
        else if (start_search.has_tag (found_tag))
        {
            move_cursor = false;
            start_search.forward_chars ((int) search_text.length);
        }

        // the user has clicked at the end of a match
        else if (start_prev.has_tag (found_tag))
            move_cursor = false;

        replace_found_tag_selected ();

        // search backward
        if (iter_backward_search (start_search, null, out match_start, out match_end))
        {
            move_search_marks (match_start, match_end, move_cursor);

            if (decrement)
            {
                search_num_match--;
                search_info_updated (true, search_nb_matches, search_num_match);
                return;
            }
        }

        // take the last match
        else if (iter_backward_search (end, null, out match_start, out match_end))
        {
            move_search_marks (match_start, match_end, true);

            search_num_match = search_nb_matches;
            search_info_updated (true, search_nb_matches, search_num_match);
            return;
        }

        find_num_match ();
    }

    private bool iter_forward_search (TextIter start, TextIter? end,
        out TextIter match_start, out TextIter match_end)
    {
        match_start = TextIter ();
        match_end = TextIter ();

        bool found = false;
        while (! found)
        {
            found = start.forward_search (search_text, get_search_flags (),
                out match_start, out match_end, end);

            if (found && search_entire_word)
            {
                found = match_start.starts_word () && match_end.ends_word ();
                if (! found)
                    start = match_end;
            }
            else
                break;
        }

        return found;
    }

    private bool iter_backward_search (TextIter start, TextIter? end,
        out TextIter match_start, out TextIter match_end)
    {
        match_start = TextIter ();
        match_end = TextIter ();

        bool found = false;
        while (! found)
        {
            found = start.backward_search (search_text, get_search_flags (),
                out match_start, out match_end, end);

            if (found && search_entire_word)
            {
                found = match_start.starts_word () && match_end.ends_word ();
                if (! found)
                    start = match_start;
            }
            else
                break;
        }

        return found;
    }

    public void clear_search (bool disconnect_signals = true)
    {
        clear_search_tags ();
        search_text = null;

        if (disconnect_signals)
        {
            cursor_moved.disconnect (search_cursor_moved_handler);
            delete_range.disconnect (search_delete_range_before_handler);
            delete_range.disconnect (search_delete_range_after_handler);
            insert_text.disconnect (search_insert_text_before_handler);
            insert_text.disconnect (search_insert_text_after_handler);
        }
    }

    private void clear_search_tags ()
    {
        invalidate_search_selected_marks ();

        TextIter start, end;
        get_bounds (out start, out end);
        remove_tag (found_tag, start, end);
        remove_tag (found_tag_selected, start, end);
    }

    private void search_cursor_moved_handler ()
    {
        TextIter insert, insert_previous;
        get_iter_at_mark (out insert, get_insert ());
        insert_previous = insert;
        insert_previous.backward_char ();
        if (insert.has_tag (found_tag_selected) ||
            insert_previous.has_tag (found_tag_selected))
        {
            return;
        }

        replace_found_tag_selected ();
        invalidate_search_selected_marks ();

        if (insert.has_tag (found_tag) || insert_previous.has_tag (found_tag))
            search_backward ();
        else
            search_info_updated (false, search_nb_matches, 0);
    }

    private void search_delete_range_before_handler (TextIter start, TextIter end)
    {
        TextIter start_search, stop_search, match_start, match_end;
        start_search = start;
        start_search.backward_chars ((int) search_text.length - 1);
        stop_search = end;
        stop_search.forward_chars ((int) search_text.length - 1);

        replace_found_tag_selected ();
        invalidate_search_selected_marks ();

        while (iter_forward_search (start_search, stop_search, out match_start,
            out match_end))
        {
            if (match_start.compare (start) < 0 || match_end.compare (end) > 0)
            {
                remove_tag (found_tag, match_start, match_end);
                remove_tag (found_tag_selected, match_start, match_end);
            }

            search_nb_matches--;
            start_search = match_end;
        }
    }

    private void search_delete_range_after_handler (TextIter location)
    {
        TextIter start_search, stop_search;
        start_search = stop_search = location;
        start_search.backward_chars ((int) search_text.length - 1);
        stop_search.forward_chars ((int) search_text.length - 1);

        search_matches_between (start_search, stop_search);
    }

    private void search_insert_text_before_handler (TextIter location)
    {
        // if text inserted in the middle of a current match, remove the tags
        if (location.has_tag (found_tag) || location.has_tag (found_tag_selected))
        {
            replace_found_tag_selected ();
            invalidate_search_selected_marks ();

            TextIter start_search, match_start, match_end;
            start_search = location;
            start_search.forward_chars ((int) search_text.length - 1);

            if (iter_backward_search (start_search, null, out match_start, out match_end))
            {
                // in the middle
                if (location.compare (match_end) < 0)
                {
                    remove_tag (found_tag, match_start, match_end);
                    remove_tag (found_tag_selected, match_start, match_end);
                    search_nb_matches--;
                }
            }
        }
    }

    private void search_insert_text_after_handler (TextIter location, string text,
        int len)
    {
        // remove tags in text inserted
        TextIter left_text = location;
        left_text.backward_chars (len);
        remove_tag (found_tag, left_text, location);
        remove_tag (found_tag_selected, left_text, location);

        TextIter start_search, stop_search;
        start_search = stop_search = location;
        start_search.backward_chars (len + (int) search_text.length - 1);
        stop_search.forward_chars ((int) search_text.length - 1);

        search_matches_between (start_search, stop_search);
    }

    private void search_matches_between (TextIter start_search, TextIter stop_search)
    {
        TextIter match_start, match_end;

        while (iter_forward_search (start_search, stop_search, out match_start,
            out match_end))
        {
            apply_tag (found_tag, match_start, match_end);
            search_nb_matches++;
            start_search = match_end;
        }

        replace_found_tag_selected ();
        invalidate_search_selected_marks ();

        // simulate a cursor move
        search_cursor_moved_handler ();
    }

    private TextSearchFlags get_search_flags ()
    {
        var flags = TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY;
        if (! search_case_sensitive)
            flags |= TextSearchFlags.CASE_INSENSITIVE;
        return flags;
    }

    private void move_search_marks (TextIter start, TextIter end, bool move_cursor)
    {
        remove_tag (found_tag, start, end);
        apply_tag (found_tag_selected, start, end);

        move_mark_by_name ("search_selected_start", start);
        move_mark_by_name ("search_selected_end", end);

        if (move_cursor)
        {
            place_cursor (start);
            tab.view.scroll_to_cursor ();
        }
    }

    private void replace_found_tag_selected ()
    {
        TextIter start, end;
        get_iter_at_mark (out start, get_mark ("search_selected_start"));
        get_iter_at_mark (out end, get_mark ("search_selected_end"));
        remove_tag (found_tag_selected, start, end);
        apply_tag (found_tag, start, end);
    }

    private void find_num_match ()
    {
        TextIter start, stop, match_end;
        get_start_iter (out start);
        get_iter_at_mark (out stop, get_mark ("search_selected_start"));

        uint i = 0;
        while (iter_forward_search (start, stop, null, out match_end))
        {
            i++;
            start = match_end;
        }

        search_num_match = i + 1;
        search_info_updated (true, search_nb_matches, search_num_match);
    }

    private void invalidate_search_selected_marks ()
    {
        TextIter iter;
        get_start_iter (out iter);
        move_mark_by_name ("search_selected_start", iter);
        move_mark_by_name ("search_selected_end", iter);
    }

    private void set_search_match_colors (TextTag text_tag)
    {
        SourceStyleScheme style_scheme = get_style_scheme ();
        SourceStyle style = null;

        if (style_scheme != null)
            style = style_scheme.get_style ("search-match");

        if (style_scheme == null || style == null)
        {
            text_tag.background = "#FFFF78";
            return;
        }

        if (style.foreground_set && style.foreground != null)
            text_tag.foreground = style.foreground;
        else
            text_tag.foreground = null;

        if (style.background_set && style.background != null)
            text_tag.background = style.background;
        else
            text_tag.background = null;

        if (style.line_background_set && style.line_background != null)
            text_tag.paragraph_background = style.line_background;
        else
            text_tag.paragraph_background = null;

        text_tag.weight = style.bold_set && style.bold ?
            Pango.Weight.BOLD : Pango.Weight.NORMAL;

        text_tag.style = style.italic_set && style.italic ?
            Pango.Style.ITALIC : Pango.Style.NORMAL;

        text_tag.underline = style.underline_set && style.underline ?
            Pango.Underline.SINGLE : Pango.Underline.NONE;

        text_tag.strikethrough = style.strikethrough_set && style.strikethrough;
    }

    private void sync_found_tags ()
    {
        set_search_match_colors (found_tag);

        // found tag selected: same as found tag but with orange background
        set_search_match_colors (found_tag_selected);
        found_tag_selected.background = "#FF8C00";
    }


    /****************
     *    REPLACE
     ****************/

    public void replace (string text)
    {
        return_if_fail (search_text != null);
        return_if_fail (! readonly);

        /* the cursor is on a match? */
        TextIter insert, insert_prev;
        get_iter_at_mark (out insert, get_insert ());
        insert_prev = insert;
        insert_prev.backward_char ();

        // no match selected, we search forward
        if (! insert.has_tag (found_tag_selected) &&
            ! insert_prev.has_tag (found_tag_selected))
        {
            search_forward ();
            return;
        }

        /* replace text */
        TextIter start, end;
        get_iter_at_mark (out start, get_mark ("search_selected_start"));
        get_iter_at_mark (out end, get_mark ("search_selected_end"));

        begin_user_action ();
        this.delete (ref start, ref end);
        this.insert (ref start, text, -1);
        end_user_action ();

        // if the next match was directly after the previous, don't search forward
        if (! start.has_tag (found_tag_selected))
            search_forward ();
    }

    public void replace_all (string text)
    {
        return_if_fail (search_text != null);
        return_if_fail (! readonly);

        TextIter start, match_start, match_end;
        get_start_iter (out start);

        stop_cursor_moved_emission = true;
        begin_user_action ();

        while (iter_forward_search (start, null, out match_start, out match_end))
        {
            this.delete (ref match_start, ref match_end);
            this.insert (ref match_start, text, -1);
            start = match_start;
        }

        end_user_action ();
        stop_cursor_moved_emission = false;
        emit_cursor_moved ();
    }
}
