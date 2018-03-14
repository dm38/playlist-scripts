#!/usr/bin/perl -w
# ./m3u_sort_and_add_logo <playlist.m3u> <logo patch>
use utf8;
use open ':utf8', ':std';
#require utf8::all;
use Encode;

my %channel_prioritet = ('Первый канал HD'	=> 1,
			 'Россия 1 HD'		=> 2,
			 'МАТЧ! ТВ HD'		=> 3,
			 'НТВ'			=> 4,
			 'Пятый канал'		=> 5,
			 'Россия К'		=> 6,
			 'Россия 24' 		=> 7,
			 'Карусель' 		=> 8,
			 'ОТР'			=> 9,
			 'ТВЦ'			=> 10,
			 'РЕН ТВ'		=> 11,
			 'СПАС ТВ'		=> 12,
			 'СТС'			=> 13,
			 'Домашний'		=> 14,
			 'ТВ-3'			=> 15,
			 'Пятница'		=> 16,
			 'Звезда'		=> 17,
			 'МИР'			=> 18,
			 'ТНТ HD'		=> 19,
			 'Муз ТВ'		=> 20,
			 'Санкт-Петербург'	=> 21,
			 '47 канал'		=> 22);

my %XMLTV;
my %LOGO_LIST;
my %PLAY_LIST;
my %channel_param;
my $prog_num = 0;

