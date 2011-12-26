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

public class GotoLine : Grid
{
    private unowned MainWindow main_window;
    private Entry entry;

    public GotoLine (MainWindow main_window)
    {
        orientation = Orientation.HORIZONTAL;
        set_column_spacing (3);
        this.main_window = main_window;

        Button close_button = new Button ();
        add (close_button);
        close_button.set_relief (ReliefStyle.NONE);
        Image img = new Image.from_stock (Stock.CLOSE, IconSize.MENU);
        close_button.add (img);
        close_button.clicked.connect (() => hide ());

        Label label = new Label (_("Go to Line:"));
        label.margin_left = 2;
        label.margin_right = 2;
        add (label);

        entry = new Entry ();
        add (entry);
        entry.set_icon_from_stock (EntryIconPosition.SECONDARY, Stock.JUMP_TO);
        entry.set_icon_activatable (EntryIconPosition.SECONDARY, true);
        entry.set_tooltip_text (_("Line you want to move the cursor to"));
        entry.set_size_request (100, -1);
        entry.activate.connect (() => hide ());
        entry.icon_press.connect (() => hide ());
        entry.changed.connect (on_changed);
    }

    public new void show ()
    {
        entry.text = "";
        show_all ();
        entry.grab_focus ();
    }

    private void on_changed ()
    {
        if (entry.text_length == 0)
        {
            Utils.set_entry_error (entry, false);
            return;
        }

        string text = entry.get_text ();

        // check if all characters are digits
        for (int i = 0 ; i < text.length ; i++)
        {
            unichar c = text[i];
            if (! c.isdigit ())
            {
                Utils.set_entry_error (entry, true);
                return;
            }
        }

        int line = int.parse (text);
        bool error = ! main_window.active_document.goto_line (--line);
        Utils.set_entry_error (entry, error);
        main_window.active_view.scroll_to_cursor ();
    }
}

public class SearchAndReplace : GLib.Object
{
    private unowned MainWindow _main_window;
    private Document _working_document;

    private Grid _main_grid;
    private Grid _replace_grid;

    private Button _button_arrow;
    private Arrow _arrow;

    private Entry _entry_find;
    private Label _label_find_normal;
    private Label _label_find_error;

    private Entry _entry_replace;

    private CheckMenuItem _check_case_sensitive;
    private CheckMenuItem _check_entire_word;

    private int min_nb_chars_for_incremental_search = 3;

    private enum Mode
    {
        SEARCH,
        SEARCH_AND_REPLACE
    }

    private Mode get_mode ()
    {
        if (_arrow.arrow_type == ArrowType.UP)
            return Mode.SEARCH_AND_REPLACE;

        return Mode.SEARCH;
    }

    private bool case_sensitive
    {
        get { return _check_case_sensitive.get_active (); }
    }

    private bool entire_word
    {
        get { return _check_entire_word.get_active (); }
    }

