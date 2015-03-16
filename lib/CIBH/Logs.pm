package CIBH::Logs;

=head1 NAME

CIBH::Logs - Functions dealing with the "Logs" from the SNMP

=cut

use strict;
use warnings;
use v5.14;     # for "state" variable

=head2 new

    my $logs=CIBH::Logs->new( $opts );

Creates a new CIBH::Logs object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $opts = shift || {};
    my $self = {
        'logs' => {},
        'opts' => {
            'log_glob' => '*',
            'log_path' => './logs',
            'shades' => 20,
            %{$opts},
        },
    };

    bless($self,$class);
    warn "reading logs from $self->{opts}->{log_path}/$self->{opts}->{log_glob}" if $self->{opts}->{debug};
    my $usage=ReadLogs([glob("$self->{opts}->{log_path}/$self->{opts}->{log_glob}")]);
    my $aliases=$self->GetAliases($usage);
    my $color_map=$self->build_color_map();
    $self->{logs}={usage=>$usage,aliases=>$aliases,color_map=>$color_map};
    return $self;
}

=head2 logs

    my $logs = $obj->logs;

Returns the log hashref. This has three parts. Usage, which is usage data
for routers, aliases which are regex info for links between routers, and
color_map which is RGB values to map utilisation.

=cut

sub logs {
    $_[0]->{logs};
}

=head2 url

    my $url=$self->url($files);

Tackles the complicated path and optional things issues to give you back a URL
for the $files arrayref.

=cut

sub url {
    my $self = shift;
    my $files = shift;
    my $opts = $self->{opts};

    my $url=$opts->{chart_cgi}.(($opts->{chart_cgi}=~/\?/)?"&":"?").
                    "file=".join(",",@{$files});
    $url.="&net=$opts->{network}" if(defined $opts->{network});

    return $url;
}

=head2 GetFiles

    my $files=$self->GetFiles($str);

Originally just called from HandleString in usage2fig, this takes a regex str
and searches for sets of files that match.  For instance, sl-bb10-atl--sl-bb.*-chi
might match some links between routers in two cities.  If a string doesn't
have a -- then it's assumed to be a router name and we search for usage data
for things like CPU utilisation.

There is a state variable that keeps a cache of found values so that lookups
are only done once, since they can be expensive.

This returns an arrayref of matching files.

=cut

sub GetFiles {
    my $self = shift;
    my $opts = $self->{opts};
    my $logs = $self->logs;

    my($str)=(@_);
    state %filehash;
    if (exists($filehash{$str})) {
        return $filehash{$str};
    }
    my $files = [];
    $str=~s/\\\\/\\/g; # strip these out - xfig puts them in;
    foreach my $alias (grep(/^$str$/,(keys %{$logs->{aliases}}))) {
        push(@{$files},@{$logs->{aliases}->{$alias}});
        warn "GetFiles regexp match: $str, $alias\n" if($opts->{debug});
    }
    if ($str !~ /--/) {
        push(@{$files},grep(/^$str$/,(keys %{$logs->{usage}})));
    }
    $filehash{$str}=$files;
    return $files;
}

=head2 GetUtilization

    my $util = $self->GetUtilization($files, $usemin=0);

This gets utilization information from the files specified by the $files
arrayref (which is usually returned from GetFiles).  This returns the higher
value of the utilization between two devices.

It takes an optional usemin argument, which returns the lower value.
This defaults to the global $opts->{usemin} value, or false if unset.

Working on making it take new arguments so we can specify direction of the
links.

=cut

# I build a global hash use{link} which caches the values of the links -
# this way you don't have to keep going back and getting them.  I could
# also do it for the full link name, but that isn't as much effort to
# just recalc each time.  This routine also returns the list of
# files used to arrive at this utilization.

# we need to figure out how to say getUtilization(<direction>) so we can do
# directional graphing in places it's supported.

