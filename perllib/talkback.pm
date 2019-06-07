###########################################################################
#
# talkback.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
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

package talkback;

use strict;


sub generate_upload_form
{
    my ($uniq_file) = @_;

    my $upload_html_form = <<EOF
 
<html>
  <head>
  </head>
  <body>
    <form name="defaultForm" 
          action="talkback-progressbar.pl"
          enctype="multipart/form-data" method="post">
      <input type="hidden" name="yes_upload" value="1" />
      <input type="hidden" name="process" value="1" />

      <p>
        <input type="file" size="50" name="uploadedfile" />
        <span style="font-size:20pt; font-weight:bold;">&rarr;</span>
        <input type="submit" value="Upload File" />
      </p>

      <script language="Javascript"> 
        setInterval("check_status(['check_upload__1', 'xx', 'uploadedfile'], ['statusbar']);", '1000');
      </script> 

    </form>


    <div id="statusbar"></div>
  </body>
</html>

EOF
    ; 

    return $upload_html_form;
}

sub generate_upload_form_progressbar
{
    my ($uniq_file) = @_;

    my $upload_html_form = <<EOF
 
<html>
  <head>
  </head>
  <body>


    <form name="talkbackUploadPB" 
          action="talkback-progressbar.pl"
          enctype="multipart/form-data" method="post">
      <input type="hidden" name="uploadedfile" value="$uniq_file" />
      <input type="hidden" name="xx" value="$uniq_file" />
    </form>


    <script type="text/javascript"> 
      setInterval("check_status(['check_upload__1', 'xx', 'uploadedfile'], ['statusbar']);", '1000');

    </script> 

    <div style="width: 380px;" id="statusbar">status bar:</div>
  </body>
</html>

EOF
    ; 


    return $upload_html_form;
}




sub generate_done_html
{
    my ($full_filename) = @_;

    my $done_html = <<EOF

<html>
  <head>
  </head>
  <body>
    <h3>
      File uploaded. 
    </h3>

    <hr /> 
    <p> 
     <i>Server file: $full_filename</i>
    </p>
  </body>
</html>

EOF
    ; 

    return $done_html;
}

sub generate_malformed_args_html
{
    my ($full_filename) = @_;

    my $done_html = <<EOF

<html>
  <head>
  </head>
  <body>
    <h3>
      Oops!
    </h3>
    <hr /> 
    <p> 
     Malformed CGI arguments.
    </p>
  </body>
</html>

EOF
    ; 

    return $done_html;
}


1;
