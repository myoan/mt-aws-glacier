#!/usr/bin/env perl

# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


=head1 NAME

mt-aws-glacier - Perl Multithreaded Multipart sync to Amazon Glacier

=head1 SYNOPSIS

More info in README.md or L<https://github.com/vsespb/mt-aws-glacier> or L<http://mt-aws.com/>

=cut


package App::MtAwsApi;

use strict;
use warnings;
use utf8;
use 5.008008; # minumum perl version is 5.8.8

our $VERSION = '1.051';
our $VERSION_MATURITY = "";

use constant ONE_MB => 1024*1024;

use App::MtAws;
use YAML;
use Data::Dumper;

sub init
{
    return YAML::LoadFile('freezer_cfg.yaml');
}

sub retrive_inventory
{
    my ($vault, $config) = @_;
    my $res = {
        'warnings' => undef,
        'option_list' => undef,
        'options' => {
            'protocol' => $config->{'protocol'},
            'journal-encoding' => 'UTF-8',
            'filenames-encoding' => 'UTF-8',
            'region' => $config->{'region'},
            'secret' => $config->{'secret'},
            'terminal-encoding' => 'UTF-8',
            'key' => $config->{'key'},
            'vault' => $vault,
            'timeout' => 180,
            'config-encoding' => 'UTF-8',
            'config' => $config->{'mt-glacier-cfg'}
        },
        'warning_texts' => undef,
        'errors' => undef,
        'error_texts' => undef,
        'command' => 'retrieve-inventory'
    };
    App::MtAws::api_process($res)
}

sub upload_file_from_stdin
{
    my ($vault, $config) = @_;
    my $res = {
        'warnings' => undef,
        'option_list' => undef,
        'options' => {
            'protocol' => $config->{'protocol'},
            'journal-encoding' => 'UTF-8',
            'filenames-encoding' => 'UTF-8',
            'set-rel-filename' => 'data/',
            'key' => $config->{'key'},
            'vault' => $vault,
            'check-max-file-size' => 131,
            'timeout' => 180,
            'config-encoding' => 'UTF-8',
            'journal' => 'journal.log',
            'data-type' => 'stdin',
            'stdin' => '1',
            'region' => $config->{'region'},
            'secret' => $config->{'secret'},
            'relfilename' => 'data/',
            'concurrency' => 4,
            'terminal-encoding' => 'UTF-8',
            'partsize' => 16,
            'name-type' => 'rel-filename',
            'config' => $config->{'mt-glacier-cfg'}
        },
        'warning_texts' => undef,
        'errors' => undef,
        'error_texts' => undef,
        'command' => 'upload-file'
    };
    App::MtAws::api_process($res)
}

1;
