###########################################################################
#
# encodings.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

# Each encoding supported by the Greenstone build-time software should be
# specified in the following hash table ($encodings).

package encodings;

use strict;

# $encodings takes the form:
# --> identifier --> name      --> The full display name of the encoding.
#                --> mapfile   --> The ump file associated with the encoding
#                --> double    --> 1 if it's a double byte encoding
#                --> converter --> If the encoding needs a specialized conversion
#                                  routine this is the name of that routine.

$encodings::encodings = {
    'iso_8859_1' => {'name' => 'Latin1 (western languages)', 'mapfile' => '8859_1.ump'},

    'iso_8859_2' => {'name' => 'Latin2 (central and eastern european languages)',
		     'mapfile' => '8859_2.ump'},

    'iso_8859_3' => {'name' => 'Latin3', 'mapfile' => '8859_3.ump'},

    'iso_8859_4' => {'name' => 'Latin4', 'mapfile' => '8859_4.ump'},

    'iso_8859_5' => {'name' => 'Cyrillic', 'mapfile' => '8859_5.ump'},

    'iso_8859_6' => {'name' => 'Arabic', 'mapfile' => '8859_6.ump'},

    'iso_8859_7' => {'name' => 'Greek', 'mapfile' => '8859_7.ump'},

    'iso_8859_8' => {'name' => 'Hebrew', 'mapfile' => '8859_8.ump'},

    'iso_8859_9' => {'name' => 'Turkish', 'mapfile' => '8859_9.ump'},

    'iso_8859_15' => {'name' => 'Latin15 (revised western)', 'mapfile' => '8859_15.ump'},

    'windows_1250' => {'name' => 'Windows codepage 1250 (WinLatin2)',
		       'mapfile' => 'win1250.ump'},

    'windows_1251' => {'name' => 'Windows codepage 1251 (WinCyrillic)',
		       'mapfile' => 'win1251.ump'},

    'windows_1252' => {'name' => 'Windows codepage 1252 (WinLatin1)',
		       'mapfile' => 'win1252.ump'},

    'windows_1253' => {'name' => 'Windows codepage 1253 (WinGreek)', 
		       'mapfile' => 'win1253.ump'},

    'windows_1254' => {'name' => 'Windows codepage 1254 (WinTurkish)',
		       'mapfile' => 'win1254.ump'},

    'windows_1255' => {'name' => 'Windows codepage 1255 (WinHebrew)', 
		       'mapfile' => 'win1255.ump'},

    'windows_1256' => {'name' => 'Windows codepage 1256 (WinArabic)', 
		       'mapfile' => 'win1256.ump'},

    'windows_1257' => {'name' => 'Windows codepage 1257 (WinBaltic)',
		       'mapfile' => 'win1257.ump'},

    'windows_1258' => {'name' => 'Windows codepage 1258 (Vietnamese)',
		       'mapfile' => 'win1258.ump'},

    'windows_874' => {'name' => 'Windows codepage 874 (Thai)', 'mapfile' => 'win874.ump'},

    'dos_437' => {'name' => 'DOS codepage 437 (US English)', 'mapfile' => 'dos437.ump'},

    'dos_850' => {'name' => 'DOS codepage 850 (Latin 1)', 'mapfile' => 'dos850.ump'},

    'dos_852' => {'name' => 'DOS codepage 852 (Central European)', 'mapfile' => 'dos852.ump'},

    'dos_866' => {'name' => 'DOS codepage 866 (Cyrillic)', 'mapfile' => 'dos866.ump'},

    'koi8_r' => {'name' => 'Cyrillic', 'mapfile' => 'koi8_r.ump'},

    'koi8_u' => {'name' => 'Cyrillic (Ukrainian)', 'mapfile' => 'koi8_u.ump'},

    'iscii_de' => {'name' => 'ISCII Devanagari', 'mapfile' => 'iscii_de.ump'},

    'shift_jis' => {'name' => 'Japanese (Shift-JIS)', 'mapfile' => 'shiftjis.ump',
		    'converter' => 'shiftjis2unicode'},

    'euc_jp' => {'name' => 'Japanese (EUC)', 'mapfile' => 'euc_jp.ump'},

    'korean' => {'name' => 'Korean (Unified Hangul Code - i.e. a superset of EUC-KR)',
		 'mapfile' => 'uhc.ump'},

    'gb' => {'name' => 'Chinese Simplified (GB)', 'mapfile' => 'gbk.ump'},

    'big5' => {'name' => 'Chinese Traditional (Big5)', 'mapfile' => 'big5.ump'}

};
