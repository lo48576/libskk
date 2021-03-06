/*
 * Copyright (C) 2011-2018 Daiki Ueno <ueno@gnu.org>
 * Copyright (C) 2011-2018 Red Hat, Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace Skk {
    public errordomain KeyEventFormatError {
        PARSE_FAILED,
        KEYSYM_NOT_FOUND
    }

    /**
     * A set of bit-flags to indicate the state of modifier keys.
     */
    [Flags]
    public enum ModifierType {
        NONE = 0,
        SHIFT_MASK = 1 << 0,
        LOCK_MASK = 1 << 1,
        CONTROL_MASK = 1 << 2,
        MOD1_MASK = 1 << 3,
        MOD2_MASK = 1 << 4,
        MOD3_MASK = 1 << 5,
        MOD4_MASK = 1 << 6,
        MOD5_MASK = 1 << 7,

        // dummy modifiers for NICOLA
        LSHIFT_MASK = 1 << 22,
        RSHIFT_MASK = 1 << 23,
        USLEEP_MASK = 1 << 24,

        SUPER_MASK = 1 << 26,
        HYPER_MASK = 1 << 27,
        META_MASK = 1 << 28,
        RELEASE_MASK = 1 << 30
    }

    /**
     * Object representing a key event.
     */
    public class KeyEvent : Object {
        /**
         * The base name of the KeyEvent.
         *
         * This is exclusive to {@link code}.
         */
        public string? name { get; private set; }

        /**
         * The base code of the KeyEvent.
         *
         * This is exclusive to {@link name}.
         */
        public unichar code { get; private set; }

        /**
         * Modifier mask.
         */
        public ModifierType modifiers { get; set; }

        /**
         * Create a key event.
         *
         * @param name a key name
         * @param code a character code
         * @param modifiers state of modifier keys
         *
         * @return a new KeyEvent
         */
        public KeyEvent (string? name,
                         unichar code,
                         ModifierType modifiers) {
            this.name = name;
            this.code = code;
            this.modifiers = modifiers;
        }

        /**
         * Create a copy of the key event.
         *
         * @return a new KeyEvent
         */
        public KeyEvent copy () {
            return new KeyEvent (name, code, modifiers);
        }

        /**
         * Create a key event from string.
         *
         * @param key a string representation of a key event
         *
         * @return a new KeyEvent
         */
        public KeyEvent.from_string (string key) throws KeyEventFormatError {
            ModifierType _modifiers = 0;
            uint _keyval = Keysyms.VoidSymbol;
            if (key.has_prefix ("(usleep ") && key.has_suffix (")")) {
                // special key event for SKK-NICOLA
                var strv = key[1:-1].split (" ");
                if (strv.length != 2) {
                    throw new KeyEventFormatError.PARSE_FAILED (
                        "usleep requires duration");
                }
                name = strv[1];
                code = '\0';
                modifiers |= ModifierType.USLEEP_MASK;
            } else if (key.has_prefix ("(") && key.has_suffix (")")) {
                var strv = key[1:-1].split (" ");
                int index = 0;
                for (; index < strv.length - 1; index++) {
                    if (strv[index] == "shift") {
                        _modifiers |= ModifierType.SHIFT_MASK;
                    } else if (strv[index] == "control") {
                        _modifiers |= ModifierType.CONTROL_MASK;
                    } else if (strv[index] == "meta") {
                        _modifiers |= ModifierType.META_MASK;
                    } else if (strv[index] == "hyper") {
                        _modifiers |= ModifierType.HYPER_MASK;
                    } else if (strv[index] == "super") {
                        _modifiers |= ModifierType.SUPER_MASK;
                    } else if (strv[index] == "alt") {
                        _modifiers |= ModifierType.MOD1_MASK;
                    } else if (strv[index] == "lshift") {
                        _modifiers |= ModifierType.LSHIFT_MASK;
                    } else if (strv[index] == "rshift") {
                        _modifiers |= ModifierType.RSHIFT_MASK;
                    } else if (strv[index] == "release") {
                        _modifiers |= ModifierType.RELEASE_MASK;
                    } else {
                        throw new KeyEventFormatError.PARSE_FAILED (
                            "unknown modifier %s", strv[index]);
                    }
                }
                // special key event for SKK-NICOLA
                if (strv[index] == "lshift" || strv[index] == "rshift") {
                    name = strv[index];
                    code = '\0';
                    modifiers = ModifierType.NONE;
                } else {
                    _keyval = KeyEventUtils.keyval_from_name (strv[index]);
                    if (_keyval == Keysyms.VoidSymbol)
                        throw new KeyEventFormatError.PARSE_FAILED (
                            "unknown keyval %s", strv[index]);
                    name = KeyEventUtils.keyval_name (_keyval);
                    code = KeyEventUtils.keyval_unicode (_keyval);
                    modifiers = _modifiers;
                }
            } else if (key.has_prefix ("[") && key.has_suffix ("]") &&
                       key.char_count () == 4) {
                // special double key press events (SKK-NICOLA extension)
                name = key;
                code = '\0';
                modifiers = ModifierType.NONE;
            } else {
                int index = key.last_index_of ("-");
                string? _name = null;
                if (index > 0) {
                    // support only limited modifiers in this form
                    string[] mods = key.substring (0, index).split ("-");
                    foreach (var mod in mods) {
                        if (mod == "S") {
                            _modifiers |= ModifierType.SHIFT_MASK;
                        } else if (mod == "C") {
                            _modifiers |= ModifierType.CONTROL_MASK;
                        } else if (mod == "A") {
                            _modifiers |= ModifierType.MOD1_MASK;
                        } else if (mod == "M") {
                            _modifiers |= ModifierType.META_MASK;
                        } else if (mod == "G") {
                            _modifiers |= ModifierType.MOD5_MASK;
                        }
                    }
                    _name = key.substring (index + 1);
                } else {
                    _modifiers = ModifierType.NONE;
                    _name = key;
                }
                _keyval = KeyEventUtils.keyval_from_name (_name);
                if (_keyval == Keysyms.VoidSymbol)
                    throw new KeyEventFormatError.PARSE_FAILED (
                        "unknown keyval %s", _name);
                name = KeyEventUtils.keyval_name (_keyval);
                code = KeyEventUtils.keyval_unicode (_keyval);
                modifiers = _modifiers;
            }
        }

        /**
         * Convert the KeyEvent to string.
         *
         * @return a string representing the KeyEvent
         */
        public string to_string () {
            string _base = name != null ? name : code.to_string ();
            if (modifiers != 0) {
                ArrayList<string?> elements = new ArrayList<string?> ();
                if ((modifiers & ModifierType.CONTROL_MASK) != 0) {
                    elements.add ("control");
                }
                if ((modifiers & ModifierType.META_MASK) != 0) {
                    elements.add ("meta");
                }
                if ((modifiers & ModifierType.HYPER_MASK) != 0) {
                    elements.add ("hyper");
                }
                if ((modifiers & ModifierType.SUPER_MASK) != 0) {
                    elements.add ("super");
                }
                if ((modifiers & ModifierType.MOD1_MASK) != 0) {
                    elements.add ("alt");
                }
                if ((modifiers & ModifierType.LSHIFT_MASK) != 0) {
                    elements.add ("lshift");
                }
                if ((modifiers & ModifierType.RSHIFT_MASK) != 0) {
                    elements.add ("rshift");
                }
                if ((modifiers & ModifierType.USLEEP_MASK) != 0) {
                    elements.add ("usleep");
                }
                if ((modifiers & ModifierType.RELEASE_MASK) != 0) {
                    elements.add ("release");
                }
                elements.add (_base);
                elements.add (null); // make sure that strv ends with null
                // newer valac thinks null in a fixed length array as
                // an empty string
                var array = elements.to_array ();
                // Change length of strv may make vala no able to free it
                // correctly. Save the length and restore it later.
                var old_length = array.length;
                array.length = -1;
                var key_string = "(" + string.joinv (" ", array) + ")";
                array.length = old_length;
                return key_string;
            } else {
                return _base;
            }
        }

        /**
         * Create a key event from an X keysym and modifiers.
         *
         * @param keyval an X keysym
         * @param modifiers modifier mask
         *
         * @return a new KeyEvent
         */
        public KeyEvent.from_x_keysym (uint keyval,
                                       ModifierType modifiers) throws KeyEventFormatError {
            name = KeyEventUtils.keyval_name (keyval);
            code = KeyEventUtils.keyval_unicode (keyval);

            this.modifiers = modifiers;
        }

        /**
         * Compare two key events ignoring modifiers.
         *
         * @param key a KeyEvent
         *
         * @return `true` if those base components are equal, `false` otherwise
         */
        public bool base_equal (KeyEvent key) {
            return code == key.code && name == key.name;
        }
    }
}
