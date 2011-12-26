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

public class TabInfoBar : InfoBar
{
    public TabInfoBar (string primary_msg, string secondary_msg, MessageType msg_type)
    {
        Box content_area = get_content_area () as Box;

        // icon
        string stock_id;
        switch (msg_type)
        {
            case MessageType.ERROR:
                stock_id = Stock.DIALOG_ERROR;
                break;
            case MessageType.QUESTION:
                stock_id = Stock.DIALOG_QUESTION;
                break;
            case MessageType.WARNING:
                stock_id = Stock.DIALOG_WARNING;
                break;
            case MessageType.INFO:
            default:
                stock_id = Stock.DIALOG_INFO;
                break;
        }

        Image image = new Image.from_stock (stock_id, IconSize.DIALOG);
        image.set_valign (Align.START);
        content_area.pack_start (image, false, false, 0);

        // text
        Grid grid = new Grid ();
        grid.orientation = Orientation.VERTICAL;
        grid.set_row_spacing (10);
        content_area.pack_start (grid);

        Label primary_label = new Label ("<b>" + primary_msg + "</b>");
        grid.add (primary_label);
        primary_label.set_halign (Align.START);
        primary_label.set_selectable (true);
        primary_label.set_line_wrap (true);
        primary_label.set_use_markup (true);

        Label secondary_label = new Label ("<small>" + secondary_msg + "</small>");
        grid.add (secondary_label);
        secondary_label.set_halign (Align.START);
        secondary_label.set_selectable (true);
        secondary_label.set_line_wrap (true);
        secondary_label.set_use_markup (true);

        set_message_type (msg_type);
        show_all ();
    }

    public void add_ok_button ()
    {
        add_button (Stock.OK, ResponseType.OK);
        response.connect ((response_id) =>
        {
            if (response_id == ResponseType.OK)
                destroy ();
        });
    }

    public void add_stock_button_with_text (string text, string stock_id, int response_id)
    {
        Button button = add_button (text, response_id) as Button;
        Image image = new Image.from_stock (stock_id, IconSize.BUTTON);
        button.set_image (image);
    }
}
