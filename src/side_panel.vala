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

public class SidePanel : Grid
{
    private unowned MainWindow main_window;
    private unowned ToggleAction action_view_side_panel;

    private Grid[] components;
    private ComboBox combo_box;
    private ListStore list_store;

    public SidePanel (MainWindow main_window, ToggleAction action_view_side_panel)
    {
        orientation = Orientation.VERTICAL;
        this.main_window = main_window;
        this.action_view_side_panel = action_view_side_panel;

        Grid grid = new Grid ();
        grid.set_orientation (Orientation.HORIZONTAL);
        grid.column_spacing = 3;
        grid.border_width = 3;
        add (grid);

        combo_box = get_combo_box ();
        combo_box.set_hexpand (true);
        grid.add (combo_box);
        grid.add (get_close_button ());
        show_all ();

        show.connect (show_active_component);
        hide.connect (hide_all_components);
    }

    public void add_component (string name, string stock_id, Grid component)
    {
        TreeIter iter;
        list_store.append (out iter);
        list_store.set (iter,
            SidePanelColumn.PIXBUF, stock_id,
            SidePanelColumn.NAME, name,
            -1);

        add (component);
        components += component;
    }

    public void restore_state ()
    {
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");
        int num = settings.get_int ("side-panel-component");
        num = num.clamp (0, components.length - 1);
        combo_box.set_active (num);
    }

    private Button get_close_button ()
    {
        Button close_button = new Button ();
        close_button.relief = ReliefStyle.NONE;
        close_button.focus_on_click = false;
        close_button.tooltip_text = _("Hide panel");
        close_button.add (new Image.from_stock (Stock.CLOSE, IconSize.MENU));
        close_button.clicked.connect (() =>
        {
            this.hide ();
            action_view_side_panel.active = false;
        });

        return close_button;
    }

    private enum SidePanelColumn
    {
        PIXBUF,
        NAME,
        N_COLUMNS
    }

    private ComboBox get_combo_box ()
    {
        list_store = new ListStore (SidePanelColumn.N_COLUMNS, typeof (string),
            typeof (string));

        ComboBox combo_box = new ComboBox.with_model (list_store);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        combo_box.pack_start (pixbuf_renderer, false);
        combo_box.set_attributes (pixbuf_renderer,
            "stock-id", SidePanelColumn.PIXBUF, null);

        CellRendererText text_renderer = new CellRendererText ();
        combo_box.pack_start (text_renderer, true);
        combo_box.set_attributes (text_renderer, "text", SidePanelColumn.NAME, null);

        combo_box.changed.connect (show_active_component);

        return combo_box;
    }

    public int get_active_component ()
    {
        return combo_box.get_active ();
    }

    private void hide_all_components ()
    {
        foreach (Grid component in components)
            component.hide ();
    }

    private void show_active_component ()
    {
        hide_all_components ();

        int active = get_active_component ();
            components[active].show ();
    }
}
