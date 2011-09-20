#!/usr/bin/perl

# use packages {{{1
use warnings;
use strict;

use Date::Calendar::Profiles qw{ $Profiles };
use Date::Calendar;
use Date::Calc qw ( :all );

sub Wrkd_Nbr_Mth #{{{1
{
	(my $year, my $month, my $cal) = @_;
	my $days = Days_in_Month($year, $month);
	return $cal->delta_workdays($year, $month, 1,
		$year, $month, $days, 1, 1);
}

sub Wrkd_Nbr_Qtr #{{{1
{
	(my $year, my $qrt, my $cal) = @_;
	my $days = Days_in_Month($year, $qrt*3);
	return $cal->delta_workdays($year, ($qrt*3)-2, 1,
		$year, $qrt*3, $days, 1, 1);
}
sub Wrkd_Nbr_Yr #{{{1
{
	(my $year, my $cal) = @_;
	return $cal->delta_workdays($year, 1, 1,
		$year, 12, 31, 1, 1);
}
sub DoMain #{{{1
{
	my $year_end = shift;
	my @calendar   = ("DE", "AT", "CH-DE");
	Language(Decode_Language("Deutsch")); # deutsche Ausgabe

	foreach (@calendar){
		print "Generating kalendar for: ".  $_;
		my $filename = "src_man_Kalender_" . $_ . ".dat";
		open(my $fh, '>', $filename) or
			die "Can't open file $filename for writing: $!\n";
		my $month = 1;
		my $day   = 1;
		my $year  = (localtime)[5] + 1900;
		my $days  = Date_to_Days($year, $month, $day);
		my $cal   = Date::Calendar->new($Profiles->{$_},1);
		my %count = (
			"month"   => 0, # Work days month
			"quarter" => 0, # Work days quarter
			"year"    => 0, # Work days year
		);
		my %Wrkd_Mth;
		my %Wrkd_Qtr;
		my %Wrkd_Yr;
		# generate Header
		print $fh "TM_ID;DT;YR;QTR;MTH_NM;WK;WKD_NM;DY_TYP;Tertiaer;WRKD_NBR_MTH;TOT_WRKD_NBR_MTH;WRKD_NBR_QTR;TOT_WRKD_NBR_QTR;WRKD_NBR_YR;TOT_WRKD_NBR_YR;MTH_NM_SHRT;ISO_YR;ISO_WK\n";

		do {
			my $dow   = Day_of_Week($year, $month, $day);
			my $qrt   = int(($month - 1)/3) + 1;
			$count{"month"}   = 0 if ($day == 1);
			$count{"quarter"} = 0 if ($day == 1 && !(($month - 1) % 3));
			$count{"year"}    = 0 if ($day == 1 && ($month == 1));
			# TM_ID
			printf $fh "%04d%02d%02d;", $year, $month, $day;
			# Date (not needed)
			printf $fh "%02d.%02d.%4d;", $day, $month, $year;
			# Year
			printf $fh "%4d;", $year;
			# Qtr
			printf $fh "%i;", $month/4+1;
			# Month name
			printf $fh "%s;", Month_to_Text($month);
			# Week
			printf $fh "%d;", int(($day + Day_of_Week($year, $month, 1) - 2) / 7) + 1;
			# Weekday name
			printf $fh "%s;", Day_of_Week_to_Text($dow);
			# Day typ
			if ($cal->is_full($year, $month, $day))
			{
				print $fh "F;";
			}
			elsif ($dow > 5){
				print $fh "X;";
			}
			else {
				print $fh "W;";
				$count{"month"}++;
				$count{"quarter"}++;
				$count{"year"}++;
			}
			# Tertiär (nicht benutzt)
			print $fh ";";
			# WRKD_NBR_MTH
			printf $fh "%d;", $count{"month"};
			# TOT_WRKD_NBR_MTH
			unless (defined $Wrkd_Mth{$year*100+$month}){
				$Wrkd_Mth{$year*100+$month} = Wrkd_Nbr_Mth($year, $month, $cal);
			}
			printf $fh "%d;", $Wrkd_Mth{$year*100+$month};
			# WRKD_NBR_QTR
			printf $fh "%d;", $count{"quarter"};
			# TOT_WRKD_NBR_QTR
			unless (defined $Wrkd_Qtr{$year * 10 + $qrt}){
				$Wrkd_Qtr{$year * 10 + $qrt} = Wrkd_Nbr_Qtr($year, $qrt, $cal);
			}
			printf $fh "%d;", $Wrkd_Qtr{$year*10 + $qrt};
			# WRKD_NBR_YR
			printf $fh "%d;", $count{"year"};
			# TOT_WRKD_NBR_YR
			unless (defined $Wrkd_Yr{$year}){
				$Wrkd_Yr{$year} = Wrkd_Nbr_Yr($year, $cal);
			}
			printf $fh "%d;", $Wrkd_Yr{$year};
			# MTH_NM_SHRT
			printf $fh "%s;", uc(substr(Month_to_Text($month),0,3));
			# ISO_YR and ISO_WK
			printf $fh "%s\n", join(';', reverse Week_of_Year($year, $month, $day));

			# increment counter
			($year, $month, $day) = Add_Delta_Days($year, $month, $day, 1);

		} while ($year <= $year_end);
		print "\t\tDone\n";
	}
}

sub usage #{{{1
{
	chomp(my $name=`basename $0`);
	print <<EOF;
$name
Usage: $name <year>
$name generates calendars in csv format for each of the countries Germany (Hessen), Austria and Switzerland and stores each of them in a file called src_man_Kalendar<country>.dat in the current directory.

Option:
-h --help				This screen
EOF
	exit(0);
}

# Configuration #{{{1
# Definierter Kalender für Deutschland
# fügt Fronleichnam als ges. Feiertag hinzu, behandle Heiligabend
# und Sylvester als Feiertage
$Profiles->{'DE'} = # Deutschland (+Fronleichnam fuer Hessen)
{
    %{$Profiles->{'DE-HE'}},
    "Heiligabend"               => "24.12.",
    "Sylvester"                 => "31.12."
};

# Main routine {{{1
if ($#ARGV < 0 || (defined($ARGV[0]) && $ARGV[0] !~ /\d{4}/)){
	usage;
}
else {
	DoMain $ARGV[0];
}


# Modeline {{{1
# vim: set fdm=marker fdl=0:
