#!/usr/bin/perl

=begin lip

=head1 NAME

recorder.pl

=head1 SYNOPSIS

RadioPod

=head1 DESCRIPTION

Controls the recording and converting of an internet radio stream to mp3 conversion system.

You will also need Mplayer and Lame installed.

=head1 AUTHOR

Ben Hammersley <ben@benhammersley.com>

=head1 BUGS

Mplayer, it seems, can't deal with some of the latest RealPlayer codecs. This causes the player to exit without recording anything.

=head1 SEE ALSO

=head1 COPYRIGHT

Ben Hammersley, 2004.

=head1 USAGE

perl recorder.pl -timestart=21:39 -timeend=21:40 --debugging -prog_name="Agincourt" -stream_url=rtsp://rmv8.bbc.net.uk/radio4/history/inourtime/inourtime.ra

=cut

########### CODE BEGINS ##########

#!/usr/bin/perl

use warnings;
use strict;
use Proc::Simple;
use Getopt::Long;
use Date::Manip;
use MP3::Info;

# You need to set these variables below to reflect your own server
my $url            = "http://nedrichards.com/~ben/";
my $path_to_public = "public_html/";

my ( $timestart, $timeend, $prog_name, $stream_url, $prog_file_name,
    $debugging_flag );

GetOptions(
    "timestart=s"  => \$timestart,
    "timeend=s"    => \$timeend,
    "prog_name=s"  => \$prog_name,
    "stream_url=s" => \$stream_url,
    "debugging"    => \$debugging_flag
);

# Parse the times into seconds since the epoch
my $time_start_in_epoch_seconds = &UnixDate( "$timestart today", "%s" );
my $time_end_in_epoch_seconds   = &UnixDate( "$timeend today",   "%s" );

# What's the time now?
my $time_now_in_epoch_seconds = time();

# Find difference between time now and time-of-start
my $time_until_start =
  ( $time_start_in_epoch_seconds - $time_now_in_epoch_seconds );

# Adjust time_until_start to deal with start times past midnight
if ( $time_until_start < 0 ) {
 $time_until_start += 24 * 60 * 60;
}


# Find difference between time-of-start and time-of-end
my $recording_time =
  ( $time_end_in_epoch_seconds - $time_start_in_epoch_seconds );

if ($debugging_flag) {

    # TEST BLOCK
    print "Time of Recording Start: $time_start_in_epoch_seconds \n";
    print "Time of Recording Stop: $time_end_in_epoch_seconds \n";
    print "Time Now: $time_now_in_epoch_seconds \n";
    print "Seconds Until Recording Start: $time_until_start \n";
    print "Duration of Recording: $recording_time \n";
}

# Append the epoch start time to the file name, to make it unique, then
# Dirify the programme name to make it suitable for a file name
# Dirify code by Ben Trott

$prog_name      = $prog_name . $time_start_in_epoch_seconds;
$prog_file_name = lc $prog_name;                               ## lower-case.
$prog_file_name =~ s!&[^;\s]+;!!g;    ## remove HTML entities.
$prog_file_name =~ s![^\w\s]!!g;      ## remove non-word/space chars.
$prog_file_name =~ tr! !_!s;          ## change space chars to underscores.

if ($debugging_flag) {

    # TEST BLOCK
    print "Filename = $prog_file_name \n";
}

# Wait until it's time to start recording
sleep($time_until_start);

# Start recording
my $recording_process = Proc::Simple->new();
$recording_process->start(
    "mplayer -cache 4000 -dumpstream -dumpfile $prog_file_name -playlist $stream_url");

# Wait until it's time to stop recording
sleep($recording_time);

# Stop recording
$recording_process->kill();

# Convert the file to wav
system("mplayer -ao pcm $prog_file_name");

# Delete the recorded stream
unlink("$prog_file_name");

# Convert the wav to mp3
system("lame -h -v -b 112 audiodump.wav $prog_file_name.mp3");

# Delete the audiodump file;
unlink("audiodump.wav");

# Change ID3 tag

my $tags = get_mp3tag("$prog_file_name.mp3");
my $todays_date = &UnixDate( "today", "%d %M %Y" );
$tags->{TITLE}  = "$prog_name $todays_date";
$tags->{ARTIST} = "$stream_url";
$tags->{YEAR}   = &UnixDate( "today", "%Y" );
set_mp3tag( "$prog_file_name.mp3", $tags );

# Move the MP3 to the public_html directory

system("mv $prog_file_name.mp3 $path_to_public$prog_file_name.mp3");

# Build the RSS file

open( RSSFILE, ">$path_to_public/rss.xml" );
print RSSFILE
  '<?xml version="1.0"?><rss version="2.0"><channel><title>RadioPod</title>';
print RSSFILE "<link>$url</link>";
print RSSFILE "<description>RadioPod created feed</description>";
print RSSFILE "<item><title>$prog_name $todays_date</title><link>";
print RSSFILE "$url$prog_file_name.mp3";
print RSSFILE '</link>';
print RSSFILE '<enclosure url="';
print RSSFILE "$url$prog_file_name.mp3";
print RSSFILE '" type="';
print RSSFILE "audio/mpeg";
print RSSFILE '"/>';
print RSSFILE '</item></channel></rss>';
close(RSSFILE);

##################################

=end lip

=cut