    public SearchAndReplace (MainWindow main_window)
    {
        _main_window = main_window;

        _main_grid = new Grid ();

        /* Arrow */
        _button_arrow = new Button ();
        _arrow = new Arrow (ArrowType.DOWN, ShadowType.OUT);
        _button_arrow.add (_arrow);
        _main_grid.attach (_button_arrow, 0, 0, 1, 1);

        /* Find entry */
        Frame frame_find = get_find_entry ();
        _main_grid.attach (frame_find, 1, 0, 1, 1);

        /* Buttons at the right of the find entry */
        Button button_clear_find = get_button (Stock.CLEAR);
        Button button_previous = get_button (Stock.GO_UP);
        Button button_next = get_button (Stock.GO_DOWN);
        Button button_close = get_button (Stock.CLOSE);

        _main_grid.attach (button_clear_find, 2, 0, 1, 1);
        _main_grid.attach (button_previous, 3, 0, 1, 1);
        _main_grid.attach (button_next, 4, 0, 1, 1);
        _main_grid.attach (button_close, 5, 0, 1, 1);

        /* Replace entry */
        _replace_grid = new Grid ();
        _replace_grid.set_orientation (Orientation.HORIZONTAL);
        _main_grid.attach (_replace_grid, 1, 1, 5, 1);

        Frame frame_replace = new Frame (null);
        frame_replace.width_request = 350;

        _entry_replace = new Entry ();
        _entry_replace.has_frame = false;
        _entry_replace.set_tooltip_text (_("Replace with"));
        _entry_replace.can_focus = true;

        frame_replace.add (_entry_replace);
        _replace_grid.add (frame_replace);

        /* Buttons at the right of the replace entry */
        Button button_clear_replace = get_button (Stock.CLEAR);
        Button button_replace = get_button (Stock.FIND_AND_REPLACE);

        // replace all: image + label
        Button button_replace_all = new Button ();
        Grid replace_all_grid = new Grid ();
        replace_all_grid.set_orientation (Orientation.HORIZONTAL);
        replace_all_grid.set_column_spacing (8);

        Image image = new Image.from_stock (Stock.FIND_AND_REPLACE, IconSize.MENU);
        replace_all_grid.add (image);

        Label label = new Label (_("All"));
        replace_all_grid.add (label);
        button_replace_all.add (replace_all_grid);

        _replace_grid.add (button_clear_replace);
        _replace_grid.add (button_replace);
        _replace_grid.add (button_replace_all);

        /* signal handlers */

        _button_arrow.clicked.connect (() =>
        {
            // search and replace -> search
            if (get_mode () == Mode.SEARCH_AND_REPLACE)
            {
                _arrow.arrow_type = ArrowType.DOWN;
                _replace_grid.hide ();
            }

            // search -> search and replace
            else
            {
                _arrow.arrow_type = ArrowType.UP;
                _replace_grid.show ();
            }
        });

        button_close.clicked.connect (hide);

        button_clear_find.clicked.connect (() => _entry_find.text = "");
        button_clear_replace.clicked.connect (() => _entry_replace.text = "");

        button_previous.clicked.connect (() =>
        {
            set_search_text (false);
            return_if_fail (_working_document != null);
            _working_document.search_backward ();
        });

        button_next.clicked.connect (search_forward);
        _entry_find.activate.connect (search_forward);

        _entry_find.changed.connect (() =>
        {
            bool sensitive = _entry_find.text_length > 0;
            button_clear_find.sensitive = sensitive;
            button_previous.sensitive = sensitive;
            button_next.sensitive = sensitive;
            button_replace.sensitive = sensitive;
            button_replace_all.sensitive = sensitive;

            if (_entry_find.text_length == 0)
            {
                _label_find_normal.hide ();
                _label_find_error.hide ();
                clear_search ();
            }
            else if (_entry_find.text_length >= min_nb_chars_for_incremental_search)
                set_search_text ();
        });

        _entry_replace.changed.connect (() =>
        {
            button_clear_replace.sensitive = _entry_replace.text_length > 0;
        });

        _check_case_sensitive.toggled.connect (() => set_search_text ());
        _check_entire_word.toggled.connect (() => set_search_text ());

        button_replace.clicked.connect (replace);
        _entry_replace.activate.connect (replace);

        button_replace_all.clicked.connect (() =>
        {
            return_if_fail (_entry_find.text_length != 0);
            set_search_text ();
            _working_document.replace_all (_entry_replace.text);
        });

        _entry_find.key_press_event.connect ((event) =>
        {
            // See GDK_KEY_* in gdk/gdkkeysyms.h (not available in Vala)
            switch (event.keyval)
            {
                case 0xff09:    // GDK_KEY_Tab
                    // TAB in find => go to replace
                    show_search_and_replace ();
                    _entry_replace.grab_focus ();
                    return true;

                case 0xff1b:    // GDK_KEY_Escape
                    // Escape in find => select text and hide search
                    select_selected_search_text ();
                    hide ();
                    return true;

                default:
                    // propagate the event further
                    return false;
            }
        });

        _main_grid.hide ();
    }

    /* Find entry, with two labels for displaying some information */
    private Frame get_find_entry ()
    {
        Frame frame_find = new Frame (null);
        frame_find.shadow_type = ShadowType.IN;
        frame_find.width_request = 350;

        Grid grid_find = new Grid ();
        grid_find.set_orientation (Orientation.HORIZONTAL);

        /* Entry */
        _entry_find = new Entry ();
        _entry_find.set_has_frame (false);
        _entry_find.primary_icon_stock = Stock.PROPERTIES;
        _entry_find.primary_icon_activatable = true;
        _entry_find.set_tooltip_text (_("Search for"));
        _entry_find.can_focus = true;
        grid_find.add (_entry_find);

        /* "Normal" information (number of matches, etc.) */
        EventBox eventbox_normal = new EventBox ();
        _label_find_normal = new Label (null);

        Pango.AttrList attributes = new Pango.AttrList ();

        // foreground: light gray (#AAAA AAAA AAAA)
        Pango.Attribute attr_foreground = Pango.attr_foreground_new (43690, 43690, 43690);
        attributes.insert ((owned) attr_foreground);

        // background: white
        Pango.Attribute attr_background = Pango.attr_background_new (65535, 65535, 65535);
        attributes.insert ((owned) attr_background);

        _label_find_normal.set_attributes (attributes);
        eventbox_normal.add (_label_find_normal);
        grid_find.add (eventbox_normal);

        /* "Error" information (text not found, etc.) */
        EventBox eventbox_error = new EventBox ();
        _label_find_error = new Label (null);

        attributes = new Pango.AttrList ();

        // foreground: white
        attr_foreground = Pango.attr_foreground_new (65535, 65535, 65535);
        attributes.insert ((owned) attr_foreground);

        // background: red (#CCCC 0000 0000)
        attr_background = Pango.attr_background_new (52428, 0, 0);
        attributes.insert ((owned) attr_background);

        _label_find_error.set_attributes (attributes);
        eventbox_error.add (_label_find_error);
        grid_find.add (eventbox_error);

        // eventboxes style
        Gdk.Color white;
        Gdk.Color.parse ("white", out white);
        eventbox_normal.modify_bg (StateType.NORMAL, white);
        eventbox_error.modify_bg (StateType.NORMAL, white);

        frame_find.add (grid_find);

        /* Options menu */
        Menu menu = new Menu ();
        _check_case_sensitive = new CheckMenuItem.with_label (_("Case sensitive"));
        _check_entire_word = new CheckMenuItem.with_label (_("Entire words only"));
        menu.append (_check_case_sensitive);
        menu.append (_check_entire_word);
        menu.show_all ();

        _entry_find.icon_press.connect ((icon_pos, event) =>
        {
            // options menu
            if (icon_pos == EntryIconPosition.PRIMARY)
                menu.popup (null, null, null, event.button.button, event.button.time);
        });

        return frame_find;
    }

