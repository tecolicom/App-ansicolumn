use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use App::ansicolumn;

######################################################################
# table_widths: water-level allocation
######################################################################

sub tw { App::ansicolumn::table_widths(@_) }

is_deeply(tw([6,12,60,300], 74, 0, undef, 4), [6,12,28,28], 'worked example');
is_deeply(tw([6,12,60,300], 74, 2, undef, 4), [6,12,24,24], 'with item-format overhead');
is_deeply(tw([5,5], 20, 0, undef, 4),         [5,5],        'fits: unchanged');
is_deeply(tw([5,5], undef, 0, undef, 4),      [5,5],        'no budget: unchanged');
is_deeply(tw([50,50,50], 10, 0, undef, 4),    [4,4,4],      'floor');
is_deeply(tw([50,50], -3, 0, undef, 4),       [4,4],        'budget-negative');
is_deeply(tw([10,30,30], 40, 0, [undef,8,undef], 4), [10,8,22], 'fixed column removed from budget');
is_deeply(tw([3,3], undef, 0, [20,undef], 4), [20,3],       'fixed without budget');

done_testing;