sub gen_channel_str_id
{
    $result=lc(shift);
    $result =~ s/[\"\s\-\!\+\\\/\._]//g; # избавляемся от кавычек,пробелов,"-", "+", "!", "\", "/", ".", "_"
    $result =~ s/ё/е/g;
    return $result;
}

sub split_param
{
    my $param = shift;
    my %params;
    if (!($param)) {return};
    $param =~ '((\S+?)\s*?=\s*?(\"{1,}.{1,}?\"{1,}|\S+))\s*(.*)';
    $param = $4;
    my $param_name = $2;
    my $param_value = $3;
    $param_value =~ s/\"//g;
    $params{$param_name} = $param_value;
    return (%params, split_param($param));
}

sub print_param
{
    my ($hash) = shift;
    my $st="";
#    if (!defined $hash) {return $st};
    foreach my $key (keys %{$hash}){
    $st=$st." $key=\"$hash->{$key}\"";
    }
    return $st;
}

sub channel_cmp
{
    $PLAY_LIST{$a}{'params'}{'group-title'} cmp $PLAY_LIST{$b}{'params'}{'group-title'}||
    $PLAY_LIST{$a}{'prior'} <=> $PLAY_LIST{$b}{'prior'} ||
    $PLAY_LIST{$a}{'name'} cmp $PLAY_LIST{$b}{'name'};
}

sub find_xml_prog_id
{
    my $channel_mame = shift;
    my $pOPTIONS_LIST = shift;
    my %OPTIONS_LIST = %{$pOPTIONS_LIST};
    my $channel_str_id = gen_channel_str_id($channel_name);
    if (defined($OPTIONS_LIST{$channel_str_id})) {
	return $channel_str_id;
    }
    $channel_str_id =~ s/(\S*)hd$/$1/;
    if (defined($OPTIONS_LIST{$channel_str_id})) {
	return $channel_str_id;
    }

    my %FOUND_ID_LIST;
    my $I = 0;
    foreach my $id (keys %OPTIONS_LIST) {
	if ($id =~ m/^$channel_str_id/) {
	    $FOUND_ID_LIST{++$I}=$id;
	}
	if ($channel_str_id =~ m/^$id/) {
	    $FOUND_ID_LIST{++$I}=$id;
	}
    }
    if ($I>0) {
	print STDERR "Для $channel_name найдено $I вариантов:\n";
	$I = 0;
	while ($FOUND_ID_LIST{++$I}) {
	    print STDERR "$I. $OPTIONS_LIST{$FOUND_ID_LIST{$I}}{'name'}\n";
	}
	print STDERR "Выбирайте: ";
	$user_input = <STDIN>;
	if (($user_input > 0) and ($user_input<$I)) {
	    print STDERR "$OPTIONS_LIST{$FOUND_ID_LIST{1*$user_input}}{'name'}\n";
#	    print STDERR "$user_input\n";
	    $result = $FOUND_ID_LIST{1*$user_input}
	}
    }
}

#разбираем xml программы передач
#open $FH, $ARGV[1];
#$/="\<\/channel\>";
#while (<$FH>)
#{
#    next unless /\<channel\sid\=\"(\S*)\"\>/m and my $channel_id=$1; #print "$1=";
#    /\<display\-name.*?\>(.*)\<\/display\-name\>/m and my $channel_name=$1; #print "$1\n";
#    /\<icon\ssrc\=\"(.*)\"/m and my $channel_icon=$1; #print "$1\n";
#    my $channel_str_id=gen_channel_str_id($channel_name);
#    $XMLTV{$channel_str_id}{'id'}=$channel_id;
#    $XMLTV{$channel_str_id}{'name'}=$channel_name;
#    if (defined $channel_icon) {$XMLTV{$channel_str_id}{'icon'}=$channel_icon};
#    undef $channel_icon;
#}
#close $FH;

#while (my $logo_file=glob('/DataVolume/smarttv/dev/logo/*')) {
while (glob('$ARGV[1]/*')) {
    $logo_file = decode_utf8($_);
    $logo_file =~ '.*\/(.*)\.\S*$';
    my $logo_name = $1;
    my $logo_str_id=gen_channel_str_id($logo_name);
    if (!$LOGO_LIST{$logo_str_id}) {
	$LOGO_LIST{$logo_str_id}{'name'}=$logo_name;
	$LOGO_LIST{$logo_str_id}{'path'}=$logo_file;
    } else {
	print "$logo_file дублирует $LOGO_LIST{$logo_str_id}{'path'}\n";
    }
#    print "$logo_file\n$1\n\n";
}

#exit;

#разбираем входящий лист каналов m3u
$/="\n";
open $FH, $ARGV[0];
while (defined($line = <$FH>) ) {
    if ($line =~ /#EXTINF:\S*\s*(.*),\s*(.*)\Z/) {
	%channel_param = split_param($1);
	$channel_name = $2;
#>>>>>индекс по порядковому номеру
        if (defined($murl = <$FH>) and ($murl =~ s/(.*)\n/$1/)) {
	    ++$prog_num;
#>>>>
#<<<<<индекс по номеру мультикаст группы
#        if (defined($line = <$FH>) and ($line =~ '(udp|rtp)(\/|:\/\/@)(\d+\.\d+\.\d+\.(\d+)):(\d+)')) {
#	    $mproto = $1;
#	    $mgroup = $3;
#	    $prog_num = $4;
#	    $mport = $5;
#	    $murl = "$mproto://\@$mgroup:$mport";
#	}
#	if (!defined($PLAY_LIST{$prog_num})) {
#<<<<
	    $PLAY_LIST{$prog_num}{'name'}=$channel_name;
	    $PLAY_LIST{$prog_num}{'url'}=$murl;
	    %{$PLAY_LIST{$prog_num}{'params'}}=%channel_param;
#////////////////////////////////////////////////////////////////////
#	    if (!($PLAY_LIST{$prog_num}{'params'}{'tvg-logo'} and $XMLTV{gen_channel_str_id($PLAY_LIST{$prog_num}{'params'}{'tvg-logo'})})) {
		$channel_str_id=find_xml_prog_id($channel_name, \%LOGO_LIST);
		if (defined($LOGO_LIST{$channel_str_id})) {
		    $PLAY_LIST{$prog_num}{'params'}{'tvg-logo'} = "$LOGO_LIST{$channel_str_id}{'path'}";
#		    $PLAY_LIST{$prog_num}{'params'}{'tvg-id'} = "$XMLTV{$channel_str_id}{'id'}";
#		    if ($XMLTV{$channel_str_id}{'icon'}) {$PLAY_LIST{$prog_num}{'params'}{'tvg-logo'} = "\"$XMLTV{$channel_str_id}{'icon'}\""};
		} else {
		    delete $PLAY_LIST{$prog_num}{'params'}{'tvg-logo'};
#		    delete $PLAY_LIST{$prog_num}{'params'}{'tvg-id'};
		}
#	    }
	    if (!($PLAY_LIST{$prog_num}{'prior'} = $channel_prioritet{$channel_name})) {$PLAY_LIST{$prog_num}{'prior'} = 1000};
	}
    }
}
close $FH;

print "#EXTM3U\n";
## по порядку
#for (my $ind=1;$PLAY_LIST{$ind};$ind++) {
## сортировка по индексу
#foreach my $ind (sort {$a <=> $b} keys %PLAY_LIST) {
## сортировка по критериям
foreach my $ind (sort channel_cmp keys %PLAY_LIST) {
    print "#EXTINF:-1".print_param($PLAY_LIST{$ind}{'params'}).",$PLAY_LIST{$ind}{'name'}\n";
    print "$PLAY_LIST{$ind}{'url'}\n";
}
