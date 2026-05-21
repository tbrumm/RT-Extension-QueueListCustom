use lib '.';

use inc::Module::Install;

RTx 'RT-Extension-QueueListCustom';

all_from 'lib/RT/Extension/QueueListCustom.pm';

readme_from 'lib/RT/Extension/QueueListCustom.pm';

license 'gplv2';

requires_rt '6.0.0';

rt_too_new '6.2.0';

repository 'https://github.com/misy1337/RT-Extension-QueueListCustom';

sign;

WriteAll;
