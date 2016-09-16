#!/usr/local/bin/perl
package Constants;

use strict;
use FindBin '$Bin';
use lib;

use vars qw(@ISA @EXPORT);
use Exporter;

@ISA = qw (Exporter);
@EXPORT = qw (	CONFIG_PATH
				LIB_PATH
				LOG_PATH
				LAST_PROCESSED_TIMESTAMP_FILE
				TRUE
              	FALSE
              	DELIMITER
				PROCESS_LOCK_FILE);

use constant CONFIG_PATH => "$Bin/conf";
use constant LIB_PATH => " $Bin/lib/";
use constant LOG_PATH => "$Bin/log";
use constant LAST_PROCESSED_TIMESTAMP_FILE => CONFIG_PATH."/LAST_ROCESSED_TIMESTAMP";

# Boolean constant
use constant TRUE  => 1;
use constant FALSE => 0;
use constant DELIMITER => ",";

use constant PROCESS_LOCK_FILE => CONFIG_PATH."/process.lck";

return 1;