    private Button get_button (string stock_id)
    {
        Button button = new Button ();
        Image image = new Image.from_stock (stock_id, IconSize.MENU);
        button.add (image);
        return button;
    }

    public Widget get_widget ()
    {
        return _main_grid;
    }

    public void show_search ()
    {
        _arrow.arrow_type = ArrowType.DOWN;
        show ();
        _replace_grid.hide ();
    }

    public void show_search_and_replace ()
    {
        _arrow.arrow_type = ArrowType.UP;
        show ();
    }

    private void show ()
    {
        return_if_fail (_main_window.active_tab != null);

        _main_grid.show_all ();
        _label_find_normal.hide ();
        _label_find_error.hide ();
        _entry_find.grab_focus ();
        set_replace_sensitivity ();

        // if text is selected in the active document, and if this text contains no \n,
        // search this text
        Document doc = _main_window.active_document;
        if (doc.get_selection_type () == SelectionType.ONE_LINE)
        {
            TextIter start, end;
            doc.get_selection_bounds (out start, out end);
            _entry_find.text = doc.get_text (start, end, false);
        }

        _main_window.notify["active-document"].connect (active_document_changed);
    }

    public void hide ()
    {
        _main_grid.hide ();
        if (_working_document != null)
            clear_search ();

        if (_main_window.active_view != null)
            _main_window.active_view.grab_focus ();

        _main_window.notify["active-document"].disconnect (active_document_changed);
    }

    private void set_label_text (string text, bool error)
    {
        if (error)
        {
            _label_find_error.set_text (text);
            _label_find_error.show ();
            _label_find_normal.hide ();
        }
        else
        {
            _label_find_normal.set_text (text);
            _label_find_normal.show ();
            _label_find_error.hide ();
        }
    }

    private void set_search_text (bool select = true)
    {
        return_if_fail (_main_window.active_document != null);

        if (_entry_find.text_length == 0)
            return;

        if (_main_window.active_document != _working_document)
        {
            if (_working_document != null)
                clear_search ();

            _working_document = _main_window.active_document;
            _working_document.search_info_updated.connect (on_search_info_updated);
        }

        uint nb_matches, num_match;
        _working_document.set_search_text (_entry_find.text, case_sensitive, entire_word,
            out nb_matches, out num_match, select);

        on_search_info_updated (nb_matches != 0, nb_matches, num_match);
    }

    private void select_selected_search_text ()
    {
        return_if_fail (_main_window.active_document != null);

        if (_working_document != null);
            _working_document.select_selected_search_text ();
    }

    private void search_forward ()
    {
        set_search_text (false);
        return_if_fail (_working_document != null);
        _working_document.search_forward ();
    }

    private void on_search_info_updated (bool selected, uint nb_matches, uint num_match)
    {
        if (selected)
            set_label_text (_("%u of %u").printf (num_match, nb_matches), false);
        else if (nb_matches == 0)
            set_label_text (_("Not found"), true);
        else if (nb_matches == 1)
            set_label_text (_("One match"), false);
        else
            set_label_text (_("%u matches").printf (nb_matches), false);
    }

    private void clear_search ()
    {
        if (_working_document != null)
        {
            _working_document.clear_search ();
            _working_document.search_info_updated.disconnect (on_search_info_updated);
            _working_document = null;
        }
    }

    private void active_document_changed ()
    {
        _label_find_normal.hide ();
        _label_find_error.hide ();
        set_replace_sensitivity ();
    }

    private void set_replace_sensitivity ()
    {
        bool readonly = _main_window.active_document.readonly;
        _replace_grid.set_sensitive (! readonly);
    }

    private void replace ()
    {
        return_if_fail (_entry_find.text_length != 0);
        set_search_text ();
        _working_document.replace (_entry_replace.text);
    }
}