sub GetUtilization {
    my $self = shift;
    my($files, $usemin)=(@_);
    my $args = $files;
    if (ref $args eq 'HASH') {
        $files      = $args->{files};
        $usemin     = $args->{usemin};
    }
    my $logs = $self->logs;
    my $opts = $self->{opts};
    my @vals;
    $usemin ||= $opts->{usemin};
    $usemin ||= 0;

    foreach my $file (@{$files}) {
        push(@vals,100*$logs->{usage}->{$file}->{usage});
    }
    warn "vals were @vals\n" if $opts->{debug};
    if(@vals) {
        @vals=sort { $a <=> $b } @vals;
        return $vals[($usemin)?0:$#vals];
    }
    return; # undef
}


=head2 build_color_map

    $color_map=$self->build_color_map();

Build a color map that will be used to convert utilisation into RGB values.

=cut

sub build_color_map {
    my $shades = shift->{opts}->{shades};
    my $step = 255/$shades;
    my $color_map;
    my ($r,$g,$b)=(0,255,0);
    for(my $i=0;$i<$shades;$i++) {
        push(@$color_map,sprintf('#%02x%02x%02x',$r,$g,$b));
        ($r,$g,$b)=($r+$step,$g-$step,$b+2*$step*(($i>=$shades/2)?-1:1));
    }
    return $color_map;
}

=head2 color_map

    my $color_map=$self->color_map;

Returns a copy of the color_map as an array_ref.

=cut

sub color_map {
    return shift->{logs}->{color_map};
}


sub GetAliases {
    my $self = shift;
    my $opts = $self->{opts};
    my($files)=(@_);
    my $addr_alias=$self->GetAliasesFromAddresses($files);
    my $desc_alias=$self->GetAliasesFromDescriptions($files);
    my $alias=$desc_alias;
    for my $name (keys %{$addr_alias}) {
        warn "desc-addr alias collision for $name:\n\t".
            join(",",@{$desc_alias->{$name}})."\n\t".
            join(",",@{$addr_alias->{$name}})."\n"
                if defined $desc_alias->{$name} and $opts->{debug};
        $alias->{$name}=$addr_alias->{$name}; #let addr override
    }

    if($opts->{debug}) {
        for my $name (keys %{$alias}) {
            warn "Final alias: $name=".join(",",@{$alias->{$name}})."\n";
        }
    }
    return wantarray ? %{$alias} : $alias;
}

sub GetAliasesFromAddresses {
    my $self = shift;
    my $opts = $self->{opts};
    my($files)=(@_);
    # net keeps a list of hosts on the same network
    # filelist keeps a list of files sharing the same alias
    # network is the prefix of an address
    my(%net,%filelist);
    my $alias={};
    foreach my $file (keys %{$files}) {
        push(@{$filelist{$files->{$file}->{addr}}},$file)
        if ($files->{$file}->{addr});
        if (my $network=$files->{$file}->{prefix}) {
            push(@{$net{$network}{$files->{$file}->{host}}},$file);
            push(@{$filelist{$network}},$file);
        }
    }
    foreach my $network (sort (keys %filelist)) {
        $alias->{$network}=$filelist{$network};
        warn "alias: $network\n" if($opts->{debug});
        my(@rtrs)=sort((keys %{$net{$network}}));
        next if(@rtrs<2);
        if(@rtrs==2) {
            $self->AddAlias($alias,join("--",@rtrs),$filelist{$network});
            $self->AddAlias($alias,join("--",reverse(@rtrs)),$filelist{$network});
        } else {
        #        $self->AddAlias($alias,join("---",@rtrs),$filelist{$network});
            my($o1,$o2,$o3,$o4,$len)=split(/[\.\/]/,$network);
            my $hub="hub_$o3.$o4";
            foreach my $rtr (@rtrs) {
        #           $self->AddAlias($alias,"$rtr--$hub",$net{$network}{$rtr});
                push(@{$alias->{"$rtr--$hub"}},@{$net{$network}{$rtr}});
            }
        }
    }
    delete $alias->{_count_}; # created by AddAlias
    return wantarray ? %{$alias} : $alias;
}

sub GetAliasesFromDescriptions {
    my $self = shift;
    my $opts = $self->{opts};
    my($files)=(@_);
    return if ref $opts->{destination} ne "CODE";

    my $info;
    my $alias={};
    foreach my $file (keys %{$files}) {
        # exploit the fact that in/out have same desc field.
        my ($src,$desc)=($files->{$file}->{host},$files->{$file}->{desc});
        my $dst=&{$opts->{destination}}($desc);
        push(@{$info->{$src}->{$dst}->{$desc}},$file) if($dst);
    }

    foreach my $src (keys %{$info}) {
        foreach my $dst (keys %{$info->{$src}}) {
            foreach my $desc (keys %{$info->{$src}->{$dst}}) {
                $self->AddAlias($alias,"$src--$dst",$info->{$src}->{$dst}->{$desc});
            }
        }
    }
    delete $alias->{_count_}; # created by AddAlias
    return wantarray ? %{$alias} : $alias;
}

# $alias->{_count_} will store a hash ref used to count occurences
# of the same name.
sub AddAlias {
    my $self = shift;
    my $opts = $self->{opts};
    my($alias,$name,$file_array)=(@_);
    push(@{$alias->{$name}},@{$file_array});
    warn "alias: $name\n" if($opts->{debug});
    $name.= "_". $alias->{_count_}->{$name}++;
    $alias->{$name}=$file_array;
    warn "alias: $name\n" if($opts->{debug});
}

=head2 ReadLogs

    my $usage = ReadLogs([glob("*")]);

Takes an arrayref ($files) and returns a hashref of usage values.

=cut

sub ReadLogs {
    my($files)=(@_);
    my $hash;
    foreach my $file (@{$files}) {
        next if ( not -e $file or not -R $file or -M $file >=1 );
        my $log=require $file;
        @{$hash}{keys %{$log}}=values %{$log};
    }
    return $hash;
}


1;
